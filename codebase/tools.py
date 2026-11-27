"""Công cụ của bài toán — nhóm LEARNLOOP (Track C).

Mỗi công cụ là một hàm Python có @tool, đọc dữ liệu từ data/hanoi_poi.json,
không tác động ra ngoài (chỉ đọc và tính toán).
"""
import json
import math
import os
import unicodedata

from tracing import tool, TOOLS  # noqa: F401

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_PATH = os.path.join(ROOT, "data", "hanoi_poi.json")


def _load_data() -> dict:
    with open(DATA_PATH, encoding="utf-8") as f:
        return json.load(f)


def _norm(text: str) -> str:
    """Chuẩn hoá tiếng Việt không dấu, chữ thường để đối chiếu tên/nhãn."""
    s = (text or "").replace("đ", "d").replace("Đ", "D")
    s = unicodedata.normalize("NFD", s)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    return " ".join(s.lower().strip().split())


def _find_place(data: dict, place_id: str) -> dict | None:
    if place_id == data["khach_san"]["id"]:
        return data["khach_san"]
    for item in data["diem"]:
        if item["id"] == place_id:
            return item
    return None


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


def _calc_travel(data: dict, id_a: str, id_b: str) -> tuple[float, int] | None:
    a = _find_place(data, id_a)
    b = _find_place(data, id_b)
    if a is None or b is None:
        return None
    if id_a == id_b:
        return 0.0, 0
    straight_km = _haversine_km(a["lat"], a["lon"], b["lat"], b["lon"])
    road_km = straight_km * float(data.get("he_so_duong", 1.3))
    speed = float(data.get("toc_do_kmh", 20))
    extra_min = float(data.get("phut_cong_them", 5))
    minutes = max(1, round((road_km / speed) * 60.0 + extra_min))
    return round(road_km, 2), minutes


def _to_min(hhmm: str) -> int:
    hh, mm = hhmm.strip().split(":", 1)
    return int(hh) * 60 + int(mm)


def _from_min(total_min: int) -> str:
    return "%02d:%02d" % (total_min // 60, total_min % 60)


def _match_name(item: dict, query: str) -> bool:
    qn = _norm(query)
    if not qn:
        return False
    candidates = [item["id"], item["ten"]] + list(item.get("ten_khac", []))
    for cand in candidates:
        cn = _norm(cand)
        if qn == cn or qn in cn or cn in qn:
            return True
    return False


@tool
def tim_diem(so_thich: list = None, tranh: list = None, ten_diem: list = None) -> dict:
    """tim_diem · Lọc các điểm tham quan ở Hà Nội từ data/hanoi_poi.json.
    Input: so_thich (danh sách nhãn sở thích), tranh (nhãn cần tránh), ten_diem (tên điểm người dùng nêu).
    Output: dict {"diem": [...], "khong_tim_thay": [...], "tong_diem_du_lieu": int}.
    Không tác động ra ngoài (chỉ đọc dữ liệu)."""
    data = _load_data()
    liked = {_norm(x) for x in (so_thich or []) if str(x).strip()}
    avoided = {_norm(x) for x in (tranh or []) if str(x).strip()}
    requested_names = [str(x).strip() for x in (ten_diem or []) if str(x).strip()]

    matched = []
    seen_ids = set()
    not_found = []

    for name in requested_names:
        found_any = False
        for item in data["diem"]:
            if _match_name(item, name):
                found_any = True
                if item["id"] not in seen_ids:
                    matched.append(item)
                    seen_ids.add(item["id"])
        if not found_any:
            not_found.append(name)

    for item in data["diem"]:
        if item["id"] in seen_ids:
            continue
        tags = {_norm(t) for t in item.get("so_thich", [])}
        if tags & avoided:
            continue
        if not liked and not requested_names:
            matched.append(item)
            seen_ids.add(item["id"])
        elif liked and (tags & liked):
            matched.append(item)
            seen_ids.add(item["id"])

    return {
        "diem": matched,
        "khong_tim_thay": not_found,
        "tong_diem_du_lieu": len(data["diem"]),
    }


@tool
def thoi_gian_di(diem_a: str, diem_b: str) -> dict:
    """thoi_gian_di · Tính khoảng cách và thời gian di chuyển giữa hai điểm ở Hà Nội.
    Input: diem_a (id điểm xuất phát, gồm cả 'khach_san'), diem_b (id điểm đến).
    Output: dict {"diem_a": str, "diem_b": str, "km": float, "phut": int} (hoặc có khoá "loi" nếu id không tồn tại).
    Không tác động ra ngoài (chỉ đọc dữ liệu và tính toán)."""
    data = _load_data()
    res = _calc_travel(data, diem_a, diem_b)
    if res is None:
        return {"diem_a": diem_a, "diem_b": diem_b, "loi": "Không tìm thấy id điểm trong dữ liệu"}
    km, phut = res
    return {"diem_a": diem_a, "diem_b": diem_b, "km": km, "phut": phut}


@tool
def kiem_lich_trinh(
    lich_trinh: list,
    gio_bat_dau: str = "08:00",
    so_nguoi_lon: int = 1,
    tuoi_tre_em: list = None,
    ngan_sach_ve_moi_nguoi: int = None,
) -> dict:
    """kiem_lich_trinh · Kiểm tra tính khả thi, giờ mở/đóng cửa, mốc 22:00 và chi phí vé/xe cho lộ trình nhiều ngày.
    Input: lich_trinh (list[list[str]] id điểm mỗi ngày), gio_bat_dau ('HH:MM'), so_nguoi_lon (int),
           tuoi_tre_em (list[int] tuỳ chọn), ngan_sach_ve_moi_nguoi (int tuỳ chọn, VND).
    Output: dict gồm hop_le (bool), vi_pham (list[str]), chi_tiet_ngay (list), tong_tien_ve, tien_xe_uoc_tinh,
            tong_chi_phi, tien_ve_moi_nguoi, tong_moi_nguoi.
    Không tác động ra ngoài (chỉ tính toán và kiểm tra)."""
    data = _load_data()
    if isinstance(tuoi_tre_em, int):
        child_ages = [tuoi_tre_em]
    else:
        child_ages = [int(a) for a in (tuoi_tre_em or [])]

    total_people = max(1, int(so_nguoi_lon) + len(child_ages))
    start_min_default = _to_min(gio_bat_dau)
    max_end_min = 22 * 60

    violations = []
    day_details = []
    total_ticket = 0
    total_km = 0.0

    for day_idx, day_ids in enumerate(lich_trinh or [], start=1):
        cur_min = start_min_default
        prev_id = data["khach_san"]["id"]
        stops = []

        for poi_id in day_ids:
            poi = _find_place(data, poi_id)
            if poi is None or poi_id == data["khach_san"]["id"]:
                violations.append("Ngày %d: điểm '%s' không có trong dữ liệu" % (day_idx, poi_id))
                continue

            travel = _calc_travel(data, prev_id, poi_id)
            km, phut = travel if travel is not None else (0.0, 0)
            arrive_min = cur_min + phut
            open_min = _to_min(poi["mo"])
            close_min = _to_min(poi["dong"])

            if arrive_min >= close_min:
                violations.append(
                    "Ngày %d: đến %s lúc %s, đã đóng cửa (giờ mở %s–%s)"
                    % (day_idx, poi["ten"], _from_min(arrive_min), poi["mo"], poi["dong"])
                )
                start_visit = arrive_min
            else:
                start_visit = max(arrive_min, open_min)

            leave_min = start_visit + int(poi["phut_tham_quan"])
            if arrive_min < close_min and leave_min > close_min:
                violations.append(
                    "Ngày %d: rời %s lúc %s, quá giờ đóng cửa (%s)"
                    % (day_idx, poi["ten"], _from_min(leave_min), poi["dong"])
                )
            if leave_min > max_end_min:
                violations.append(
                    "Ngày %d: kết thúc %s lúc %s, quá 22:00"
                    % (day_idx, poi["ten"], _from_min(leave_min))
                )

            free_under = poi.get("tre_em_mien_phi_duoi")
            adult_cost = int(so_nguoi_lon) * int(poi["gia_ve"])
            child_cost = sum(
                0 if (free_under is not None and age < int(free_under)) else int(poi["gia_ve"])
                for age in child_ages
            )
            ticket_cost = adult_cost + child_cost

            total_ticket += ticket_cost
            total_km += km
            stops.append({
                "id": poi["id"],
                "ten": poi["ten"],
                "tu": prev_id,
                "km_di": km,
                "phut_di": phut,
                "gio_den": _from_min(arrive_min),
                "gio_roi": _from_min(leave_min),
                "mo": poi["mo"],
                "dong": poi["dong"],
                "tien_ve_nhom": ticket_cost,
            })
            cur_min = leave_min
            prev_id = poi["id"]

        day_details.append({"ngay": day_idx, "diem": stops})

    cars = math.ceil(total_people / int(data.get("khach_moi_xe", 4)))
    taxi_cost = round(total_km * float(data.get("gia_xe_moi_km", 15000)) * cars)
    total_cost = total_ticket + taxi_cost
    ticket_per_person = round(total_ticket / total_people)
    total_per_person = round(total_cost / total_people)

    if ngan_sach_ve_moi_nguoi is not None and ticket_per_person > int(ngan_sach_ve_moi_nguoi):
        diff = ticket_per_person - int(ngan_sach_ve_moi_nguoi)
        violations.append(
            "Vượt ngân sách vé: %dđ/người > %dđ/người (vượt %dđ/người)"
            % (ticket_per_person, int(ngan_sach_ve_moi_nguoi), diff)
        )

    return {
        "hop_le": len(violations) == 0,
        "vi_pham": violations,
        "chi_tiet_ngay": day_details,
        "tong_km": round(total_km, 2),
        "tong_tien_ve": total_ticket,
        "tien_xe_uoc_tinh": taxi_cost,
        "tong_chi_phi": total_cost,
        "tien_ve_moi_nguoi": ticket_per_person,
        "tong_moi_nguoi": total_per_person,
    }
