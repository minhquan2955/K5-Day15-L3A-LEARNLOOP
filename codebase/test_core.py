"""Tự kiểm phần tính bằng code + luồng agent với model giả lập JSON. Chạy: python codebase/test_core.py"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import agent  # noqa: E402
from tools import kiem_lich_trinh, thoi_gian_di, tim_diem  # noqa: E402

# B06: bắt đầu 13:00 thì lăng Bác (đóng 10:30) phải báo vi phạm
assert any("Lăng" in v for v in kiem_lich_trinh([["lang_bac", "van_mieu"]], "13:00", 2, [])["vi_pham"])
# Sáng sớm thì xếp được
assert kiem_lich_trinh([["lang_bac", "van_mieu"]], "07:30", 2, [])["vi_pham"] == []
# B13: trẻ 5 tuổi miễn vé (dưới 6) → chỉ 2 người lớn trả: (70k + 50k) × 2
assert kiem_lich_trinh([["van_mieu", "ho_guom"]], "08:00", 2, [5, 5])["total_vnd"] == 240000
# Tuổi chưa biết → tính như người lớn
assert kiem_lich_trinh([["van_mieu"]], "08:00", 1, [None])["total_vnd"] == 140000
# B05: vượt ngân sách được báo
assert any("vượt ngân sách" in v for v in kiem_lich_trinh(
    [["hoang_thanh", "van_mieu", "hoa_lo"]], "08:00", 4, [], 150000)["vi_pham"])
# B08: điểm ngoài dữ liệu
r = tim_diem([], [], ["Văn Miếu", "Bảo tàng Mỹ thuật Việt Nam"])
assert [p["id"] for p in r["diem"]] == ["van_mieu"] and r["khong_tim_thay"] == ["Bảo tàng Mỹ thuật Việt Nam"]
# tránh nhãn
assert all("bao_tang" not in p["so_thich"] for p in tim_diem(["lich_su"], ["bao_tang"], [])["diem"])
assert thoi_gian_di(["van_mieu"])["khach_san>van_mieu"] > 5

# Luồng agent với model giả trả JSON
replies = []
agent.call_model = lambda system, user: {"text": json.dumps(replies.pop(0)), "model": "stub", "tokens_in": 0, "tokens_out": 0}

replies[:] = [{"trang_thai": "hoi_lai", "cau_hoi": "Bạn đi mấy ngày?"}]
assert agent.answer("nên đi đâu?")["output"] == "Bạn đi mấy ngày?"

replies[:] = [{"trang_thai": "ok", "so_ngay": 1, "nguoi_lon": 2, "tuoi_tre_em": [], "diem_muon_di": ["lăng bác", "văn miếu"],
               "gio_bat_dau": "13:00", "tu_choi_them": []},
              {"ngay": [["lang_bac", "van_mieu"]], "ly_do": {}},
              {"ngay": [["lang_bac", "van_mieu"]], "ly_do": {}},
              {"ngay": [["van_mieu"]], "ly_do": {"van_mieu": "ok"}, "bo": [{"id": "lang_bac", "ly_do": "chỉ mở sáng"}]}]
r = agent.answer("từ 13h, lăng Bác và Văn Miếu")
assert r["itinerary"]["feasible"] and [s["id"] for s in r["itinerary"]["days"][0]["stops"]] == ["van_mieu"], r
assert "Không xếp Lăng" in r["output"]

replies[:] = [{"trang_thai": "ok", "so_ngay": 1, "nguoi_lon": 2, "diem_muon_di": ["hoàng thành"], "tu_choi_them": ["đặt vé"]},
              {"ngay": [["hoang_thanh", "id_bia"]], "ly_do": {}}]
r = agent.answer("Hoàng thành, đặt vé giúp, thẻ 4111 1111 1111 1111")
assert "4111" not in r["output"] and "id_bia" not in r["output"] and r["itinerary"]["feasible"]

# --- Thời tiết (Open-Meteo) + link Google Maps — thay lời gọi mạng bằng dữ liệu giả ---
import datetime  # noqa: E402
import tools  # noqa: E402

DOC2 = {"trang_thai": "ok", "so_ngay": 2, "nguoi_lon": 2, "diem_muon_di": ["lăng bác", "văn miếu", "hồ gươm"]}
PLAN2 = {"ngay": [["lang_bac", "van_mieu"], ["ho_guom"]], "ly_do": {}}
goi = []


def du_bao_gia(url):
    goi.append(url)
    return {"daily": {"time": [(tools.hom_nay() + datetime.timedelta(days=k)).isoformat() for k in (1, 2)],
                      "weather_code": [63, 1], "temperature_2m_min": [19.6, 18.2], "temperature_2m_max": [24.8, 26.1],
                      "precipitation_probability_max": [80, 10], "precipitation_sum": [12.34, 0.0]}}


tools._tai_du_bao = du_bao_gia
mai = (tools.hom_nay() + datetime.timedelta(days=1)).isoformat()
replies[:] = [dict(DOC2, ngay_bat_dau=mai), PLAN2]
r = agent.answer("x")
assert len(goi) == 1 and "start_date=" + mai in goi[0]
assert "Mưa vừa, 20–25°C, khả năng mưa 80%" in r["output"] and "Ngày 1 khả năng mưa cao" in r["output"]
assert "Open-Meteo.com" in r["output"] and r["itinerary"]["days"][1]["weather"]["mo_ta"] == "Ít mây"
assert r["itinerary"]["days"][0]["date"] == mai
# Link Google Maps: có trong itinerary, không có trong output chữ
d1 = r["itinerary"]["days"][0]
assert d1["maps_urls"][0].startswith("https://www.google.com/maps/dir/?api=1&destination=21.0287%2C105.8355")
assert "origin" not in d1["stops"][0]["maps_url"] and "origin=21.0368%2C105.8346" in d1["stops"][1]["maps_url"]
assert "google.com" not in r["output"]
# Không nói ngày đi → không gọi mạng; hỏi thời tiết thì nhắc cho biết ngày, không báo "thiếu dữ liệu thời tiết"
goi.clear()
replies[:] = [dict(DOC2, thieu_du_lieu=["thời tiết"]), PLAN2]
r = agent.answer("Hà Nội có mưa không?")
assert not goi and "Cho mình biết ngày đi" in r["output"] and "thông tin về thời tiết" not in r["output"]
assert r["itinerary"]["days"][0]["weather"] is None
# Ngày quá 16 ngày tới → nói rõ, vẫn có lịch
replies[:] = [dict(DOC2, ngay_bat_dau=(tools.hom_nay() + datetime.timedelta(days=30)).isoformat()), PLAN2]
r = agent.answer("x")
assert not goi and "dự báo chỉ có đến" in r["output"] and r["itinerary"]["feasible"]


def mat_mang(url):
    raise OSError("mất mạng")


tools._tai_du_bao = mat_mang  # API lỗi → chỉ ghi chú, lịch vẫn ra
replies[:] = [dict(DOC2, ngay_bat_dau=mai), PLAN2]
r = agent.answer("x")
assert "chưa lấy được dự báo" in r["output"] and r["itinerary"]["feasible"]

# --- Lỗi thấy khi chạy thật với Gemini (28/11): lý do sai, chiều trống, tiền taxi lẻ ---
DOC_THAT = {"trang_thai": "ok", "so_ngay": 2, "nguoi_lon": 2, "so_thich": ["di_tich", "am_thuc"],
            "diem_muon_di": ["lăng bác", "văn miếu", "hồ gươm", "phố đi bộ"]}
PLAN_THAT = {"ngay": [["lang_bac", "chua_mot_cot", "hoang_thanh", "van_mieu"], ["ho_guom", "dong_xuan", "pho_di_bo"]],
             "ly_do": {"lang_bac": "Điểm tham quan buổi sáng sớm để đảm bảo giờ mở cửa và tránh đông đúc.",
                       "chua_mot_cot": "Nằm ngay cạnh Lăng Bác, thuận tiện di chuyển tiếp nối.",
                       "hoang_thanh": "Tối ưu đường đi vì gần cụm Ba Đình.",
                       "van_mieu": "Điểm di tích quan trọng, xếp vào buổi chiều để hoàn thành ngày đầu.",
                       "pho_di_bo": "Chỉ mở vào buổi tối, kết thúc ngày thứ hai."}}
replies[:] = [DOC_THAT, PLAN_THAT]
r = agent.answer("x")
ly_do = {s["id"]: s["reason"] for d in r["itinerary"]["days"] for s in d["stops"]}
# 1. Lý do nhắc độ đông (dữ liệu không có) / "buổi chiều" khi đến lúc 10:xx → thay bằng lý do do code viết
assert "đông" not in r["output"] and "buổi chiều" not in r["output"]
assert ly_do["lang_bac"] == "Bạn muốn đi điểm này; hợp sở thích di tích; chỉ mở buổi sáng nên xếp sớm.", ly_do["lang_bac"]
assert ly_do["van_mieu"].startswith("Bạn muốn đi điểm này")
# Lý do đúng thì giữ nguyên ("tối ưu" không phải buổi tối; "buổi tối" khớp giờ đến 19:00)
assert ly_do["chua_mot_cot"] == PLAN_THAT["ly_do"]["chua_mot_cot"]
assert ly_do["hoang_thanh"] == PLAN_THAT["ly_do"]["hoang_thanh"]
assert ly_do["pho_di_bo"] == PLAN_THAT["ly_do"]["pho_di_bo"]
# 2. Ngày 2 trống từ trưa đến tối → nói rõ khung trống + gợi ý điểm mở cửa vừa khung
assert "Ngày 2 trống từ" in r["output"] and "Có thể thêm:" in r["output"], r["output"]
assert "Ngày 1 trống" not in r["output"]
# 3. Tiền taxi làm tròn nghìn (trong công cụ, nên vẫn khớp công cụ)
assert r["itinerary"]["taxi_vnd"] % 1000 == 0
assert kiem_lich_trinh([["van_mieu", "ho_guom"]], "08:00", 2, [])["xe_vnd"] % 1000 == 0
print("OK: test_core")
