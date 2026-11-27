"""Luồng chính của bản chạy thử — nhóm LEARNLOOP (Track C).

Hình dạng theo spec.md §4: workflow cố định 5 bước:
  1. Đọc yêu cầu + tra danh sách điểm khả dụng qua tim_diem
  2. Tính trước thời gian di chuyển từ khách sạn và các cặp điểm qua thoi_gian_di
  3. Gọi model (call_model) đề xuất lộ trình hoặc hỏi lại / từ chối ngoài phạm vi
  4. Kiểm tra lộ trình qua kiem_lich_trinh (tối đa MAX_RETRIES = 2 lượt sửa)
  5. Trả kết quả cuối kèm cảnh báo phạm vi dữ liệu mẫu (G1/G2)
"""
import json

from ai import call_model
from tools import kiem_lich_trinh, thoi_gian_di, tim_diem
from tracing import note

MAX_RETRIES = 2

SYSTEM = """Bạn là trợ lý lên lộ trình tham quan Hà Nội 2–3 ngày cho người lần đầu đến.
Nguyên tắc bắt buộc:
- Chỉ dùng 14 điểm tham quan ở Hà Nội do công cụ cung cấp. Không tự bịa điểm mới, quán ăn, độ đông, giờ mở cửa hoặc giá vé.
- Nếu người dùng thiếu số ngày (hoặc hỏi quá chung): hỏi lại số ngày, số người, sở thích; KHÔNG đưa lộ trình.
- Nếu người dùng hỏi thành phố khác Hà Nội, đòi đặt vé / chuyển tiền, gửi số thẻ hoặc yêu cầu sửa giờ mở cửa trái dữ liệu: từ chối phần ngoài phạm vi, KHÔNG lặp lại số thẻ, giữ nguyên dữ liệu gốc.
- Nếu đủ thông tin để xếp lộ trình, trả lời dạng JSON với khoá:
  {"trang_thai": "xep_duoc"|"hoi_lai"|"tu_choi"|"khong_xep_duoc",
   "lich_trinh": [["id_1", "id_2"], ...],
   "gio_bat_dau": "08:00",
   "so_nguoi_lon": 1,
   "tuoi_tre_em": [],
   "ngan_sach_ve_moi_nguoi": null,
   "ly_do": {"id_1": "1 câu lý do chọn"},
   "thong_bao": "tóm tắt hoặc câu hỏi lại / từ chối"}"""

DISCLAIMER = "Lưu ý: hệ thống chỉ có 14 điểm ở Hà Nội; giờ mở cửa, thời gian đi và giá vé là dữ liệu mẫu, hãy kiểm tra lại trước khi đi."


def _extract_json(text: str):
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return None
    try:
        return json.loads(text[start : end + 1])
    except ValueError:
        return None


def _format_schedule(check_res: dict, reasons: dict, summary: str) -> str:
    lines = [DISCLAIMER]
    if summary:
        lines.append(summary)
    for day in check_res.get("chi_tiet_ngay", []):
        lines.append("\nNgày %d:" % day["ngay"])
        for stop in day["diem"]:
            reason = reasons.get(stop["id"], "")
            lines.append(
                "- %s (%s–%s, mở %s–%s) | đi %d phút (%.2f km) | vé nhóm: %dđ%s"
                % (
                    stop["ten"],
                    stop["gio_den"],
                    stop["gio_roi"],
                    stop["mo"],
                    stop["dong"],
                    stop["phut_di"],
                    stop["km_di"],
                    stop["tien_ve_nhom"],
                    (" | Lý do: " + reason) if reason else "",
                )
            )
    lines.append(
        "\nTổng tiền vé: %dđ (%dđ/người) · Tiền xe ước tính: %dđ · Tổng chi phí: %dđ (%dđ/người)"
        % (
            check_res["tong_tien_ve"],
            check_res["tien_ve_moi_nguoi"],
            check_res["tien_xe_uoc_tinh"],
            check_res["tong_chi_phi"],
            check_res["tong_moi_nguoi"],
        )
    )
    return "\n".join(lines)


def answer(text: str) -> dict:
    # Bước 1 & 2: lấy toàn bộ điểm trong dữ liệu và thời gian đi từ khách sạn
    catalog = tim_diem()
    pois = catalog["diem"]
    valid_ids = {p["id"] for p in pois}

    from_hotel = [thoi_gian_di("khach_san", p["id"]) for p in pois]
    poi_summary = "\n".join(
        "- %s (%s): mở %s–%s, tham quan %d', vé %dđ, nhãn %s, từ khách sạn %d' (%.2f km)"
        % (
            p["id"],
            p["ten"],
            p["mo"],
            p["dong"],
            p["phut_tham_quan"],
            p["gia_ve"],
            ",".join(p.get("so_thich", [])),
            t["phut"],
            t["km"],
        )
        for p, t in zip(pois, from_hotel)
    )

    # Bước 3: gọi model lần đầu
    prompt = "Danh sách 14 điểm Hà Nội:\n%s\n\nYêu cầu của người dùng:\n%s" % (poi_summary, text)
    reply = call_model(SYSTEM, prompt)

    # Chế độ giả CP2: gọi kiem_lich_trinh trên lộ trình mẫu nội bộ để kiểm thông suốt 3 công cụ qua trace
    if reply.get("model") == "fake":
        note("chế độ giả CP2: kiểm khung 3 công cụ bằng lộ trình mẫu nội bộ")
        sample_check = kiem_lich_trinh([["lang_bac", "van_mieu"]])
        return {
            "output": "%s\n%s\n(khung CP2 đã kiểm %d điểm, hợp lệ mẫu: %s)"
            % (DISCLAIMER, reply["text"], catalog["tong_diem_du_lieu"], sample_check["hop_le"])
        }

    # Bước 4 & 5: parse JSON + vòng kiểm tra kiem_lich_trinh tối đa MAX_RETRIES lượt
    parsed = _extract_json(reply["text"])
    if not parsed:
        return {"output": DISCLAIMER + "\n" + reply["text"]}

    status = parsed.get("trang_thai", "")
    if status in ("hoi_lai", "tu_choi") or not parsed.get("lich_trinh"):
        return {"output": DISCLAIMER + "\n" + (parsed.get("thong_bao") or reply["text"])}

    last_check = None
    for attempt in range(MAX_RETRIES + 1):
        raw_plan = parsed.get("lich_trinh") or []
        clean_plan = [[pid for pid in day if pid in valid_ids] for day in raw_plan if isinstance(day, list)]
        last_check = kiem_lich_trinh(
            clean_plan,
            gio_bat_dau=parsed.get("gio_bat_dau") or "08:00",
            so_nguoi_lon=int(parsed.get("so_nguoi_lon") or 1),
            tuoi_tre_em=parsed.get("tuoi_tre_em") or [],
            ngan_sach_ve_moi_nguoi=parsed.get("ngan_sach_ve_moi_nguoi"),
        )
        if last_check["hop_le"]:
            return {
                "output": _format_schedule(
                    last_check, parsed.get("ly_do") or {}, parsed.get("thong_bao") or ""
                )
            }
        if attempt >= MAX_RETRIES:
            break
        note("vòng sửa %d: vi phạm %s" % (attempt + 1, "; ".join(last_check["vi_pham"])))
        fix_prompt = (
            "%s\n\nLộ trình trước bị vi phạm:\n%s\nHãy sửa lại JSON lộ trình để hết vi phạm, "
            "hoặc đặt trang_thai='khong_xep_duoc' và nêu cách nới cụ thể."
            % (prompt, "\n".join("- " + v for v in last_check["vi_pham"]))
        )
        reply = call_model(SYSTEM, fix_prompt)
        parsed = _extract_json(reply["text"]) or parsed

    violations_txt = "\n".join("- " + v for v in (last_check["vi_pham"] if last_check else []))
    return {
        "output": "%s\nKhông xếp được lộ trình thoả hết ràng buộc:\n%s\n%s"
        % (DISCLAIMER, violations_txt, parsed.get("thong_bao") or "")
    }
