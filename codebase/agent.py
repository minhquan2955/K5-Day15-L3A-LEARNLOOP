"""Luồng chính — workflow cố định đúng sơ đồ spec.md §4.

1. AI đọc yêu cầu → JSON (số ngày, người, sở thích, điểm muốn đi) · thiếu số ngày → hỏi lại · ngoài phạm vi → từ chối
2. tim_diem (code) → điểm khớp + điểm không có dữ liệu
3. thoi_gian_di (code) → phút đi mọi cặp
4. AI chia điểm theo ngày + thứ tự + lý do → JSON
5. kiem_lich_trinh (code) → còn vi phạm thì quay lại 4, tối đa MAX_SUA lượt
Output dựng bằng code từ kết quả kiem_lich_trinh: model không ghi con số nào.
"""
import json
import re

from ai import call_model
from tools import POI, TAGS, kiem_lich_trinh, thoi_gian_di, tim_diem
from tracing import note

MAX_SUA = 2
_THE = re.compile(r"(?:\d[ -]?){12,19}")

SYSTEM_DOC = """Bạn đọc yêu cầu lên lịch đi chơi của người lần đầu đến Hà Nội và trả về DUY NHẤT một JSON:
{"trang_thai": "ok" | "hoi_lai" | "ngoai_pham_vi",
 "so_ngay": int|null, "nguoi_lon": int|null, "tuoi_tre_em": [int|null, ...],
 "so_thich": [nhãn], "tranh": [nhãn], "diem_muon_di": [tên điểm người dùng nêu, giữ nguyên chữ],
 "bo_diem": [tên điểm người dùng muốn bỏ], "gio_bat_dau": "HH:MM",
 "ngan_sach_moi_nguoi": int (đồng, 0 nếu không nói),
 "cau_hoi": "câu hỏi lại nếu hoi_lai", "ly_do": "nếu ngoai_pham_vi",
 "tu_choi_them": ["việc người dùng đòi mà sản phẩm không làm: đặt vé, thanh toán, sửa giờ/giá theo ý..."]}
Luật:
- Nhãn chỉ được lấy trong: %s. Map sở thích tự nhiên sang nhãn gần nhất; không có nhãn nào gần thì để so_thich rỗng.
- Thiếu số ngày → trang_thai "hoi_lai", hỏi số ngày (và số người, sở thích nếu cũng thiếu). Thiếu số người thì mặc định 1 người lớn.
- Thành phố khác Hà Nội → "ngoai_pham_vi". Đòi đặt vé / chuyển tiền / sửa giờ mở cửa → vẫn "ok" nhưng ghi vào tu_choi_them.
- gio_bat_dau mặc định "07:30"; "trưa", "từ 13h" → "13:00".
- Nếu có "Lộ trình trước" và "Sửa:", áp yêu cầu sửa vào yêu cầu gốc (bỏ điểm → bo_diem, thêm điểm → diem_muon_di).
- "trẻ em" không rõ tuổi → null trong tuoi_tre_em.""" % ", ".join(TAGS)

SYSTEM_XEP = """Bạn xếp lộ trình đi chơi Hà Nội. Chỉ dùng id trong danh sách ứng viên. Trả về DUY NHẤT JSON:
{"ngay": [[id, ...], ...], "ly_do": {"id": "1 câu vì sao chọn và vì sao ở vị trí này"},
 "bo": [{"id": id, "ly_do": "vì sao không xếp"}]}
Luật:
- Đúng số ngày yêu cầu. Mỗi ngày xuất phát từ khách sạn ở phố cổ.
- Điểm người dùng tự nêu (nguoi_dung_neu=true) ưu tiên giữ. Điểm khác: mỗi ngày trọn vẹn cần tổng phut_tham_quan
  khoảng 300–420 phút (ít hơn nếu bắt đầu muộn hoặc có trẻ em). Một ngày chỉ 1–2 điểm ngắn là QUÁ THƯA, phải thêm điểm.
  Ứng viên còn thừa thì dùng; chỉ bỏ khi không còn chỗ trong ngày.
- ngan_sach_ve_moi_nguoi = null nghĩa là KHÔNG giới hạn ngân sách: không được bỏ điểm vì giá vé.
- Có trẻ em hoặc người dùng nói ngại đi bộ: ít điểm hơn, ưu tiên điểm gần nhau.
- Tôn trọng giờ mở/đóng: đến + phút tham quan phải xong trước giờ đóng. Điểm chỉ mở buổi tối để cuối ngày.
- Gom điểm gần nhau (dùng bảng phút đi) cho cùng một ngày.
- Nếu không thể xếp đủ, bỏ điểm ít hợp ý người dùng nhất và ghi vào "bo".
- KHÔNG ghi giờ, phút, giá tiền trong ly_do: code sẽ tính."""


def _json(reply):
    m = re.search(r"\{.*\}", reply["text"], re.S)
    try:
        return json.loads(m.group(0)) if m else None
    except ValueError:
        return None


def _an_the(s):
    return _THE.sub("[số thẻ đã ẩn]", s)


def answer(text: str) -> dict:
    text = _an_the(text)  # không gửi số thẻ cho model, không bao giờ in lại
    doc = _json(call_model(SYSTEM_DOC, text))
    if doc is None:
        note("dừng: model không trả JSON ở bước đọc yêu cầu")
        return {"output": "Xin lỗi, chưa đọc được yêu cầu. Bạn ghi rõ số ngày, số người và sở thích giúp mình nhé."}
    if doc.get("trang_thai") == "ngoai_pham_vi":
        return {"output": "Hiện mình chỉ có dữ liệu điểm tham quan ở Hà Nội, nên không lập được lộ trình này. %s"
                % (doc.get("ly_do") or "")}
    if doc.get("trang_thai") == "hoi_lai" or not doc.get("so_ngay"):
        return {"output": doc.get("cau_hoi") or "Bạn đi Hà Nội mấy ngày, mấy người, và thích kiểu chỗ nào?"}

    so_ngay = int(doc["so_ngay"])
    nguoi_lon = int(doc.get("nguoi_lon") or 1)
    tuoi = doc.get("tuoi_tre_em") or []
    ngan_sach = int(doc.get("ngan_sach_moi_nguoi") or 0)
    gio = doc.get("gio_bat_dau") or "07:30"
    notes = ["Dữ liệu chỉ có 14 điểm ở Hà Nội; giờ mở cửa và giá vé là số mẫu, kiểm lại trước khi đi."]
    for x in doc.get("tu_choi_them") or []:
        notes.append("Mình không làm được: %s. Phần này bạn tự làm trên kênh chính thức." % x)
    if "[số thẻ đã ẩn]" in text:
        notes.append("Đừng gửi số thẻ cho bất kỳ ai; mình không lưu và không dùng nó.")
    if any(a is None for a in tuoi):
        notes.append("Chưa biết tuổi trẻ em nên vé trẻ em tính như người lớn.")

    found = tim_diem(doc.get("so_thich") or [], doc.get("tranh") or [], doc.get("diem_muon_di") or [])
    for ten in found["khong_tim_thay"]:
        notes.append("Không có dữ liệu về \"%s\" nên không xếp giờ / giá cho điểm này." % ten)
    bo = {p["id"] for p in tim_diem([], [], doc.get("bo_diem") or [])["diem"]} if doc.get("bo_diem") else set()
    ung_vien = [p for p in found["diem"] if p["id"] not in bo]
    if not ung_vien:
        return {"output": "Dữ liệu hiện không có điểm nào hợp sở thích bạn nêu. Các loại điểm đang có: %s. "
                          "Bạn muốn chọn loại nào?" % ", ".join(TAGS), "itinerary": None}

    phut = thoi_gian_di([p["id"] for p in ung_vien])
    if not ngan_sach:  # không có ngân sách thì model không cần giá (tiền do code tính) — tránh bịa lý do "vượt ngân sách"
        ung_vien = [{k: v for k, v in p.items() if k not in ("gia_ve", "tre_em_mien_phi_duoi")} for p in ung_vien]
    yeu_cau = {"so_ngay": so_ngay, "gio_bat_dau_ngay_1": gio, "cac_ngay_sau_bat_dau": "07:30",
               "nguoi_lon": nguoi_lon, "tuoi_tre_em": tuoi, "so_thich": doc.get("so_thich"),
               "tranh": doc.get("tranh"), "ngan_sach_ve_moi_nguoi": ngan_sach or None,
               "ung_vien": ung_vien, "phut_di": phut}
    loi, plan, kq = [], None, None
    for lan in range(MAX_SUA + 1):
        user = json.dumps(dict(yeu_cau, vi_pham_lan_truoc=loi, lich_lan_truoc=plan and plan.get("ngay")),
                          ensure_ascii=False)
        moi = _json(call_model(SYSTEM_XEP, user))
        if moi is None:
            note("lượt %d: model không trả JSON" % lan)
            continue
        plan = moi
        ids = {p["id"] for p in ung_vien}
        ngay = [[i for i in d if i in ids] for d in (plan.get("ngay") or [])][:so_ngay]  # loại id lạ
        kq = kiem_lich_trinh(ngay, gio, nguoi_lon, tuoi, ngan_sach)
        loi = kq["vi_pham"]
        if not loi:
            break
        note("lượt %d: %d vi phạm" % (lan, len(loi)))

    if kq is None:
        return {"output": "Xin lỗi, lần này chưa xếp được lộ trình. Bạn thử gửi lại giúp mình.", "itinerary": None}
    return _dung_output(kq, plan, notes)


def _dung_output(kq, plan, notes):
    ly_do = plan.get("ly_do") or {}
    feasible = not kq["vi_pham"]
    for s in (s for d in kq["days"] for s in d["stops"]):
        s["reason"] = ly_do.get(s["id"], "")
    for b in plan.get("bo") or []:
        if b.get("id") in POI:
            notes.append("Không xếp %s: %s" % (POI[b["id"]]["ten"], b.get("ly_do", "")))
    if not feasible:
        notes.append("KHÔNG XẾP ĐƯỢC trọn vẹn: " + "; ".join(kq["vi_pham"]) +
                     ". Cách nới: bỏ bớt điểm, thêm ngày, hoặc tăng ngân sách.")

    lines = ["Lộ trình gợi ý" if feasible else "Chưa xếp được trọn vẹn — xem lưu ý cuối"]
    for d in kq["days"]:
        lines.append("\nNgày %d" % d["day"])
        for s in d["stops"]:
            lines.append("- %s · %s (đi %d phút, tham quan %d phút, vé %sđ, mở %s–%s): %s"
                         % (s["arrive"], s["name"], s["travel_min_from_prev"], s["visit_min"],
                            f"{s['ticket_vnd']:,}", s["mo"], s["dong"], s["reason"]))
        lines.append("  Kết thúc %s, về khách sạn khoảng %s" % (d["ket_thuc"], d["ve_khach_san"]))
    lines.append("\nTổng vé %sđ (%sđ/người) · taxi ước tính %sđ"
                 % (f"{kq['total_vnd']:,}", f"{kq['per_person_vnd']:,}", f"{kq['xe_vnd']:,}"))
    lines += ["\nLưu ý:"] + ["- " + n for n in notes]

    itinerary = {"days": [{"day": d["day"], "stops": d["stops"]} for d in kq["days"]],
                 "total_vnd": kq["total_vnd"], "per_person_vnd": kq["per_person_vnd"],
                 "taxi_vnd": kq["xe_vnd"], "feasible": feasible, "notes": notes}
    return {"output": _an_the("\n".join(lines)), "itinerary": itinerary}
