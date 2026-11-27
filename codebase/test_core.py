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
print("OK: test_core")
