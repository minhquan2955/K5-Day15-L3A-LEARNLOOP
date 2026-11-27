"""Test tích hợp lưu trữ P0 với PostgreSQL thật (đã áp db/migrations 001, 002, seed, 003).

  DATABASE_URL=postgresql://learnloop:...@localhost:5432/learnloop python server/test_luu_tru.py
Không có DATABASE_URL → bỏ qua (in SKIP), không lỗi.
"""
import os
import sys
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luu_tru  # noqa: E402

if not os.environ.get("DATABASE_URL"):
    print("SKIP: test_luu_tru (chưa có DATABASE_URL)")
    sys.exit(0)

assert luu_tru.bat()
nd, khac = str(uuid.uuid4()), str(uuid.uuid4())

# Người dùng ẩn danh: chưa đồng ý thì không ghi sự kiện
assert luu_tru.dang_ky(nd, False) == {"nguoi_dung": nd, "dong_y": False}
assert luu_tru.ghi_su_kien(nd, [{"loai": "mo_man_hinh", "luc": "2026-11-28T08:00:00+07:00", "du_lieu": {"man": "chat"}}])["nhan"] == 0
# Đồng ý → ghi; loại lạ bị bỏ; trường không được phép / nội dung tự do bị lọc
luu_tru.dang_ky(nd, True)
kq = luu_tru.ghi_su_kien(nd, [
    {"loai": "mo_man_hinh", "luc": "2026-11-28T08:00:00+07:00", "du_lieu": {"man": "chat", "toa_do": "21.03,105.85"}},
    {"loai": "gui_yeu_cau", "luc": "2026-11-28T08:00:05+07:00",
     "du_lieu": {"so_ky_tu": 80, "noi_dung": "Đi Hà Nội 2 ngày…"}},
    {"loai": "hack_he_thong", "luc": "x"},
])
assert kq["nhan"] == 2, kq
dong = luu_tru._chay("SELECT loai, du_lieu FROM learnloop.su_kien WHERE nguoi_dung_id = CAST(:id AS uuid) ORDER BY luc", id=nd)
assert [d[0] for d in dong] == ["mo_man_hinh", "gui_yeu_cau"]
assert dong[0][1] == {"man": "chat"} and dong[1][1] == {"so_ky_tu": 80}, dong  # không lưu toạ độ, không lưu nội dung câu hỏi

# Lưu chuyến từ itinerary dạng /api/plan
it = {"days": [
    {"day": 1, "date": "2026-11-29", "stops": [
        {"id": "lang_bac", "name": "Lăng Chủ tịch Hồ Chí Minh", "arrive": "07:41", "visit_min": 60,
         "travel_min_from_prev": 11, "ticket_vnd": 0, "reason": "Chỉ mở buổi sáng."},
        {"id": "van_mieu", "name": "Văn Miếu – Quốc Tử Giám", "arrive": "08:50", "visit_min": 75,
         "travel_min_from_prev": 9, "ticket_vnd": 140000, "reason": ""}]},
    {"day": 2, "stops": [
        {"id": "khong_co", "name": "Điểm lạ", "arrive": "19:00", "visit_min": 90, "travel_min_from_prev": 6,
         "ticket_vnd": 0}]}],
    "feasible": True, "total_vnd": 140000, "per_person_vnd": 70000, "taxi_vnd": 81000, "notes": ["Dữ liệu mẫu."]}
luu = luu_tru.luu_chuyen(nd, "Hà Nội 2 ngày", it)
cd = luu["chuyen_di"]
assert [(d["ngay_thu"], d["thu_tu"]) for d in luu["diem"]] == [(1, 1), (1, 2), (2, 1)]
ds = luu_tru.danh_sach_chuyen(nd)["chuyen_di"]
assert len(ds) == 1 and ds[0]["ngay_bat_dau"] == "2026-11-29" and ds[0]["itinerary"]["days"][1]["date"] == "2026-11-30"
s0 = ds[0]["itinerary"]["days"][0]["stops"]
assert s0[0]["id"] == "lang_bac" and s0[0]["arrive"] == "07:41" and s0[1]["ticket_vnd"] == 140000
assert ds[0]["itinerary"]["days"][1]["stops"][0]["id"] is None  # điểm không có trong dữ liệu: giữ tên, không gắn khoá ngoài
assert luu_tru._chay("SELECT buoi FROM learnloop.diem_dung WHERE chuyen_di_id = CAST(:cd AS uuid) ORDER BY ngay_thu, thu_tu",
                     cd=cd) == [["sang"], ["sang"], ["toi"]]

# Check-in: chủ chuyến được, người khác không
assert luu_tru.check_in(nd, cd, 1, 1, True)["xong_luc"]
assert luu_tru.danh_sach_chuyen(nd)["chuyen_di"][0]["itinerary"]["days"][0]["stops"][0]["xong_luc"]
assert luu_tru.check_in(nd, cd, 1, 1, False)["xong_luc"] is None
try:
    luu_tru.check_in(khac, cd, 1, 1, True)
    raise AssertionError("người khác không được check-in")
except luu_tru.SaiDuLieu:
    pass
# Sự kiện gắn chuyến của người khác → chuyen_di_id bỏ trống
luu_tru.dang_ky(khac, True)
luu_tru.ghi_su_kien(khac, [{"loai": "luu_trip", "luc": "2026-11-28T09:00:00+07:00", "chuyen_di": cd}])
assert luu_tru._chay("SELECT chuyen_di_id FROM learnloop.su_kien WHERE nguoi_dung_id = CAST(:id AS uuid)", id=khac) == [[None]]

# Dữ liệu sai → SaiDuLieu (HTTP 400)
for ham, args in [(luu_tru.dang_ky, ("khong-phai-uuid", True)), (luu_tru.luu_chuyen, (nd, "x", {"days": []})),
                  (luu_tru.luu_chuyen, (nd, "x", {"days": [{"stops": []}] * 4}))]:
    try:
        ham(*args)
        raise AssertionError("phải báo SaiDuLieu: %s" % ham.__name__)
    except luu_tru.SaiDuLieu:
        pass

# Xoá dữ liệu của tôi: xoá hết chuyến, điểm dừng, sự kiện
assert luu_tru.xoa_nguoi_dung(nd) == {"da_xoa": True}
assert luu_tru._chay("SELECT count(*) FROM learnloop.su_kien WHERE nguoi_dung_id = CAST(:id AS uuid)", id=nd) == [[0]]
assert luu_tru._chay("SELECT count(*) FROM learnloop.chuyen_di WHERE id = CAST(:cd AS uuid)", cd=cd) == [[0]]
luu_tru.xoa_nguoi_dung(khac)
# Hàm dọn sự kiện cũ chạy được
assert luu_tru._chay("SELECT learnloop.xoa_su_kien_cu(90)")[0][0] >= 0

# Không có DB → BatTat (API trả 503)
os.environ["DATABASE_URL"] = "postgresql://x:y@127.0.0.1:1/z"
assert not luu_tru.bat()
print("OK: test_luu_tru")
