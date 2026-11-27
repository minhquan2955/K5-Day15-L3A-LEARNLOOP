"""Luồng chính — workflow cố định 5 bước theo spec.md §4 (nâng cấp LEARNLOOP v2).

1. AI đọc yêu cầu (Distillation, JSON extraction-first) → thiếu số ngày → hỏi lại · ngoài phạm vi → từ chối (kèm tu_choi_them)
2. tim_diem (code) + Gate kiểm tra nhãn bị lọc bởi điều kiện tránh & thiếu dữ liệu
3. thoi_gian_di (code) → phút đi mọi cặp
4. AI phân tích ràng buộc rồi xếp ngày + thứ tự + lý do (JSON Reason-before-Plan)
5. kiem_lich_trinh + kiểm đủ số ngày (code) → còn vi phạm thì phản hồi ở ĐẦU prompt (Theorem R.1), tối đa MAX_SUA lượt
Thêm sau lượt 2: biết ngày đi thì thoi_tiet (code, Open-Meteo) → dự báo từng ngày; mỗi điểm / ngày có link
chỉ đường Google Maps (link_google_maps, không cần key) trong itinerary — không đưa link vào output chữ.
Output dựng bằng code từ kết quả kiem_lich_trinh và thoi_gian_di: model không ghi con số nào.
"""
import datetime
import json
import re

from ai import call_model
from tools import (MUA_NHIEU, POI, TAGS, hom_nay, kiem_lich_trinh, link_google_maps, thoi_gian_di, thoi_tiet,
                   tim_diem)
from tracing import note

MAX_SUA = 2
_THE = re.compile(r"(?:\d[ -]?){12,19}")
_DELIM = re.compile(r"(?:<\|[^|>]{1,40}\|>|#{3,}|\r)")
_THOI_TIET = re.compile(r"thời tiết|trời mưa|\bmưa\b|nắng|nóng|lạnh|rét", re.I)
_THU = ["thứ Hai", "thứ Ba", "thứ Tư", "thứ Năm", "thứ Sáu", "thứ Bảy", "Chủ nhật"]

SYSTEM_DOC = """Bạn là bộ tách biến (Distillation) đọc yêu cầu du lịch Hà Nội và trả về DUY NHẤT một JSON theo đúng thứ tự trường sau:
{"so_ngay": int|null,
 "nguoi_lon": int|null,
 "tuoi_tre_em": [int|null, ...],
 "so_thich": [nhãn],
 "tranh": [nhãn],
 "diem_muon_di": [tên điểm người dùng nêu, giữ nguyên chữ],
 "bo_diem": [tên điểm người dùng muốn bỏ],
 "gio_bat_dau": "HH:MM",
 "ngay_bat_dau": "YYYY-MM-DD" | null,
 "ngan_sach_moi_nguoi": int,
 "tu_choi_them": ["đặt vé" | "đặt phòng" | "chuyển tiền" | "sửa giờ/giá theo ý" | ...],
 "thieu_du_lieu": ["độ đông" | "ngày lễ" | "quán ăn cụ thể" | "giờ mở cửa thực tế hôm nay" | ...],
 "trang_thai": "ok" | "hoi_lai" | "ngoai_pham_vi",
 "cau_hoi": "câu hỏi lại nếu hoi_lai",
 "ly_do": "lý do ngắn nếu ngoai_pham_vi hoặc không có điểm phù hợp"}

Luật bắt buộc:
- Chỉ bóc tách dữ kiện; KHÔNG tự đánh giá lịch dày/xa hay từ chối trước ở bước này khi đã có so_ngay ở Hà Nội (để công cụ kiểm).
- Đếm số người: "mình với N bạn" hoặc "tôi và N người" = 1 + N người lớn (vd "mình với 2 bạn" -> nguoi_lon = 3; "nhóm mình 4 bạn" -> nguoi_lon = 4). Thiếu số người thì mặc định 1.
- "trẻ em" không rõ tuổi -> null trong tuoi_tre_em.
- Nhãn so_thich và tranh CHỈ lấy từ: %s.
  - Nếu người dùng đã nêu danh sách diem_muon_di cụ thể mà KHÔNG nêu sở thích chung -> để so_thich = [].
  - Map sở thích tự nhiên sang nhãn gần nhất; nếu sở thích hoàn toàn không có ở Hà Nội (vd leo núi, tắm biển) -> để so_thich = [] và giữ trang_thai = "ok".
  - Nếu người dùng ngại đi xa ngoài thành phố -> thêm "ngoai_thanh" vào tranh.
- Thiếu so_ngay -> trang_thai = "hoi_lai", hỏi gọn số ngày (và số người/sở thích nếu thiếu). Đã có so_ngay thì KHÔNG đặt "hoi_lai".
- Thành phố khác Hà Nội -> trang_thai = "ngoai_pham_vi", đồng thời VẪN ghi mọi yêu cầu đặt phòng / đặt vé / chuyển tiền vào tu_choi_them.
- Việc tính tiền vé, gợi ý điểm hoặc kiểm tra giờ là chức năng hợp lệ -> KHÔNG bao giờ đưa vào tu_choi_them.
- Đòi đặt vé / đặt phòng / chuyển tiền / sửa giờ mở cửa trái dữ liệu -> ghi vào tu_choi_them (không lặp lại số thẻ).
- Nếu người dùng hỏi về độ đông, ngày lễ, quán ăn cụ thể ngoài điểm tham quan, hay giờ mở cửa thực tế hôm nay -> ghi tên yếu tố đó vào thieu_du_lieu. Thời tiết KHÔNG ghi vào đây (code tra dự báo khi biết ngày đi).
- Hôm nay là {HOM_NAY}. Người dùng nói ngày đi ("5/12", "thứ Bảy này", "cuối tuần sau", "mai") -> ngay_bat_dau là ngày đầu tiên dạng YYYY-MM-DD; không nói -> null. KHÔNG hỏi lại chỉ vì thiếu ngày đi.
- gio_bat_dau mặc định "07:30"; "trưa", "từ 13h" -> "13:00"; "16h30" -> "16:30". ngan_sach_moi_nguoi bằng đồng (0 nếu không nói).
- Nếu có "Lộ trình trước" và "Sửa:", áp yêu cầu sửa vào yêu cầu gốc (bỏ điểm -> bo_diem, thêm điểm -> diem_muon_di).

Ví dụ mẫu (tham khảo cách đếm và tách trường):
1) Input: "Mình với 2 bạn đi Hà Nội 2 ngày muốn thăm Văn Miếu, Hồ Gươm." -> {"so_ngay":2,"nguoi_lon":3,"tuoi_tre_em":[],"so_thich":[],"tranh":[],"diem_muon_di":["Văn Miếu","Hồ Gươm"],"bo_diem":[],"gio_bat_dau":"07:30","ngan_sach_moi_nguoi":0,"tu_choi_them":[],"thieu_du_lieu":[],"trang_thai":"ok","cau_hoi":"","ly_do":""}
2) Input: "Lên lịch Huế 2 ngày 3 người và đặt giúp 1 phòng khách sạn." -> {"so_ngay":2,"nguoi_lon":3,"tuoi_tre_em":[],"so_thich":[],"tranh":[],"diem_muon_di":[],"bo_diem":[],"gio_bat_dau":"07:30","ngan_sach_moi_nguoi":0,"tu_choi_them":["đặt phòng khách sạn"],"thieu_du_lieu":[],"trang_thai":"ngoai_pham_vi","cau_hoi":"","ly_do":"Chỉ hỗ trợ lên lộ trình tại Hà Nội, không hỗ trợ Huế."}
3) Input: "Đi Hà Nội 2 ngày 2 người thích di tích, tránh chỗ đông dịp lễ." -> {"so_ngay":2,"nguoi_lon":2,"tuoi_tre_em":[],"so_thich":["di_tich"],"tranh":[],"diem_muon_di":[],"bo_diem":[],"gio_bat_dau":"07:30","ngan_sach_moi_nguoi":0,"tu_choi_them":[],"thieu_du_lieu":["độ đông và tình trạng ngày lễ"],"trang_thai":"ok","cau_hoi":"","ly_do":""}""" % ", ".join(TAGS)

SYSTEM_XEP = """Bạn xếp lộ trình đi chơi Hà Nội. Chỉ dùng id trong danh sách ung_vien. Trả về DUY NHẤT JSON theo đúng thứ tự trường sau:
{"phan_tich": "tóm tắt nhanh ràng buộc số ngày, giờ bắt đầu, ngân sách, điểm cần bỏ (không bịa số)",
 "bo": [{"id": id, "ly_do": "vì sao không xếp (KHÔNG tự ước giờ/phút/tiền)"}],
 "ngay": [[id, ...], ...],
 "ly_do": {"id": "1 câu vì sao chọn và vì sao ở vị trí này"}}

Luật bắt buộc:
- Đúng so_ngay ngày yêu cầu. Nếu số ung_vien >= so_ngay thì KHÔNG ĐƯỢC để ngày nào rỗng (chia đều điểm sang các ngày).
- Mỗi ngày xuất phát từ khách sạn ở phố cổ (ngày 1 từ gio_bat_dau_ngay_1, các ngày sau từ 07:30).
- Ưu tiên giữ điểm nguoi_dung_neu=true nếu kịp giờ mở/đóng cửa và vừa ngân sách. Nếu điểm nguoi_dung_neu=true phải bỏ vì quá giờ hoặc quá ngân sách -> đưa vào "bo" và gợi ý thêm ngày hoặc đổi điểm.
- Nếu tổng thời gian rảnh đủ, mỗi ngày trọn vẹn nên có tổng phut_tham_quan khoảng 240–420 phút (ít hơn nếu bắt đầu muộn, có trẻ em, hoặc ít ứng viên). Nếu còn ứng viên hợp sở thích chưa xếp mà ngày còn trống thời gian và vừa ngân sách thì xếp thêm.
- Khi ngan_sach_ve_moi_nguoi > 0: tổng gia_ve của các điểm đã chọn PHẢI <= ngan_sach_ve_moi_nguoi. Nếu tổng vé vượt ngân sách -> CHỦ ĐỘNG bỏ bớt điểm có gia_ve > 0 (ưu tiên giữ điểm miễn phí hoặc điểm hợp ý nhất) và ghi điểm bị bỏ vào "bo".
- Khi ngan_sach_ve_moi_nguoi = null: không giới hạn ngân sách, không được bỏ điểm vì giá vé.
- Có trẻ em hoặc ngại đi bộ: ít điểm hơn, ưu tiên điểm gần nhau và điểm có nhãn tre_em.
- Tôn trọng giờ mở/đóng: phải đến và tham quan xong trước giờ đóng cửa. Điểm chỉ mở buổi tối để cuối ngày.
- Gom điểm gần nhau (theo phut_di) trong cùng một ngày.
- Có thoi_tiet_tung_ngay: ngày kha_nang_mua cao (từ 60) ưu tiên bảo tàng và điểm ít đi ngoài trời; điểm ngoài trời (dao_pho, chup_anh, thien_nhien, ngoai_thanh) dời sang ngày khô hơn nếu được. Lý do được nhắc thời tiết, không ghi số.
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
    nay = hom_nay()
    doc = _json(call_model(SYSTEM_DOC.replace("{HOM_NAY}", "%s, %s" % (_THU[nay.weekday()], nay.isoformat())),
                           clean_text))
    if doc is None:
        note("dừng: model không trả JSON ở bước đọc yêu cầu")
        return {"output": "Xin lỗi, chưa đọc được yêu cầu. Bạn ghi rõ số ngày, số người và sở thích giúp mình nhé."}

    tu_choi_them = [x for x in (doc.get("tu_choi_them") or []) if "tính tiền vé" not in x.lower()]
    if doc.get("trang_thai") == "ngoai_pham_vi":
        parts = ["Hiện mình chỉ có dữ liệu điểm tham quan ở Hà Nội, nên không lập được lộ trình này."]
        if doc.get("ly_do"):
            parts.append(doc["ly_do"])
        for x in tu_choi_them:
            parts.append("Mình cũng không làm được: %s. Phần này bạn tự thực hiện trên kênh chính thức." % x)
        return {"output": " ".join(parts)}

    # Gate chống dừng sớm: chỉ hỏi lại khi thực sự thiếu số ngày (hoặc test mock đặt hoi_lai khi chưa nêu điểm)
    if not doc.get("so_ngay") or (doc.get("trang_thai") == "hoi_lai" and not doc.get("diem_muon_di")):
        return {"output": doc.get("cau_hoi") or "Bạn đi Hà Nội mấy ngày, mấy người, và thích kiểu chỗ nào?"}

    so_ngay = int(doc["so_ngay"])
    nguoi_lon = int(doc.get("nguoi_lon") or 1)
    tuoi = doc.get("tuoi_tre_em") or []
    ngan_sach = int(doc.get("ngan_sach_moi_nguoi") or 0)
    gio = doc.get("gio_bat_dau") or "07:30"
    notes = ["Dữ liệu chỉ có 14 điểm ở Hà Nội; giờ mở cửa và giá vé là số mẫu, kiểm lại trước khi đi."]
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

    so_thich = doc.get("so_thich") or []
    tranh = doc.get("tranh") or []
    found = tim_diem(so_thich, tranh, doc.get("diem_muon_di") or [])
    for ten in found["khong_tim_thay"]:
        notes.append("Không có dữ liệu về \"%s\" nên không xếp giờ / giá cho điểm này." % ten)

    bo = {p["id"] for p in tim_diem([], [], doc.get("bo_diem") or [])["diem"]} if doc.get("bo_diem") else set()
    ung_vien = [p for p in found["diem"] if p["id"] not in bo]

    # Gate phát hiện sở thích bị bộ lọc `tranh` loại sạch (vd thích trải nghiệm nhưng tránh ngoại thành)
    for st in so_thich:
        co_trong_data = any(st in p["so_thich"] for p in POI.values())
        con_trong_uv = any(st in p["so_thich"] for p in ung_vien)
        if co_trong_data and not con_trong_uv and tranh:
            notes.append(
                "Dữ liệu hiện không có điểm '%s' thỏa điều kiện tránh '%s' (các điểm '%s' có sẵn đều nằm ở nhóm bị tránh)."
                % (st, ", ".join(tranh), st)
            )

    if not ung_vien:
        prefix = (doc.get("ly_do") + " ") if doc.get("ly_do") else ""
        return {
            "output": "%sDữ liệu hiện không có điểm nào hợp sở thích bạn nêu. Các loại điểm đang có: %s. "
                      "Bạn muốn chọn loại nào?" % (prefix, ", ".join(TAGS)),
            "itinerary": None,
        }

    phut = thoi_gian_di([p["id"] for p in ung_vien])
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
    du_bao = _lay_thoi_tiet(ngay_di, so_ngay, notes)
    if any(du_bao):
        yeu_cau["thoi_tiet_tung_ngay"] = [x and {"mo_ta": x["mo_ta"], "kha_nang_mua": x["kha_nang_mua"]} for x in du_bao]
    loi, plan, kq = [], None, None
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
        kq = kiem_lich_trinh(ngay, gio, nguoi_lon, tuoi, ngan_sach)
        loi = list(kq["vi_pham"])
        if len(ung_vien) >= so_ngay and (len(ngay) < so_ngay or any(not d for d in ngay)):
            loi.append("Phải chia điểm đủ %d ngày và không để ngày nào trống" % so_ngay)
        if not loi:
            break
        note("lượt %d: %d vi phạm" % (lan, len(loi)))

    if kq is None:
        return {"output": "Xin lỗi, lần này chưa xếp được lộ trình. Bạn thử gửi lại giúp mình.", "itinerary": None}
    return _dung_output(kq, plan, notes, phut, ung_vien, so_ngay, ngay_di, du_bao)


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


def _dung_output(kq, plan, notes, phut, ung_vien, so_ngay, ngay_di=None, du_bao=None):
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
    for s in (s for d in days_nonempty for s in d["stops"]):
        s["reason"] = ly_do.get(s["id"], "")
    for b in plan.get("bo") or []:
        bid = b.get("id")
        if bid in POI:
            p = POI[bid]
            go_min = phut.get("khach_san>" + bid)
            info = "mở %s–%s, tham quan %d phút" % (p["mo"], p["dong"], p["phut_tham_quan"])
            if go_min is not None:
                info += ", đi từ khách sạn %d phút" % go_min
            extra = " (gợi ý: có thể thêm ngày hoặc điều chỉnh ngân sách/điểm)" if bid in user_ids else ""
            notes.append("Không xếp %s (%s): %s%s" % (p["ten"], info, b.get("ly_do", ""), extra))
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
        lines.append(tieu_de)
        for s in d["stops"]:
            lines.append("- %s · %s (đi %d phút, tham quan %d phút, vé %sđ, mở %s–%s): %s"
                         % (s["arrive"], s["name"], s["travel_min_from_prev"], s["visit_min"],
                            f"{s['ticket_vnd']:,}", s["mo"], s["dong"], s["reason"]))
        lines.append("  Kết thúc %s, về khách sạn khoảng %s" % (d["ket_thuc"], d["ve_khach_san"]))
    lines.append("\nTổng vé %sđ (%sđ/người) · taxi ước tính %sđ"
                 % (f"{kq['total_vnd']:,}", f"{kq['per_person_vnd']:,}", f"{kq['xe_vnd']:,}"))
    lines += ["\nLưu ý:"] + ["- " + n for n in notes]

    for d in days_nonempty:  # link Google Maps cho app — không đưa vào output chữ (toạ độ không phải số của công cụ)
        ids = [s["id"] for s in d["stops"]]
        for k, s in enumerate(d["stops"]):
            s["maps_url"] = link_google_maps([s["id"]], tu=ids[k - 1] if k else None)
        # trình duyệt di động chỉ nhận tối đa 3 điểm dừng giữa đường → mỗi link tối đa 4 điểm, link sau nối tiếp link trước
        d["maps_urls"] = [link_google_maps(ids[i:i + 4], tu=ids[i - 1] if i else None) for i in range(0, len(ids), 4)]
    itinerary = {"days": [{"day": d["day"], "date": d.get("date"), "weather": d.get("weather"),
                           "stops": d["stops"], "maps_urls": d["maps_urls"]} for d in days_nonempty],
                 "total_vnd": kq["total_vnd"], "per_person_vnd": kq["per_person_vnd"],
                 "taxi_vnd": kq["xe_vnd"], "feasible": feasible, "notes": notes}
    return {"output": _an_the("\n".join(lines)), "itinerary": itinerary}
