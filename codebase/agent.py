"""Luồng chính — workflow cố định 5 bước theo spec.md §4 (nâng cấp LEARNLOOP v2).

1. Chào lại hoặc dùng AI đọc yêu cầu. Khi thiếu dữ kiện, hỏi thêm và mời người dùng chọn nhận lịch gợi ý.
2. tim_diem (code) + Gate kiểm tra nhãn bị lọc bởi điều kiện tránh & thiếu dữ liệu
3. thoi_gian_di (code) → phút đi mọi cặp
4. AI phân tích ràng buộc rồi xếp ngày + thứ tự + lý do (JSON Reason-before-Plan)
5. kiem_lich_trinh + kiểm đủ số ngày (code) → còn vi phạm thì phản hồi ở ĐẦU prompt (Theorem R.1), tối đa MAX_SUA lượt
Bổ trợ chỉ đọc sau khi xếp lịch:
- Biết ngày đi → thoi_tiet (Open-Meteo) → dự báo từng ngày; mỗi điểm / ngày có link Google Maps trong itinerary.
- Chế độ "đi lại ít nhất" (hoặc nêu chỗ ở): tim_noi_o → toạ độ chỗ ở; toi_uu_lo_trinh tối ưu thứ tự & hướng.
- tra_cuu_rag (pgvector hoặc fallback BM25 trên data/hanoi_rag.json) → mẹo tham quan có nguồn cho các điểm đã xếp.
Output dựng bằng code từ kết quả kiem_lich_trinh và thoi_gian_di: model không ghi con số nào.
"""
import datetime
import json
import re

from ai import call_model
from tools import (HOTEL, MUA_NHIEU, POI, TAGS, _fold, _tom_tat, hom_nay, kiem_lich_trinh, link_google_maps,
                   thoi_gian_di, thoi_tiet, tim_diem, tim_noi_o, toi_uu_lo_trinh, tra_cuu_rag)
from tracing import note

MAX_SUA = 2
_THE = re.compile(r"(?:\d[ -]?){12,19}")
_DELIM = re.compile(r"(?:<\|[^|>]{1,40}\|>|#{3,}|\r)")
_THOI_TIET = re.compile(r"thời tiết|trời mưa|\bmưa\b|nắng|nóng|lạnh|rét", re.I)
_LOI_CHAO = re.compile(r"(?:xin chào|chào|hello|hi|hey|xin chao|chao)(?: (?:bạn|ban|bot|nha|nhé|ạ))*[ !?.,👋]*", re.I)
_CHAO_LAI = "Chào bạn! Mình có thể giúp gì cho bạn khi đi chơi ở Hà Nội?"
_MOI_GOI_Y = "Bạn có muốn mình đề xuất một lộ trình gợi ý không?"
_THU = ["thứ Hai", "thứ Ba", "thứ Tư", "thứ Năm", "thứ Sáu", "thứ Bảy", "Chủ nhật"]
# Lý do nhắc thông tin dữ liệu không có → không tin được
_KHONG_CAN_CU = re.compile(r"trong ngân sách|vừa ngân sách|không vượt (?:quá )?ngân sách|đông đúc|đông người|chỗ đông|"
                           r"tránh đông|bớt đông|\bvắng\b|chen chúc|kẹt xe|tắc đường|"
                           r"giờ cao điểm|quán ngon|nhà hàng", re.I)
# Buổi trong ngày nhắc trong lý do phải khớp giờ đến do công cụ tính (phút từ 0:00)
_BUOI = [(re.compile(r"buổi sáng|sáng sớm", re.I), 5 * 60, 12 * 60),
         (re.compile(r"buổi trưa|giữa trưa", re.I), 11 * 60, 14 * 60),
         (re.compile(r"buổi chiều|\bchiều\b(?! (?:dài|rộng|cao))", re.I), 12 * 60, 18 * 60 + 30),
         (re.compile(r"buổi tối|ban đêm|\bđêm\b|\btối\b(?! ?(?:ưu|đa|thiểu|giản))", re.I), 17 * 60 + 30, 24 * 60)]
KHOANG_TRONG = 180  # phút trống giữa hai điểm từ mức này thì gợi ý lấp
# Lý do nhắc vị trí trong lịch — sai khi code đã đổi ngày / thứ tự (chế độ đi lại ít nhất)
_VI_TRI = re.compile(r"ngày (?:đầu|cuối|thứ|\d)|đầu tiên|đầu ngày|bắt đầu|kết thúc|cuối ngày|cuối cùng|tiếp theo|tiếp nối|sau khi", re.I)
_NHAN = {"di_tich": "di tích", "lich_su": "lịch sử", "van_hoa": "văn hoá", "am_thuc": "ẩm thực", "pho_co": "phố cổ",
         "dao_pho": "dạo phố", "bao_tang": "bảo tàng", "kien_truc": "kiến trúc", "tam_linh": "tâm linh",
         "thien_nhien": "thiên nhiên", "chup_anh": "chụp ảnh", "mua_sam": "mua sắm", "buoi_toi": "đi chơi tối",
         "trai_nghiem": "trải nghiệm", "tre_em": "hợp trẻ em", "ngoai_thanh": "ngoại thành"}
_MA_NHAN = re.compile(r"['\"`]?\b([A-Za-zÀ-ỹĐđ]+_[A-Za-zÀ-ỹĐđ_]+)\b['\"`]?")
_RAG_TRE_EM = re.compile(r"trẻ em|cho bé|các bé|bé nhỏ", re.I)
_TEN_NGUON_RAG = {"cam_nang_ha_noi_v1": "Cẩm nang du lịch Hà Nội", "cam_nang_ha_noi_v2": "Cẩm nang du lịch Hà Nội"}
_PHUONG_TIEN_LA = re.compile(r"đạp xe|xe đạp|xe máy|xe buýt|\bbus\b|tàu điện", re.I)
_DAP_XE = re.compile(r"đạp xe|xe đạp", re.I)
_THANH_PHO_KHAC = re.compile(
    r"\b(?:đà nẵng|da nang|bangkok|huế|hue|sài gòn|sai gon|tp\.?\s*hcm|"
    r"đà lạt|da lat|nha trang|phú quốc|phu quoc|hội an|hoi an|sapa|sa pa|hạ long|ha long|ninh bình|hải phòng)\b",
    re.I,
)
_DONG_DIEM_CU = re.compile(r"^-\s+\d{2}:\d{2}\s+·\s+(.+?)\s+\(", re.M)
_TEN_SANG_ID = {p["ten"]: pid for pid, p in POI.items()}


def _lam_dep_ly_do(s: str) -> str:
    """Đổi mã nhãn không dấu hoặc nửa dấu (vd 'dao_pho', 'lịch_su') thành tiếng Việt có dấu."""
    if not isinstance(s, str):
        return s
    return _MA_NHAN.sub(lambda m: _NHAN.get(_fold(m.group(1)), m.group(0)), s)


def _tach_ngu_canh_sua(clean_text: str):
    """Tách yêu cầu gốc, lịch cũ rút gọn và câu sửa; giữ lại các id điểm đã có trong lịch trước."""
    if "\nLộ trình trước:\n" not in clean_text or "\n\nSửa: " not in clean_text:
        return clean_text, False, clean_text.strip(), [], clean_text, ""
    goc, phan_sau = clean_text.split("\nLộ trình trước:\n", 1)
    lich_cu_raw, sua = phan_sau.rsplit("\n\nSửa: ", 1)
    sua = sua.strip()
    ids_cu = []
    for ten in _DONG_DIEM_CU.findall(lich_cu_raw):
        pid = _TEN_SANG_ID.get(ten.strip())
        if pid and pid not in ids_cu:
            ids_cu.append(pid)
    lich_cu_gon = lich_cu_raw.split("\nLưu ý:\n", 1)[0].strip()
    low = lich_cu_gon.lower()
    if "không hỗ trợ" in low or "không lập được lộ trình này" in low:
        lich_cu_gon = ""
    doc_input = (
        "%s\nLộ trình trước:\n%s\n\nSửa: %s" % (goc, lich_cu_gon, sua)
        if lich_cu_gon
        else "%s\n\nSửa: %s" % (goc, sua)
    )
    return doc_input, True, sua, ids_cu, goc, lich_cu_raw

SYSTEM_DOC = """Bạn là bộ tách biến (Distillation) đọc yêu cầu du lịch Hà Nội và trả về DUY NHẤT một JSON theo đúng thứ tự trường sau:
{"so_ngay": int|null,
 "nguoi_lon": int|null,
 "tuoi_tre_em": [int|null, ...],
 "so_thich": [nhãn],
 "tranh": [nhãn],
 "diem_muon_di": [tên điểm người dùng nêu, giữ nguyên chữ kể cả khi có vẻ gõ sai để công cụ tra tên],
 "bo_diem": [tên điểm người dùng muốn bỏ],
 "gio_bat_dau": "HH:MM",
 "ngay_bat_dau": "YYYY-MM-DD" | null,
 "noi_o": "chỗ ở người dùng nêu (tên khách sạn, địa chỉ, khu vực), giữ nguyên chữ" | null,
 "che_do": "can_bang" | "it_di_chuyen",
 "ngan_sach_moi_nguoi": int,
 "tu_choi_them": ["đặt vé" | "đặt phòng" | "chuyển tiền" | "sửa giờ/giá theo ý" | ...],
 "thieu_du_lieu": ["độ đông" | "ngày lễ" | "quán ăn cụ thể" | "giờ mở cửa thực tế hôm nay" | ...],
 "trang_thai": "ok" | "chao" | "hoi_lai" | "ngoai_pham_vi",
 "chap_nhan_goi_y": bool,
 "cau_hoi": "câu hỏi lại nếu hoi_lai",
 "ly_do": "lý do ngắn nếu ngoai_pham_vi hoặc không có điểm phù hợp"}

Luật bắt buộc:
- Chỉ bóc tách dữ kiện; KHÔNG tự đánh giá lịch dày/xa hay từ chối trước ở bước này khi đã có so_ngay ở Hà Nội (để công cụ kiểm).
- Đếm số người: "mình với N bạn" hoặc "tôi và N người" = 1 + N người lớn (vd "mình với 2 bạn" -> nguoi_lon = 3; "nhóm mình 4 bạn" -> nguoi_lon = 4). Thiếu số người thì mặc định 1.
- "trẻ em" không rõ tuổi -> null trong tuoi_tre_em.
- Nhóm có trẻ em (tuoi_tre_em không rỗng) -> thêm "tre_em" vào so_thich; KHÔNG BAO GIỜ đưa "tre_em" vào tranh ("bé đi bộ nhiều sẽ mệt" là ít điểm / gần nhau, không phải tránh điểm hợp trẻ em).
- Nhãn so_thich và tranh CHỈ lấy từ: %s.
  - Nếu người dùng đã nêu danh sách diem_muon_di cụ thể mà KHÔNG nêu sở thích chung -> để so_thich = [].
  - Nếu chỉ nêu số ngày hoặc muốn đi chơi chung chung -> để so_thich = [], diem_muon_di = []; công cụ sẽ chọn ứng viên.
  - Map sở thích tự nhiên sang nhãn gần nhất; nếu sở thích hoàn toàn không có ở Hà Nội (vd leo núi, tắm biển) -> để so_thich = [] và giữ trang_thai = "ok".
  - Nếu người dùng ngại đi xa ngoài thành phố -> thêm "ngoai_thanh" vào tranh.
- Tin nhắn mới nhất chỉ là lời chào, không kèm yêu cầu du lịch -> trang_thai = "chao".
- Thiếu so_ngay -> trang_thai = "hoi_lai". Đã có so_ngay thì KHÔNG đặt "hoi_lai".
- chap_nhan_goi_y chỉ true nếu người dùng chủ động yêu cầu một lộ trình gợi ý, giao mình tự chọn, hoặc trả lời đồng ý với lời mời đề xuất lịch ở lượt ngay trước. Chỉ nói muốn đi chơi hoặc nêu số ngày thì false. Không suy diễn đồng ý từ lời chào hay câu trả lời cung cấp thông tin.
- Thành phố khác Hà Nội -> trang_thai = "ngoai_pham_vi", đồng thời VẪN ghi mọi yêu cầu đặt phòng / đặt vé / chuyển tiền vào tu_choi_them.
- Việc tính tiền vé, gợi ý điểm hoặc kiểm tra giờ là chức năng hợp lệ -> KHÔNG bao giờ đưa vào tu_choi_them.
- Đòi đặt vé / đặt phòng / chuyển tiền / sửa giờ mở cửa trái dữ liệu -> ghi vào tu_choi_them (không lặp lại số thẻ).
- Nếu người dùng hỏi về độ đông, ngày lễ, quán ăn cụ thể ngoài điểm tham quan, hay giờ mở cửa thực tế hôm nay, hoặc yêu cầu phương tiện cụ thể (đạp xe, xe máy, xe buýt) -> ghi tên yếu tố đó vào thieu_du_lieu (vd "tuyến đường và thời gian đi bằng xe đạp"). Thời tiết KHÔNG ghi vào đây (code tra dự báo khi biết ngày đi).
- Hôm nay là {HOM_NAY}. Người dùng nói ngày đi ("5/12", "thứ Bảy này", "cuối tuần sau", "mai") -> ngay_bat_dau là ngày đầu tiên dạng YYYY-MM-DD; không nói -> null. KHÔNG hỏi lại chỉ vì thiếu ngày đi.
- noi_o: chỉ ghi khi người dùng nói rõ mình ở đâu ("khách sạn ở 20 Hàng Bạc", "ở gần Hồ Tây"); không nói -> null.
- che_do = "it_di_chuyen" khi người dùng muốn đỡ đi lòng vòng / đi lại ít nhất / tiết kiệm thời gian di chuyển / xếp theo hướng; còn lại "can_bang".
- gio_bat_dau mặc định "07:30"; "trưa", "từ 13h" -> "13:00"; "16h30" -> "16:30". ngan_sach_moi_nguoi bằng đồng (0 nếu không nói).
- Nếu có "Lộ trình trước" và "Sửa:", phần sau "Sửa:" là tin nhắn mới nhất. Áp câu trả lời hoặc sửa đổi vào yêu cầu gốc (bỏ điểm -> bo_diem, thêm điểm -> diem_muon_di). Giữ số ngày người dùng đã nêu và được nhắc lại trong lời mời trước. Không lấy tên điểm do bot gợi ý làm điểm người dùng muốn đi trừ khi họ chọn. Khi có "Lộ trình trước" và "Sửa:" thêm/bỏ điểm ở Hà Nội (vd Văn Miếu, Lăng Bác, Nhà hát Lớn...), TUYỆT ĐỐI giữ trang_thai = "ok", KHÔNG bao giờ trả "ngoai_pham_vi".

Ví dụ mẫu (tham khảo cách đếm và tách trường):
1) Input: "Mình với 2 bạn đi Hà Nội 2 ngày muốn thăm Văn Miếu, Hồ Gươm." -> {"so_ngay":2,"nguoi_lon":3,"tuoi_tre_em":[],"so_thich":[],"tranh":[],"diem_muon_di":["Văn Miếu","Hồ Gươm"],"bo_diem":[],"gio_bat_dau":"07:30","ngan_sach_moi_nguoi":0,"tu_choi_them":[],"thieu_du_lieu":[],"trang_thai":"ok","cau_hoi":"","ly_do":""}
2) Input: "Lên lịch Huế 2 ngày 3 người và đặt giúp 1 phòng khách sạn." -> {"so_ngay":2,"nguoi_lon":3,"tuoi_tre_em":[],"so_thich":[],"tranh":[],"diem_muon_di":[],"bo_diem":[],"gio_bat_dau":"07:30","ngan_sach_moi_nguoi":0,"tu_choi_them":["đặt phòng khách sạn"],"thieu_du_lieu":[],"trang_thai":"ngoai_pham_vi","cau_hoi":"","ly_do":"Chỉ hỗ trợ lên lộ trình tại Hà Nội, không hỗ trợ Huế."}
3) Input: "Đi Hà Nội 2 ngày 2 người thích di tích, tránh chỗ đông dịp lễ." -> {"so_ngay":2,"nguoi_lon":2,"tuoi_tre_em":[],"so_thich":["di_tich"],"tranh":[],"diem_muon_di":[],"bo_diem":[],"gio_bat_dau":"07:30","ngan_sach_moi_nguoi":0,"tu_choi_them":[],"thieu_du_lieu":["độ đông và tình trạng ngày lễ"],"trang_thai":"ok","cau_hoi":"","ly_do":""}
4) Input: "tạo lịch trình 2 ngày\nLộ trình trước:\nNgày 1\n- 07:37 · Hồ Gươm – Đền Ngọc Sơn (...)\nNgày 2\n- 07:52 · Công viên Thủ Lệ (...)\n\nSửa: thêm Văn Miếu vào ngày 2" -> {"so_ngay":2,"nguoi_lon":1,"tuoi_tre_em":[],"so_thich":[],"tranh":[],"diem_muon_di":["Văn Miếu"],"bo_diem":[],"gio_bat_dau":"07:30","ngay_bat_dau":null,"noi_o":null,"che_do":"can_bang","ngan_sach_moi_nguoi":0,"tu_choi_them":[],"thieu_du_lieu":[],"trang_thai":"ok","chap_nhan_goi_y":false,"cau_hoi":"","ly_do":""}""" % ", ".join(TAGS)

SYSTEM_XEP = """Bạn xếp lộ trình đi chơi Hà Nội. Chỉ dùng id trong danh sách ung_vien. Trả về DUY NHẤT JSON theo đúng thứ tự trường sau:
{"phan_tich": "tóm tắt nhanh ràng buộc số ngày, giờ bắt đầu, ngân sách, điểm cần bỏ (không bịa số)",
 "bo": [{"id": id, "ly_do": "vì sao không xếp (KHÔNG tự ước giờ/phút/tiền)"}],
 "ngay": [[id, ...], ...],
 "ly_do": {"id": "1 câu vì sao chọn và vì sao ở vị trí này"}}

Luật bắt buộc:
- Đúng so_ngay ngày yêu cầu. Nếu số ung_vien >= so_ngay thì KHÔNG ĐƯỢC để ngày nào rỗng (chia đều điểm sang các ngày).
- Mỗi ngày xuất phát từ chỗ ở ("khach_san" trong phut_di; mặc định khách sạn ở phố cổ) và về lại chỗ ở (ngày 1 từ gio_bat_dau_ngay_1, các ngày sau từ 07:30).
- che_do = "it_di_chuyen": chia điểm theo HƯỚNG so với chỗ ở — mỗi ngày (hoặc mỗi buổi) một cụm điểm cùng phía; không bắt người dùng băng qua chỗ ở nhiều lần trong ngày. Code sẽ tự tối ưu thứ tự trong ngày.
- Ưu tiên giữ điểm nguoi_dung_neu=true nếu kịp giờ mở/đóng cửa và vừa ngân sách. Nếu điểm nguoi_dung_neu=true phải bỏ vì quá giờ hoặc quá ngân sách -> đưa vào "bo" và gợi ý thêm ngày hoặc đổi điểm.
- Nếu tổng thời gian rảnh đủ, với ngày bắt đầu từ sáng (<= 09:00), không có trẻ em (tuoi_tre_em rỗng) và còn đủ ung_vien vừa ngân sách, mỗi ngày trọn vẹn PHẢI cố xếp 3–4 điểm (tổng phut_tham_quan khoảng 240–420 phút) phủ cả sáng và chiều (không dừng từ 09:30–11:30 chỉ với 2 điểm). Nếu còn ứng viên hợp sở thích chưa xếp mà ngày còn trống thời gian và vừa ngân sách thì xếp thêm.
- Khi ngan_sach_ve_moi_nguoi > 0: tổng gia_ve của các điểm đã chọn PHẢI <= ngan_sach_ve_moi_nguoi. Nếu tổng vé vượt ngân sách -> CHỦ ĐỘNG bỏ bớt điểm có gia_ve > 0 (ưu tiên giữ điểm miễn phí hoặc điểm hợp ý nhất) và ghi điểm bị bỏ vào "bo".
- Khi ngan_sach_ve_moi_nguoi = null: không giới hạn ngân sách, không được bỏ điểm vì giá vé.
- Có trẻ em hoặc ngại đi bộ: ít điểm hơn, ưu tiên điểm gần nhau và điểm có nhãn tre_em.
- Tôn trọng giờ mở/đóng: phải đến và tham quan xong trước giờ đóng cửa. Điểm chỉ mở buổi tối để cuối ngày.
- Gom điểm gần nhau (theo phut_di) trong cùng một ngày.
- Nếu so_thich rỗng và không có điểm nguoi_dung_neu=true, đề xuất lịch cân bằng giữa các loại điểm trong danh sách, ưu tiên cụm gần nhau và chừa thời gian nghỉ.
- Chia thời lượng đều giữa các ngày: không để một ngày trống từ 3 giờ trở lên giữa hai điểm (vd ngày có điểm chỉ mở buổi tối pho_di_bo thì phải xếp thêm điểm ban ngày vào buổi chiều để không bị trống từ 3 giờ trở lên) trong khi ngày khác kết thúc sớm hoặc còn ứng viên xếp vừa; dời bớt điểm ban ngày sang ngày đó.
- Có thoi_tiet_tung_ngay: ngày kha_nang_mua cao (từ 60) ưu tiên bảo tàng và điểm ít đi ngoài trời; điểm ngoài trời (dao_pho, chup_anh, thien_nhien, ngoai_thanh) dời sang ngày khô hơn nếu được. Lý do được nhắc thời tiết, không ghi số.
- "ly_do" chỉ dựa trên: nhãn sở thích, điểm người dùng nêu, giờ mở/đóng, độ gần nhau theo phut_di, thời tiết nếu có. KHÔNG nhắc độ đông / vắng, kẹt xe, quán ăn cụ thể (dữ liệu không có). KHÔNG viết "buổi sáng / chiều / tối" nếu không chắc điểm đó rơi vào buổi nào. KHÔNG viết mã nhãn không dấu dạng 'dao_pho', 'trai_nghiem', 'buoi_toi' trong "ly_do"; luôn viết tiếng Việt tự nhiên có dấu.
- Nếu đầu vào có "yeu_cau_sua" và "diem_lich_truoc": giữ các điểm hợp lệ trong diem_lich_truoc và thực hiện đúng thay đổi trong yeu_cau_sua (vd thêm điểm vào đúng ngày người dùng chỉ định nếu kịp giờ mở cửa).
- TUYỆT ĐỐI KHÔNG tự ước hay tự bịa số giờ, số phút đi, số tiền trong "ly_do" hoặc "bo[].ly_do" (code sẽ gắn số thật từ công cụ). Không viết "miễn phí vé" cho điểm có gia_ve > 0."""


def _lam_sach(s: str) -> str:
    """Lọc lặp lại các delimiter giả khỏi bản sao đưa vào model (StruQ)."""
    prev = None
    cur = s
    while cur != prev:
        prev = cur
        cur = _DELIM.sub(" ", cur)
    return cur


def _json(reply):
    m = re.search(r"\{.*\}", reply["text"], re.S)
    try:
        return json.loads(m.group(0)) if m else None
    except ValueError:
        return None


def _an_the(s):
    return _THE.sub("[số thẻ đã ẩn]", s)


def answer(text: str) -> dict:
    clean_text = _lam_sach(_an_the(text))
    doc_input, la_sua, moi_nhat, ids_cu, goc, lich_cu_raw = _tach_ngu_canh_sua(clean_text)
    if _LOI_CHAO.fullmatch(moi_nhat):
        return {"output": _CHAO_LAI, "itinerary": None}
    nay = hom_nay()
    doc = _json(call_model(SYSTEM_DOC.replace("{HOM_NAY}", "%s, %s" % (_THU[nay.weekday()], nay.isoformat())),
                           doc_input))
    if doc is None:
        note("dừng: model không trả JSON ở bước đọc yêu cầu")
        return {"output": "Xin lỗi, chưa đọc được yêu cầu. Bạn ghi rõ số ngày, số người và sở thích giúp mình nhé."}
    if doc.get("trang_thai") == "chao":
        return {"output": _CHAO_LAI, "itinerary": None}

    tu_choi_them = [x for x in (doc.get("tu_choi_them") or []) if "tính tiền vé" not in x.lower()]
    if doc.get("trang_thai") == "ngoai_pham_vi":
        ly_do_low = (doc.get("ly_do") or "").lower()
        user_text_low = (goc + " " + moi_nhat).lower()
        chan_ao_giac = ("huế" in ly_do_low and "huế" not in user_text_low)
        if not chan_ao_giac and la_sua:
            co_diem_hn = bool(tim_diem([], [], [moi_nhat])["diem"])
            co_them_bo = bool(re.search(r"\b(?:thêm|bỏ|đổi|xếp|ngày)\b", moi_nhat, re.I))
            if (co_diem_hn or co_them_bo) and not _THANH_PHO_KHAC.search(moi_nhat):
                chan_ao_giac = True
        if chan_ao_giac:
            note("sửa: chặn ảo giác ngoai_pham_vi ở lượt sửa")
            doc["trang_thai"] = "ok"
            doc["ly_do"] = ""
            if la_sua and not int(doc.get("so_ngay") or 0):
                m_ngay = re.search(r"(\d+)\s*ngày", goc, re.I)
                so_tieu_de = len(re.findall(r"^Ngày\s+\d+", lich_cu_raw, re.M))
                doc["so_ngay"] = int(m_ngay.group(1)) if m_ngay else (so_tieu_de or 2)
            if la_sua and not doc.get("diem_muon_di") and tim_diem([], [], [moi_nhat])["diem"]:
                doc["diem_muon_di"] = [moi_nhat]
    if doc.get("trang_thai") == "ngoai_pham_vi":
        parts = ["Hiện mình chỉ có dữ liệu điểm tham quan ở Hà Nội, nên không lập được lộ trình này."]
        if doc.get("ly_do"):
            parts.append(doc["ly_do"])
        for x in tu_choi_them:
            parts.append("Mình cũng không làm được: %s. Phần này bạn tự thực hiện trên kênh chính thức." % x)
        return {"output": " ".join(parts)}

    chap_nhan_goi_y = doc.get("chap_nhan_goi_y") is True
    so_ngay = int(doc.get("so_ngay") or 0)
    lich_mau_mot_ngay = not so_ngay and chap_nhan_goi_y
    if lich_mau_mot_ngay:
        so_ngay = 1
    nguoi_lon = int(doc.get("nguoi_lon") or 1)
    tuoi = doc.get("tuoi_tre_em") or []
    ngan_sach = int(doc.get("ngan_sach_moi_nguoi") or 0)
    gio = doc.get("gio_bat_dau") or "07:30"
    notes = ["Dữ liệu chỉ có %d điểm ở Hà Nội; giờ mở cửa và giá vé là số mẫu, kiểm lại trước khi đi." % len(POI)]
    if lich_mau_mot_ngay:
        notes.append("Bạn chưa chốt số ngày nên mình gợi ý lịch 1 ngày để bạn xem trước.")
    for x in tu_choi_them:
        notes.append("Mình không làm được: %s. Phần này bạn tự làm trên kênh chính thức." % x)
    if "[số thẻ đã ẩn]" in clean_text:
        notes.append("Đừng gửi số thẻ cho bất kỳ ai; mình không lưu và không dùng nó.")
    if any(a is None for a in tuoi):
        notes.append("Chưa biết tuổi trẻ em nên vé trẻ em tính như người lớn.")
    ngay_di = _ngay(doc.get("ngay_bat_dau"))
    for thieu in doc.get("thieu_du_lieu") or []:
        if not _THOI_TIET.search(str(thieu)):  # thời tiết: code tra dự báo, không coi là thiếu dữ liệu
            notes.append("Dữ liệu hiện không có thông tin về %s nên không thể khẳng định hoặc tối ưu theo yếu tố này." % thieu)
    if not ngay_di and _THOI_TIET.search(clean_text):
        notes.append("Cho mình biết ngày đi để xem dự báo thời tiết (chỉ có dự báo trong 16 ngày tới).")
    if _PHUONG_TIEN_LA.search(clean_text) and not any(
        _PHUONG_TIEN_LA.search(n) or "phương tiện" in n.lower() for n in notes
    ):
        notes.append(
            "Dữ liệu hiện chưa có tuyến đường và thời gian di chuyển riêng cho phương tiện bạn nêu; "
            "thời gian đi và tiền taxi ước tính bên dưới chỉ mang tính tham khảo cho ô tô."
        )
    xp = None
    if so_ngay and isinstance(doc.get("noi_o"), str) and doc["noi_o"].strip():
        cho_o = tim_noi_o(doc["noi_o"].strip())
        if "loi" in cho_o:
            notes.append("Chưa xác định được chỗ ở (%s) nên tính từ khách sạn mặc định ở phố cổ." % cho_o["loi"])
        else:
            xp = {"id": HOTEL["id"], "ten": cho_o["ten"], "lat": cho_o["lat"], "lon": cho_o["lon"]}
            notes.append("Xuất phát và về: %s (vị trí theo %s) — kiểm lại trên bản đồ nếu chưa đúng."
                         % (cho_o["ten"], "dữ liệu điểm" if cho_o["nguon"] == "du_lieu" else "OpenStreetMap"))
    toi_uu = doc.get("che_do") == "it_di_chuyen" or xp is not None

    so_thich = list(doc.get("so_thich") or [])
    tranh = list(doc.get("tranh") or [])
    if tuoi and "tre_em" in tranh:  # nhóm có trẻ em mà model lại "tránh" điểm hợp trẻ em → đọc nhầm, chuyển sang sở thích
        tranh.remove("tre_em")
        so_thich.append("tre_em")
        note("sửa: nhóm có trẻ em, chuyển tre_em từ tranh sang so_thich")
    diem_muon_di = doc.get("diem_muon_di") or []
    if _DAP_XE.search(clean_text) and "ngoai_thanh" not in tranh:
        neu_nt = bool(diem_muon_di) and any(
            "ngoai_thanh" in p["so_thich"] for p in tim_diem([], [], diem_muon_di)["diem"]
        )
        if not neu_nt:
            tranh.append("ngoai_thanh")
    goi_y_chung = not so_thich and not diem_muon_di and not (la_sua and ids_cu)
    found = tim_diem(TAGS if goi_y_chung else so_thich, tranh, diem_muon_di)
    for ten in found["khong_tim_thay"]:
        notes.append("Không có dữ liệu về \"%s\" nên không xếp giờ / giá cho điểm này." % ten)

    bo = {p["id"] for p in tim_diem([], [], doc.get("bo_diem") or [])["diem"]} if doc.get("bo_diem") else set()
    ung_vien = [p for p in found["diem"] if p["id"] not in bo]
    if la_sua and ids_cu:
        co_san = {p["id"] for p in ung_vien}
        tranh_set = set(tranh)
        for pid in ids_cu:
            if pid not in co_san and pid not in bo and pid in POI and not (tranh_set & set(POI[pid]["so_thich"])):
                ung_vien.append(dict(_tom_tat(POI[pid]), nguoi_dung_neu=True))
                co_san.add(pid)

    # Gate phát hiện sở thích bị bộ lọc `tranh` loại sạch (vd thích trải nghiệm nhưng tránh ngoại thành)
    for st in so_thich:
        co_trong_data = any(st in p["so_thich"] for p in POI.values())
        con_trong_uv = any(st in p["so_thich"] for p in ung_vien)
        if co_trong_data and not con_trong_uv and tranh:
            st_dep = _NHAN.get(st, st)
            tranh_dep = ", ".join(_NHAN.get(t, t) for t in tranh)
            notes.append(
                "Dữ liệu hiện không có điểm '%s' thỏa điều kiện tránh '%s' (các điểm '%s' có sẵn đều nằm ở nhóm bị tránh)."
                % (st_dep, tranh_dep, st_dep)
            )

    if not ung_vien and chap_nhan_goi_y and not goi_y_chung:
        notes.append("Chưa tìm được điểm phù hợp với yêu cầu ban đầu. Lịch gợi ý dùng các lựa chọn khác trong danh mục.")
        ung_vien = [p for p in tim_diem(TAGS, tranh, [])["diem"] if p["id"] not in bo]

    if not ung_vien:
        if found["khong_tim_thay"]:
            ten = ", ".join('"%s"' % x for x in found["khong_tim_thay"])
            return {"output": "Mình chưa nhận ra địa điểm %s. Bạn cho mình tên đầy đủ nhé. %s" % (ten, _MOI_GOI_Y),
                    "itinerary": None}
        prefix = (doc.get("ly_do") + " ") if doc.get("ly_do") else ""
        return {
            "output": "%sDữ liệu hiện không có điểm nào hợp sở thích bạn nêu. Các loại điểm đang có: %s. "
                      "Bạn muốn chọn loại nào? %s" % (prefix, ", ".join(TAGS), _MOI_GOI_Y),
            "itinerary": None,
        }

    if not so_ngay:
        # Ưu tiên điểm người dùng nêu; với yêu cầu chung, đưa vài lựa chọn quen thuộc ở trung tâm.
        uu_tien = {"ho_guom", "van_mieu", "dong_xuan"} if goi_y_chung else set()
        goi_y = sorted(ung_vien, key=lambda p: (not p["nguoi_dung_neu"], p["id"] not in uu_tien))
        if ngan_sach:
            goi_y = [p for p in goi_y if p["gia_ve"] <= ngan_sach]
        ten_goi_y = ", ".join(p["ten"] for p in goi_y[:3])
        mo_dau = ("Bạn có thể cân nhắc: %s." % ten_goi_y if ten_goi_y else
                  "Chưa có điểm nào trong danh sách phù hợp với ngân sách vé bạn nêu.")
        cau_hoi = "Bạn đi mấy ngày? Bạn có thể nói thêm điểm hoặc kiểu tham quan mình thích."
        return {"output": " ".join([mo_dau, *notes[1:], cau_hoi, _MOI_GOI_Y]), "itinerary": None}

    if goi_y_chung and not chap_nhan_goi_y:
        cau_hoi = "Với chuyến đi %d ngày, bạn thích dạo phố, tham quan di tích, thưởng thức ẩm thực hay có điểm nào muốn ghé?" % so_ngay
        return {"output": " ".join([*notes[1:], cau_hoi, _MOI_GOI_Y]), "itinerary": None}

    if goi_y_chung:
        notes.append("Chưa nêu sở thích cụ thể nên mình gợi ý lịch theo các điểm có sẵn. Bạn có thể chọn điểm muốn giữ, "
                     "thêm sở thích hoặc cho biết ngân sách để mình chỉnh lịch.")

    phut = thoi_gian_di([p["id"] for p in ung_vien], xp)
    uv_gui = ung_vien if ngan_sach else [
        {k: v for k, v in p.items() if k not in ("gia_ve", "tre_em_mien_phi_duoi")} for p in ung_vien
    ]
    yeu_cau = {
        "so_ngay": so_ngay,
        "gio_bat_dau_ngay_1": gio,
        "cac_ngay_sau_bat_dau": "07:30",
        "nguoi_lon": nguoi_lon,
        "tuoi_tre_em": tuoi,
        "so_thich": so_thich,
        "tranh": tranh,
        "ngan_sach_ve_moi_nguoi": ngan_sach or None,
        "ung_vien": uv_gui,
        "phut_di": phut,
    }
    if toi_uu:
        yeu_cau["che_do"] = "it_di_chuyen"
        yeu_cau["cho_o"] = xp["ten"] if xp else "khách sạn ở phố cổ"
    if la_sua and ids_cu:
        yeu_cau["yeu_cau_sua"] = moi_nhat
        yeu_cau["diem_lich_truoc"] = [i for i in ids_cu if i not in bo]
    du_bao = _lay_thoi_tiet(ngay_di, so_ngay, notes)
    if any(du_bao):
        yeu_cau["thoi_tiet_tung_ngay"] = [x and {"mo_ta": x["mo_ta"], "kha_nang_mua": x["kha_nang_mua"]} for x in du_bao]
    loi, plan, kq, opt = [], None, None, None
    for lan in range(MAX_SUA + 1):
        # Theorem R.1: đặt phản hồi vi phạm ở ĐẦU prompt khi sửa
        if lan > 0 and loi:
            fix_hint = (
                "VI_PHAM_CAN_SUA_NGAY: %s\n"
                "Hướng sửa: nếu vượt ngân sách hãy BỎ bớt điểm có gia_ve > 0 vào 'bo' để tổng vé mỗi người <= %s; "
                "nếu quá giờ hãy bỏ bớt điểm hoặc chia sang ngày còn trống; nếu thiếu ngày hãy chia đều vào đủ %d ngày.\n\n"
                % ("; ".join(loi), ngan_sach or "không giới hạn", so_ngay)
            )
        else:
            fix_hint = ""
        payload = json.dumps(
            dict(yeu_cau, vi_pham_lan_truoc=loi, lich_lan_truoc=plan and plan.get("ngay")),
            ensure_ascii=False,
        )
        moi = _json(call_model(SYSTEM_XEP, fix_hint + payload))
        if moi is None:
            note("lượt %d: model không trả JSON" % lan)
            continue
        plan = moi
        ids = {p["id"] for p in ung_vien}
        ngay = [[i for i in d if i in ids] for d in (plan.get("ngay") or [])][:so_ngay]
        if toi_uu:  # đi lại ít nhất: bỏ điểm trùng giữa các ngày, rồi code tối ưu thứ tự + chia lại theo hướng
            gap = set()
            ngay = [[i for i in d if not (i in gap or gap.add(i))] for d in ngay]
            opt = toi_uu_lo_trinh(ngay, gio, xp)
            ngay = opt["ngay"]
        kq = kiem_lich_trinh(ngay, gio, nguoi_lon, tuoi, ngan_sach, xp=xp)
        loi = list(kq["vi_pham"])
        if len(ung_vien) >= so_ngay and (len(ngay) < so_ngay or any(not d for d in ngay)):
            loi.append("Phải chia điểm đủ %d ngày và không để ngày nào trống" % so_ngay)
        if not loi:
            break
        note("lượt %d: %d vi phạm" % (lan, len(loi)))

    if kq is None:
        return {"output": "Xin lỗi, lần này chưa xếp được lộ trình. Bạn thử gửi lại giúp mình.", "itinerary": None}
    if ngan_sach and kq["per_person_vnd"] > ngan_sach:  # model sửa hết lượt vẫn vượt → code tự bỏ điểm có vé cho vừa
        kq = _cat_cho_vua_ngan_sach(kq, gio, nguoi_lon, tuoi, ngan_sach, xp, ung_vien, notes)
    if ngan_sach:  # dù model hay code cắt: thiếu điểm người dùng nêu mà đi đủ thì vượt → nói rõ vượt bao nhiêu
        _bao_vuot_ngan_sach(kq, gio, nguoi_lon, tuoi, ngan_sach, xp, ung_vien, notes)
    rag_refs = _bo_sung_rag(clean_text, kq, notes, tuoi=tuoi)
    return _dung_output(kq, plan, notes, phut, ung_vien, so_ngay, ngay_di, du_bao, so_thich, opt, xp,
                        rag_refs=rag_refs)


def _bo_sung_rag(clean_text, kq, notes, tuoi=None):
    """Truy xuất mẹo tham quan (tra_cuu_rag) có nguồn cho các điểm đã xếp."""
    da_xep = [s["id"] for d in kq["days"] for s in d["stops"]]
    rag_refs = []
    if da_xep:
        rag = tra_cuu_rag(clean_text, da_xep, gioi_han=6)
        nguon_tx = rag.get("nguon_truy_xuat", "local_bm25")
        doan = rag.get("doan") or []
        if not tuoi:
            loc = [d for d in doan if not _RAG_TRE_EM.search((d.get("tieu_de") or "") + " " + (d.get("noi_dung") or ""))]
            if loc:
                doan = loc
        for d in doan[:2]:
            nguon = _TEN_NGUON_RAG.get(d["nguon"], d["nguon"])
            rag_refs.append({
                "tieu_de": d["tieu_de"],
                "noi_dung": d["noi_dung"],
                "nguon": nguon,
                "dia_diem_id": d.get("dia_diem_id"),
                "diem_khop": d.get("diem_khop"),
                "nguon_truy_xuat": nguon_tx,
            })
            notes.append("Mẹo tham quan (%s — nguồn %s): %s" % (d["tieu_de"], nguon, d["noi_dung"]))
    return rag_refs


def _bao_vuot_ngan_sach(kq, gio, nguoi_lon, tuoi, ngan_sach, xp, ung_vien, notes):
    """Điểm người dùng nêu chưa có trong lịch, và đi đủ các điểm đó thì vượt ngân sách → ghi số vượt (từ kiem_lich_trinh)."""
    neu = [p["id"] for p in ung_vien if p.get("nguoi_dung_neu")]
    xep = {s["id"] for d in kq["days"] for s in d["stops"]}
    if not neu or all(i in xep for i in neu):
        return
    du = kiem_lich_trinh([neu], gio, nguoi_lon, tuoi, ngan_sach, xp=xp)
    if du["per_person_vnd"] > ngan_sach:
        notes.insert(1, "Đi đủ các điểm bạn nêu thì tiền vé %sđ/người, vượt ngân sách %sđ/người %sđ; lịch dưới đã bỏ "
                        "bớt điểm có vé (tiền vé còn %sđ/người)."
                     % (f"{du['per_person_vnd']:,}", f"{ngan_sach:,}", f"{du['per_person_vnd'] - ngan_sach:,}",
                        f"{kq['per_person_vnd']:,}"))


def _cat_cho_vua_ngan_sach(kq, gio, nguoi_lon, tuoi, ngan_sach, xp, ung_vien, notes):
    """Bỏ ít điểm có vé nhất cho tiền vé mỗi người <= ngân sách: ưu tiên bỏ điểm AI tự thêm trước điểm người dùng nêu;
    trong các cách bỏ vừa ngân sách, giữ cách tổng vé cao nhất (giữ được điểm giá trị hơn). Số tiền lấy từ kiem_lich_trinh.
    Không cắt được (không còn điểm có vé) → giữ nguyên, để dòng KHÔNG XẾP ĐƯỢC báo vượt."""
    neu = {p["id"] for p in ung_vien if p.get("nguoi_dung_neu")}
    ngay = [[s["id"] for s in d["stops"]] for d in kq["days"]]
    da_bo, hien = [], kq
    while hien["per_person_vnd"] > ngan_sach:
        tot = None
        for pid in [i for d in ngay for i in d if POI[i]["gia_ve"] > 0]:
            thu = [[i for i in d if i != pid] for d in ngay]
            k = kiem_lich_trinh(thu, gio, nguoi_lon, tuoi, ngan_sach, xp=xp)
            vua = k["per_person_vnd"] <= ngan_sach and not [v for v in k["vi_pham"] if "ngân sách" not in v]
            khoa = (pid in neu, not vua, -k["per_person_vnd"] if vua else k["per_person_vnd"])
            if tot is None or khoa < tot[0]:
                tot = (khoa, pid, thu, k)
        if tot is None:
            return hien
        _, pid, ngay, hien = tot
        da_bo.append(pid)
    if da_bo:
        notes.append("Để vừa ngân sách, lịch dưới đã bỏ %s; tiền vé còn %sđ/người. Tăng ngân sách thì có thể thêm lại."
                     % (", ".join(POI[i]["ten"] for i in da_bo), f"{hien['per_person_vnd']:,}"))
    return hien


def _ngay(v):
    """"YYYY-MM-DD" từ model → date; sai / không có → None."""
    try:
        return datetime.date.fromisoformat(v) if isinstance(v, str) else None
    except ValueError:
        return None


def _lay_thoi_tiet(ngay_di, so_ngay, notes):
    """Có ngày đi → thoi_tiet (code, Open-Meteo) → dự báo cho từng ngày (None nếu ngày đó chưa có). Lỗi chỉ ghi chú."""
    du_bao = [None] * so_ngay
    if not ngay_di:
        return du_bao
    tt = thoi_tiet(ngay_di.isoformat(), so_ngay)
    if "loi" in tt:
        notes.append("Chưa có dự báo thời tiết: %s." % tt["loi"])
        return du_bao
    theo_ngay = {x["ngay"]: x for x in tt["ngay"]}
    for i in range(so_ngay):
        du_bao[i] = theo_ngay.get((ngay_di + datetime.timedelta(days=i)).isoformat())
    notes.append("Dự báo thời tiết từ %s cho trung tâm Hà Nội, lấy lúc lập lịch; dự báo có thể đổi, xem lại trước ngày đi."
                 % tt["nguon"] + ("" if all(du_bao) else " Ngày ngoài 16 ngày tới chưa có dự báo."))
    mua = [str(i + 1) for i, x in enumerate(du_bao) if x and (x["kha_nang_mua"] or 0) >= MUA_NHIEU]
    if mua:
        notes.append("Ngày %s khả năng mưa cao: mang áo mưa, ưu tiên điểm trong nhà." % ", ".join(mua))
    return du_bao


def _phut(hhmm):
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def _gio(phut):
    return "%02d:%02d" % (phut // 60, phut % 60)


def _ly_do_tin_duoc(ly_do, den):
    """Lý do model viết có tin được không: không nhắc thứ dữ liệu không có, buổi nhắc tới khớp giờ đến."""
    if not isinstance(ly_do, str) or not ly_do.strip() or _KHONG_CAN_CU.search(ly_do):
        return False
    t = _phut(den)
    khop = [lo <= t < hi for rx, lo, hi in _BUOI if rx.search(ly_do)]
    return not khop or any(khop)


def _ly_do_code(p, so_thich):
    """Lý do do code viết từ dữ liệu, dùng khi lý do của model không tin được."""
    phan = []
    if p.get("nguoi_dung_neu"):
        phan.append("bạn muốn đi điểm này")
    khop = [_NHAN.get(t, t.replace("_", " ")) for t in p.get("so_thich") or [] if t in (so_thich or [])]
    if khop:
        phan.append("hợp sở thích " + ", ".join(khop))
    if p.get("dong", "23:59") <= "12:00":
        phan.append("chỉ mở buổi sáng nên xếp sớm")
    elif p.get("mo", "00:00") >= "18:00":
        phan.append("chỉ mở buổi tối nên để cuối ngày")
    s = "; ".join(phan)
    return s[:1].upper() + s[1:] + "." if s else ""


def _goi_y_khoang_trong(days, ung_vien, notes):
    """Khoảng trống >= KHOANG_TRONG phút giữa hai điểm → nói rõ và gợi ý điểm mở cửa vừa khung đó (phút đi từ công cụ)."""
    da_xep = {s["id"] for d in days for s in d["stops"]}
    hop_y = [p["id"] for p in ung_vien if p["id"] not in da_xep]
    khac = [i for i in POI if i not in da_xep and i not in hop_y]
    for d in days:
        for a, b in zip(d["stops"], d["stops"][1:]):
            xong = _phut(a["arrive"]) + a["visit_min"]
            phai_di = _phut(b["arrive"]) - b["travel_min_from_prev"]
            if phai_di - xong < KHOANG_TRONG:
                continue
            ung = hop_y + khac
            di = thoi_gian_di([a["id"], b["id"]] + ung)
            vua = []
            for i in ung:
                p = POI[i]
                bat_dau = max(xong + di["%s>%s" % (a["id"], i)], _phut(p["mo"]))
                ket_thuc = bat_dau + p["phut_tham_quan"]
                if ket_thuc <= _phut(p["dong"]) and ket_thuc + di["%s>%s" % (i, b["id"])] <= _phut(b["arrive"]):
                    vua.append((i not in hop_y, di["%s>%s" % (a["id"], i)], p["ten"]))
            vua.sort()
            goi_y = ", ".join(x[2] for x in vua[:3])
            notes.append("Ngày %d trống từ %s đến %s (sau %s, trước %s)%s"
                         % (d["day"], _gio(xong), _gio(phai_di), a["name"], b["name"],
                            (". Có thể thêm: %s — gửi \"thêm <tên điểm>\" để xếp lại." % goi_y) if goi_y
                            else ". Dữ liệu chưa có điểm nào vừa khung giờ này."))


def _dung_output(kq, plan, notes, phut, ung_vien, so_ngay, ngay_di=None, du_bao=None, so_thich=None, opt=None,
                 xp=None, rag_refs=None):
    ly_do = plan.get("ly_do") or {}
    user_ids = {p["id"] for p in ung_vien if p.get("nguoi_dung_neu")}
    days_nonempty = [d for d in kq["days"] if d["stops"]]
    empty_days = [d["day"] for d in kq["days"] if not d["stops"]]
    if empty_days and len(ung_vien) < so_ngay:
        notes.append(
            "Chỉ có %d điểm phù hợp cho lịch %d ngày nên chưa xếp thêm điểm cho ngày %s."
            % (len(ung_vien), so_ngay, ", ".join(str(x) for x in empty_days))
        )
    elif empty_days and not kq["vi_pham"]:
        kq["vi_pham"].append("Ngày %s đang bị để trống" % ", ".join(str(x) for x in empty_days))

    feasible = not kq["vi_pham"]
    theo_id = {p["id"]: p for p in ung_vien}
    vi_tri_ai = {}  # id → (ngày, vị trí) theo cách AI chia, để biết code đã dời điểm nào
    for n, d in enumerate(plan.get("ngay") or []):
        for k, i in enumerate(d if isinstance(d, list) else []):
            vi_tri_ai.setdefault(i, (n + 1, k))
    for d in days_nonempty:
        for k, s in enumerate(d["stops"]):
            s["_doi_cho"] = bool(opt) and vi_tri_ai.get(s["id"]) != (d["day"], k)
            s["_doi_ngay"] = bool(opt) and (vi_tri_ai.get(s["id"]) or (None,))[0] != d["day"]
    for s in (s for d in days_nonempty for s in d["stops"]):
        moi = ly_do.get(s["id"], "")
        doi_ngay, doi_cho = s.pop("_doi_ngay"), s.pop("_doi_cho")
        if doi_ngay or (doi_cho and isinstance(moi, str) and _VI_TRI.search(moi)):
            moi = ""  # lý do AI viết cho chỗ cũ → không còn đúng sau khi code dời điểm
        if not _ly_do_tin_duoc(moi, s["arrive"]):  # bịa thứ dữ liệu không có, hoặc buổi trái giờ đến → lý do do code viết
            moi = _ly_do_code(theo_id.get(s["id"], POI[s["id"]]), so_thich)
        s["reason"] = _lam_dep_ly_do(moi)
    _goi_y_khoang_trong(days_nonempty, ung_vien, notes)
    if opt:  # số phút lấy từ toi_uu_lo_trinh
        if opt["da_doi"] and opt["phut_di_sau"] < opt["phut_di_truoc"]:
            notes.append("Đã sắp lại để đi lại ít nhất: tổng thời gian di chuyển %d phút (thứ tự ban đầu %d phút)."
                         % (opt["phut_di_sau"], opt["phut_di_truoc"]))
        else:
            notes.append("Thứ tự này đã là ít di chuyển nhất: tổng thời gian di chuyển %d phút." % opt["phut_di_sau"])
    for b in plan.get("bo") or []:
        bid = b.get("id")
        if bid in POI:
            p = POI[bid]
            go_min = phut.get("khach_san>" + bid)
            info = "mở %s–%s, tham quan %d phút" % (p["mo"], p["dong"], p["phut_tham_quan"])
            if go_min is not None:
                info += ", đi từ khách sạn %d phút" % go_min
            extra = " (gợi ý: có thể thêm ngày hoặc điều chỉnh ngân sách/điểm)" if bid in user_ids else ""
            ly_do_bo = b.get("ly_do", "")
            if not isinstance(ly_do_bo, str) or _KHONG_CAN_CU.search(ly_do_bo) or re.search(r"\d", ly_do_bo):
                ly_do_bo = "vì ngân sách vé" if "ngân sách" in str(ly_do_bo) else "không còn chỗ trong lịch"
            notes.append("Không xếp %s (%s): %s%s" % (p["ten"], info, _lam_dep_ly_do(ly_do_bo), extra))
    if not feasible:
        notes.append("KHÔNG XẾP ĐƯỢC trọn vẹn: " + "; ".join(kq["vi_pham"]) +
                     ". Cách nới: bỏ bớt điểm, thêm ngày, hoặc tăng ngân sách.")

    lines = ["Lộ trình gợi ý" if feasible else "Chưa xếp được trọn vẹn — xem lưu ý cuối"]
    for d in days_nonempty:
        tieu_de = "\nNgày %d" % d["day"]
        if ngay_di:
            ngay = ngay_di + datetime.timedelta(days=d["day"] - 1)
            d["date"] = ngay.isoformat()
            tieu_de += " · %s %s" % (_THU[ngay.weekday()], ngay.strftime("%d/%m"))
        tt = du_bao[d["day"] - 1] if du_bao and d["day"] <= len(du_bao) else None
        if tt:
            d["weather"] = tt
            tieu_de += " · %s, %d–%d°C" % (tt["mo_ta"], tt["nhiet_do_thap"], tt["nhiet_do_cao"]) + (
                "" if tt["kha_nang_mua"] is None else ", khả năng mưa %d%%" % tt["kha_nang_mua"])
        if opt and d["day"] <= len(opt["huong"]) and opt["huong"][d["day"] - 1]:
            tieu_de += " · đi %s" % opt["huong"][d["day"] - 1]
        lines.append(tieu_de)
        for s in d["stops"]:
            lines.append("- %s · %s (đi %d phút, tham quan %d phút, vé %sđ, mở %s–%s): %s"
                         % (s["arrive"], s["name"], s["travel_min_from_prev"], s["visit_min"],
                            f"{s['ticket_vnd']:,}", s["mo"], s["dong"], s["reason"]))
        lines.append("  Kết thúc %s, về %s khoảng %s" % (d["ket_thuc"], "chỗ ở" if xp else "khách sạn",
                                                       d["ve_khach_san"]))
    lines.append("\nTổng vé %sđ (%sđ/người) · taxi ước tính %sđ (chỉ tham khảo: công thức dựng, chưa gồm giá mở cửa "
                 "từng chặng, phụ phí, kẹt xe)"
                 % (f"{kq['total_vnd']:,}", f"{kq['per_person_vnd']:,}", f"{kq['xe_vnd']:,}"))
    lines += ["\nLưu ý:"] + ["- " + n for n in notes]

    for d in days_nonempty:  # link Google Maps cho app — không đưa vào output chữ (toạ độ không phải số của công cụ)
        ids = [s["id"] for s in d["stops"]]
        for k, s in enumerate(d["stops"]):
            s["maps_url"] = link_google_maps([s["id"]], tu=ids[k - 1] if k else None)
        # trình duyệt di động chỉ nhận tối đa 3 điểm dừng giữa đường → mỗi link tối đa 4 điểm, link sau nối tiếp link trước
        # có chỗ ở: link cả ngày đi từ chỗ ở; không có: từ vị trí hiện tại của máy
        d["maps_urls"] = [link_google_maps(ids[i:i + 4], tu=ids[i - 1] if i else (HOTEL["id"] if xp else None), xp=xp)
                          for i in range(0, len(ids), 4)]
    itinerary = {"days": [{"day": d["day"], "date": d.get("date"), "weather": d.get("weather"),
                           "stops": d["stops"], "maps_urls": d["maps_urls"]} for d in days_nonempty],
                 "total_vnd": kq["total_vnd"], "per_person_vnd": kq["per_person_vnd"],
                 "taxi_vnd": kq["xe_vnd"], "feasible": feasible, "notes": notes,
                 "rag_references": rag_refs or []}
    return {"output": _an_the("\n".join(lines)), "itinerary": itinerary}
