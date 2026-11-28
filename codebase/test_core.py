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
# B15, B22: tên lồng nhau — "Phố đi bộ Hồ Gươm" không được khớp nhầm Hồ Gươm
def ids_of(*ten):
    return [p["id"] for p in tim_diem([], [], list(ten))["diem"]]


assert ids_of("Phố đi bộ Hồ Gươm") == ["pho_di_bo"] and ids_of("Hồ Gươm") == ["ho_guom"]
assert ids_of("Hồ Gươm", "Phố đi bộ Hồ Gươm") == ["ho_guom", "pho_di_bo"]
assert ids_of("phố đi bộ") == ["pho_di_bo"] and ids_of("Hồ Gươm - Đền Ngọc Sơn") == ["ho_guom"]
assert ids_of("Hồ Tây") == ["tran_quoc"] and ids_of("Chợ Đồng Xuân") == ["dong_xuan"] and ids_of("Lăng Bác") == ["lang_bac"]
assert ids_of("hồm gươm") == ["ho_guom"]
assert ids_of("van meiu") == ["van_mieu"]

# Luồng agent với model giả trả JSON
replies = []
agent.call_model = lambda system, user: {"text": json.dumps(replies.pop(0)), "model": "stub", "tokens_in": 0, "tokens_out": 0}

r = agent.answer("Xin chào!")
assert "chào" in r["output"].lower() and "giúp gì" in r["output"] and not r.get("itinerary")

replies[:] = [{"trang_thai": "hoi_lai", "cau_hoi": "Bạn đi mấy ngày?"}]
r = agent.answer("nên đi đâu?")
assert "mấy ngày" in r["output"] and "lộ trình gợi ý" in r["output"] and not r["itinerary"]

replies[:] = [{"so_ngay": 1, "trang_thai": "hoi_lai"}]
r = agent.answer("Tôi muốn đi chơi trong 1 ngày")
assert "1 ngày" in r["output"] and "thích" in r["output"] and not r["itinerary"]

replies[:] = [{"so_ngay": 1, "chap_nhan_goi_y": True}, {"ngay": [["ho_guom", "dong_xuan"]]}]
r = agent.answer("Tôi muốn đi chơi trong 1 ngày\nLộ trình trước:\n" + r["output"] + "\n\nSửa: Có, gợi ý giúp mình")
assert r["itinerary"]["feasible"] and len(r["itinerary"]["days"]) == 1
assert "Chưa nêu sở thích" in r["output"] and "Bạn có thể" in r["output"]

replies[:] = [{"chap_nhan_goi_y": True}, {"ngay": [["ho_guom"]]}]
r = agent.answer("Cho mình một lộ trình gợi ý đi")
assert len(r["itinerary"]["days"]) == 1 and "gợi ý lịch 1 ngày" in r["output"]

replies[:] = [{"so_ngay": 1, "diem_muon_di": ["hồm gươm"]}, {"ngay": [["ho_guom"]]}]
assert agent.answer("Hà Nội 1 ngày, ghé hồm gươm")["itinerary"]["days"][0]["stops"][0]["id"] == "ho_guom"

replies[:] = [{"so_ngay": 1, "diem_muon_di": ["Bảo tàng Mỹ thuật Việt Nam"]}]
r = agent.answer("1 ngày, ghé Bảo tàng Mỹ thuật Việt Nam")
assert not r["itinerary"] and "Bảo tàng Mỹ thuật Việt Nam" in r["output"]

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

# --- Chế độ "đi lại ít nhất": tối ưu thứ tự + chia ngày theo hướng, chỗ ở người dùng ---
from tools import tim_noi_o, toi_uu_lo_trinh  # noqa: E402

# AI chia lộn xộn: trộn phía Tây (Dân tộc học, Lăng Bác, Văn Miếu) với phía Đông (Bát Tràng) — chỗ ở ở giữa (phố cổ)
TRON = [["bt_dan_toc_hoc", "ho_guom", "van_mieu"], ["bat_trang", "lang_bac", "dong_xuan", "hoa_lo"]]
o = toi_uu_lo_trinh(TRON, ["07:30", "07:30"])
assert o["da_doi"] and o["phut_di_sau"] < o["phut_di_truoc"], o
assert sorted(sum(o["ngay"], [])) == sorted(sum(TRON, [])) and all(o["ngay"])  # đủ điểm, không ngày nào trống
assert o["huong"][0] != o["huong"][1]  # mỗi ngày một hướng
assert not any("bat_trang" in d and "bt_dan_toc_hoc" in d for d in o["ngay"])  # không băng qua chỗ ở trong một ngày
assert kiem_lich_trinh(o["ngay"], ["07:30", "07:30"], 2, [])["vi_pham"] == []
# Thứ tự trong ngày tôn trọng giờ mở cửa: lăng Bác (đóng 10:30) phải đi sớm, phố đi bộ (mở 19:00) cuối ngày
o = toi_uu_lo_trinh([["pho_di_bo", "van_mieu", "lang_bac"]], "07:30")
assert o["ngay"][0][0] == "lang_bac" and o["ngay"][0][-1] == "pho_di_bo"
# Không thứ tự nào kịp (13:00 mà có lăng Bác) → giữ nguyên để kiem_lich_trinh báo vi phạm
o = toi_uu_lo_trinh([["lang_bac", "van_mieu"]], "13:00")
assert o["ngay"] == [["lang_bac", "van_mieu"]] and not o["da_doi"]

# Chỗ ở: khớp tên điểm trong dữ liệu thì không gọi mạng
goi.clear()
tools._tra_dia_chi = lambda q: goi.append(q) or []
c = tim_noi_o("khách sạn gần Hồ Tây")
assert c["nguon"] == "du_lieu" and c["ten"] == "gần Chùa Trấn Quốc – Hồ Tây" and not goi
# Không khớp → Nominatim (dữ liệu giả); ngoài Hà Nội / không thấy / mất mạng → báo lỗi
tools._tra_dia_chi = lambda q: [{"lat": "21.0340", "lon": "105.8510", "display_name": "20 Hàng Bạc, Hàng Bạc, Hoàn Kiếm"}]
assert tim_noi_o("20 Hàng Bạc") == {"ten": "20 Hàng Bạc, Hàng Bạc", "lat": 21.034, "lon": 105.851, "nguon": "openstreetmap"}
tools._tra_dia_chi = lambda q: [{"lat": "16.05", "lon": "108.20", "display_name": "Đà Nẵng"}]
assert "ngoài Hà Nội" in tim_noi_o("khách sạn Mường Thanh")["loi"]
tools._tra_dia_chi = lambda q: []
assert "không tìm thấy" in tim_noi_o("abc xyz")["loi"]
tools._tra_dia_chi = mat_mang
assert "chưa tra được" in tim_noi_o("abc xyz")["loi"]

# Luồng đầy đủ: người dùng ở gần Hồ Tây, muốn đỡ đi lòng vòng
replies[:] = [{"trang_thai": "ok", "so_ngay": 2, "nguoi_lon": 2, "noi_o": "khách sạn gần Hồ Tây", "che_do": "it_di_chuyen",
               "diem_muon_di": ["Dân tộc học", "Hồ Gươm", "Văn Miếu", "Bát Tràng", "Lăng Bác", "Đồng Xuân", "Hỏa Lò"]},
              {"ngay": TRON, "ly_do": {}}]
r = agent.answer("x")
assert "Xuất phát và về: gần Chùa Trấn Quốc – Hồ Tây" in r["output"], r["output"]
assert "Đã sắp lại để đi lại ít nhất" in r["output"] and " · đi phía" in r["output"] and "về chỗ ở khoảng" in r["output"]
assert r["itinerary"]["feasible"]
tai = [sum(s["visit_min"] for s in d["stops"]) for d in r["itinerary"]["days"]]
assert max(tai) <= 420 and min(tai) > 0, tai  # không dồn hết vào một ngày
assert "origin=21.048%2C105.8368" in r["itinerary"]["days"][0]["maps_urls"][0]  # link cả ngày đi từ chỗ ở
# Code dời điểm sang ngày khác / đổi vị trí → lý do AI viết cho chỗ cũ bị thay bằng lý do do code viết
replies[:] = [{"trang_thai": "ok", "so_ngay": 2, "nguoi_lon": 2, "che_do": "it_di_chuyen",
               "diem_muon_di": ["Dân tộc học", "Hồ Gươm", "Văn Miếu", "Bát Tràng", "Lăng Bác", "Đồng Xuân", "Hỏa Lò"]},
              {"ngay": TRON, "ly_do": {"ho_guom": "Kết thúc ngày đầu tiên gần khách sạn.",
                                        "bat_trang": "Trải nghiệm làng gốm hợp gia đình.",
                                        "van_mieu": "Di tích bạn muốn đi."}}]
r = agent.answer("x")
ld = {s["id"]: (d["day"], s["reason"]) for d in r["itinerary"]["days"] for s in d["stops"]}
assert "ngày đầu tiên" not in r["output"] and ld["ho_guom"][1].startswith("Bạn muốn đi điểm này"), ld
# Chế độ mặc định không đổi gì: không tối ưu, không ghi chú
replies[:] = [{"trang_thai": "ok", "so_ngay": 2, "nguoi_lon": 2,
               "diem_muon_di": ["Dân tộc học", "Hồ Gươm", "Văn Miếu", "Bát Tràng", "Lăng Bác", "Đồng Xuân", "Hỏa Lò"]},
              {"ngay": TRON, "ly_do": {}}, {"ngay": TRON, "ly_do": {}}, {"ngay": TRON, "ly_do": {}}]
r = agent.answer("x")  # lịch lộn xộn có vi phạm → lõi gọi lại model, không tự tối ưu ở chế độ mặc định
assert "đi lại ít nhất" not in r["output"] and [s["id"] for s in r["itinerary"]["days"][0]["stops"]] == TRON[0]

# --- B05: model sửa hết lượt vẫn vượt ngân sách → code tự bỏ điểm có vé cho vừa, nói rõ vượt bao nhiêu ---
B05V = {"trang_thai": "ok", "so_ngay": 1, "nguoi_lon": 4, "ngan_sach_moi_nguoi": 150000,
        "diem_muon_di": ["Hoàng thành", "Văn Miếu", "Hồ Gươm", "Hỏa Lò", "Bảo tàng Dân tộc học"]}
VUOT = {"ngay": [["ho_guom", "hoa_lo", "van_mieu"]],
        "ly_do": {"van_mieu": "Nằm trong ngân sách sau khi đã điều chỉnh."},
        "bo": [{"id": "hoang_thanh", "ly_do": "vượt ngân sách"}, {"id": "bt_dan_toc_hoc", "ly_do": "vượt ngân sách"}]}
replies[:] = [B05V, VUOT, VUOT, VUOT]
r = agent.answer("x")
assert r["itinerary"]["feasible"] and r["itinerary"]["per_person_vnd"] <= 150000, r["output"]
assert "Đi đủ các điểm bạn nêu thì tiền vé 280,000đ/người, vượt ngân sách 150,000đ/người 130,000đ" in r["output"]
assert "Để vừa ngân sách, lịch dưới đã bỏ" in r["output"] and "trong ngân sách" not in r["output"]
assert [s["id"] for s in r["itinerary"]["days"][0]["stops"]].count("van_mieu") == 1  # giữ Văn Miếu (bỏ điểm rẻ hơn)

# --- B05 (lượt 7): model TỰ cắt cho vừa ngân sách → vẫn phải nói đi đủ thì vượt bao nhiêu ---
TU_CAT = {"ngay": [["ho_guom", "hoa_lo", "bt_dan_toc_hoc"]],
          "bo": [{"id": "hoang_thanh", "ly_do": "Loại bỏ để đảm bảo tổng chi phí vé nằm trong ngân sách cho phép."},
                 {"id": "van_mieu", "ly_do": "Loại bỏ để đảm bảo tổng chi phí vé nằm trong ngân sách cho phép."}]}
replies[:] = [B05V, TU_CAT]
r = agent.answer("x")
assert r["itinerary"]["feasible"] and r["itinerary"]["per_person_vnd"] == 140000, r["output"]
assert "Đi đủ các điểm bạn nêu thì tiền vé 280,000đ/người, vượt ngân sách 150,000đ/người 130,000đ" in r["output"]
assert "trong ngân sách" not in r["output"] and "vì ngân sách vé" in r["output"]
# Không có điểm nào bị bỏ → không ghi thêm
replies[:] = [dict(B05V, diem_muon_di=["Hồ Gươm", "Hỏa Lò"]), {"ngay": [["ho_guom", "hoa_lo"]]}]
assert "Đi đủ các điểm" not in agent.answer("x")["output"]

# --- B07 (lượt 7): nhóm có trẻ em mà model đưa tre_em vào "tranh" → chuyển sang sở thích, vẫn có lịch ---
replies[:] = [{"trang_thai": "ok", "so_ngay": 2, "nguoi_lon": 2, "tuoi_tre_em": [6, 8], "so_thich": [], "tranh": ["tre_em"]},
              {"ngay": [["bt_dan_toc_hoc"], ["bat_trang"]]}]
r = agent.answer("Đi Hà Nội 2 ngày với 2 bé 6 và 8 tuổi, bé đi bộ nhiều sẽ mệt")
assert r["itinerary"] and [s["id"] for d in r["itinerary"]["days"] for s in d["stops"]] == ["bt_dan_toc_hoc", "bat_trang"]
# Không có trẻ em thì "tranh" giữ nguyên
replies[:] = [{"trang_thai": "ok", "so_ngay": 1, "nguoi_lon": 2, "so_thich": ["van_hoa"], "tranh": ["tre_em"]},
              {"ngay": [["van_mieu", "ho_guom"]]}]
assert "Dân tộc học" not in agent.answer("x")["output"]

# --- RAG (tra_cuu_rag) ---
from tools import tra_cuu_rag  # noqa: E402
from tracing import TOOLS  # noqa: E402

assert {"tim_diem", "thoi_gian_di", "kiem_lich_trinh", "tim_noi_o", "toi_uu_lo_trinh",
        "thoi_tiet", "tra_cuu_rag"}.issubset(TOOLS.keys())
assert "tim_kiem_thong_tin" not in TOOLS

# Kiểm tra dữ liệu POI mở rộng & RAG cục bộ không chứa từ cấm và không chứa giờ/giá
assert len(tools.POI) == 24
assert all(tools.POI[pid] for pid in ("nha_tho_lon", "bt_phu_nu", "bt_lich_su", "bt_ho_chi_minh",
                                       "bt_quan_su", "phu_chu_tich", "den_quan_thanh", "den_bach_ma",
                                       "chua_quan_su", "thu_le"))
assert "Bảo tàng Mỹ thuật Việt Nam" in tim_diem([], [], ["Bảo tàng Mỹ thuật Việt Nam"])["khong_tim_thay"]  # giữ B08
assert all("ngoai_thanh" in p["so_thich"] for p in tools.POI.values() if "trai_nghiem" in p["so_thich"])  # giữ B23
assert ids_of("Nhà thờ Lớn Hà Nội") == ["nha_tho_lon"] and ids_of("Công viên Thủ Lệ") == ["thu_le"]
assert ids_of("Bảo tàng Phụ nữ") == ["bt_phu_nu"]

import re  # noqa: E402
_rag_doan = tools.RAG_DATA["doan"]
_rag_ids = {d.get("dia_diem_id") for d in _rag_doan if d.get("dia_diem_id")}
assert len(_rag_doan) >= 75 and set(tools.POI).issubset(_rag_ids)
_rag_nguon = {d["nguon"] for d in _rag_doan}
assert {"cam_nang_ha_noi_v1", "Wikipedia tiếng Việt (CC BY-SA 4.0)", "VnExpress", "VietnamPlus"}.issubset(_rag_nguon)
_rag_keys = set()
_gio_gia_re = re.compile(r"(?:\b\d{1,2}\s*(?:h|giờ|:)\s*\d{0,2}\b|\b\d[\d.,]*\s*(?:đồng|đ\b|vnd|nghìn)\b|\b\d+\s*(?:phút|tiếng)\b)", re.I)
for _d in _rag_doan:
    assert isinstance(_d["thu_tu"], int) and _d["thu_tu"] > 0
    _k = (_d["nguon"], _d["thu_tu"])
    assert _k not in _rag_keys, _k
    _rag_keys.add(_k)
    _txt = (_d["tieu_de"] + " " + _d["noi_dung"]).lower()
    assert not _gio_gia_re.search(_txt), (_d["tieu_de"], _d["noi_dung"])
    for _cam in ("đông", "buổi chiều", "trong ngân sách", "ngày đầu tiên", "đi lại ít nhất", "google.com", "vắng"):
        assert _cam not in _txt, (_d["tieu_de"], _cam)

# 1. Local BM25: lọc đúng dia_diem_ids, không lọt điểm ngoài
r_rag = tra_cuu_rag("x", ["lang_bac", "van_mieu"], gioi_han=3)
assert r_rag["nguon_truy_xuat"] == "local_bm25" and r_rag["so_ket_qua"] == 3
assert {x["dia_diem_id"] for x in r_rag["doan"]}.issubset({"lang_bac", "van_mieu"})
assert any(x["dia_diem_id"] == "van_mieu" for x in tra_cuu_rag("bia tiến sĩ văn miếu", ["lang_bac", "van_mieu"], gioi_han=3)["doan"])

r_rag_q = tra_cuu_rag("trang phục vào lăng bác", gioi_han=3)
assert r_rag_q["nguon_truy_xuat"] == "local_bm25" and r_rag_q["so_ket_qua"] >= 1
assert any(x["dia_diem_id"] == "lang_bac" for x in r_rag_q["doan"])

# 2. Chế độ pgvector (mock _nhung_van_ban & _truy_van_pgvector) + fallback khi rỗng
_old_env = {k: os.environ.get(k) for k in ("DATABASE_URL", "API_KEY", "MODEL_PROVIDER")}
_old_embed, _old_pg = tools._nhung_van_ban, tools._truy_van_pgvector
try:
    os.environ["DATABASE_URL"] = "postgresql://u:p@localhost:5432/db"
    os.environ["API_KEY"] = "test-key"
    os.environ["MODEL_PROVIDER"] = "gemini"
    tools._nhung_van_ban = lambda text: [0.1] * 768
    tools._truy_van_pgvector = lambda vec, model, k, ids=None: [
        {"tieu_de": "PG Văn Miếu", "noi_dung": "Mẹo từ pgvector.", "nguon": "pg_db", "dia_diem_id": "van_mieu", "diem_khop": 0.92}
    ]
    r_pg = tra_cuu_rag("văn miếu", ["van_mieu"], gioi_han=2)
    assert r_pg["nguon_truy_xuat"] == "pgvector" and r_pg["doan"][0]["tieu_de"] == "PG Văn Miếu"

    # Fallback sang local_bm25 khi pgvector trả rỗng
    tools._truy_van_pgvector = lambda vec, model, k, ids=None: []
    r_fb = tra_cuu_rag("văn miếu", ["van_mieu"], gioi_han=2)
    assert r_fb["nguon_truy_xuat"] == "local_bm25" and r_fb["doan"][0]["dia_diem_id"] == "van_mieu"
finally:
    tools._nhung_van_ban, tools._truy_van_pgvector = _old_embed, _old_pg
    for _k, _v in _old_env.items():
        if _v is None:
            os.environ.pop(_k, None)
        else:
            os.environ[_k] = _v

# 3. Tích hợp agent.answer: điểm ngoài danh mục giữ cảnh báo thiếu dữ liệu + bổ sung mẹo RAG
replies[:] = [{"trang_thai": "ok", "so_ngay": 1, "nguoi_lon": 2,
               "diem_muon_di": ["Văn Miếu", "Bảo tàng Mỹ thuật Việt Nam"]},
              {"ngay": [["van_mieu"]], "ly_do": {"van_mieu": "Bạn muốn đi điểm này."}}]
r = agent.answer("Đi Hà Nội 1 ngày Văn Miếu và Bảo tàng Mỹ thuật Việt Nam")
assert r["itinerary"]["feasible"]
assert 'Không có dữ liệu về "Bảo tàng Mỹ thuật Việt Nam" nên không xếp giờ / giá cho điểm này.' in r["output"]
assert "Mẹo tham quan (" in r["output"]
assert r["itinerary"]["rag_references"] and "search_references" not in r["itinerary"]

print("OK: test_core")
