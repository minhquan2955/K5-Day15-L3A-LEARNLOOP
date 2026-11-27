"""Công cụ của bài toán — thiết kế ở spec.md §4. Ba công cụ chính chỉ đọc data/hanoi_poi.json; thoi_tiet chỉ đọc
API Open-Meteo (khi biết ngày đi). Không công cụ nào tác động ra ngoài.

Mọi con số người dùng thấy (giờ, phút đi, tiền) đến từ đây, không từ model.
"""
import datetime
import json
import math
import os
import unicodedata
import urllib.parse
import urllib.request

from tracing import tool, TOOLS  # noqa: F401

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(ROOT, "data", "hanoi_poi.json"), encoding="utf-8") as _f:
    DATA = json.load(_f)
POI = {p["id"]: p for p in DATA["diem"]}
HOTEL = DATA["khach_san"]
TAGS = sorted({t for p in DATA["diem"] for t in p["so_thich"]})
GIO_MUON_NHAT = 22 * 60  # spec §4: lịch không quá 22:00


def _fold(s):
    s = unicodedata.normalize("NFD", s.lower()).replace("đ", "d")
    return "".join(c for c in s if unicodedata.category(c) != "Mn").strip()


def _phut(hhmm):
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def _gio(phut):
    return "%02d:%02d" % (phut // 60, phut % 60)


def _toa_do(pid):
    p = HOTEL if pid == HOTEL["id"] else POI[pid]
    return p["lat"], p["lon"]


def _km(a, b):
    (la1, lo1), (la2, lo2) = _toa_do(a), _toa_do(b)
    r = 6371.0
    dla, dlo = math.radians(la2 - la1), math.radians(lo2 - lo1)
    h = math.sin(dla / 2) ** 2 + math.cos(math.radians(la1)) * math.cos(math.radians(la2)) * math.sin(dlo / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h)) * DATA["he_so_duong"]


def _phut_di(a, b):
    """Công thức DATA_CARD: chim bay × hệ số đường ÷ tốc độ + phút cộng thêm."""
    if a == b:
        return 0
    return round(_km(a, b) / DATA["toc_do_kmh"] * 60) + DATA["phut_cong_them"]


def link_google_maps(diem_den: list, tu: str = None) -> str:
    """Link chỉ đường Google Maps (Maps URLs, không cần API key) qua các id theo thứ tự.
    tu = id điểm xuất phát; None = vị trí hiện tại của máy người dùng. Đi ô tô (khớp tiền taxi)."""
    q = [("api", "1")]
    if tu:
        q.append(("origin", "%s,%s" % _toa_do(tu)))
    q.append(("destination", "%s,%s" % _toa_do(diem_den[-1])))
    if len(diem_den) > 1:
        q.append(("waypoints", "|".join("%s,%s" % _toa_do(i) for i in diem_den[:-1])))
    q.append(("travelmode", "driving"))
    return "https://www.google.com/maps/dir/?" + urllib.parse.urlencode(q, quote_via=urllib.parse.quote, safe="")


def _tom_tat(p):
    return {k: p.get(k) for k in ("id", "ten", "mo", "dong", "phut_tham_quan", "gia_ve", "tre_em_mien_phi_duoi", "so_thich")}


@tool
def tim_diem(so_thich: list, tranh: list, ten_diem: list) -> dict:
    """tim_diem · Input: nhãn sở thích, nhãn cần tránh, tên điểm người dùng nêu ·
    Output: {"diem": điểm khớp, "khong_tim_thay": tên không có trong dữ liệu, "nhan_co_san": mọi nhãn} ·
    Không tác động ra ngoài."""
    tranh = set(tranh or [])
    chon, khong_thay = {}, []
    for ten in ten_diem or []:
        f = _fold(ten)
        hit = next((p for p in DATA["diem"]
                    if any(_fold(x) in f or f in _fold(x) for x in p["ten_khac"] + [p["ten"]])), None)
        if hit:
            chon[hit["id"]] = dict(_tom_tat(hit), nguoi_dung_neu=True)
        else:
            khong_thay.append(ten)
    for p in DATA["diem"]:
        if p["id"] in chon or tranh & set(p["so_thich"]):
            continue
        if set(so_thich or []) & set(p["so_thich"]):
            chon[p["id"]] = dict(_tom_tat(p), nguoi_dung_neu=False)
    return {"diem": list(chon.values()), "khong_tim_thay": khong_thay, "nhan_co_san": TAGS}


@tool
def thoi_gian_di(ids: list) -> dict:
    """thoi_gian_di · Input: danh sách id điểm (tự thêm khách sạn) ·
    Output: {"a>b": số phút đi} cho mọi cặp · Không tác động ra ngoài."""
    ids = [HOTEL["id"]] + [i for i in ids if i in POI]
    return {"%s>%s" % (a, b): _phut_di(a, b) for a in ids for b in ids if a != b}


@tool
def kiem_lich_trinh(ngay: list, gio_bat_dau: str, nguoi_lon: int, tuoi_tre_em: list,
                    ngan_sach_moi_nguoi: int = 0) -> dict:
    """kiem_lich_trinh · Input: mỗi ngày một dãy id (xuất phát và về khách sạn), giờ bắt đầu ngày 1
    (các ngày sau 07:30), số người lớn, tuổi từng trẻ em (null = chưa biết, tính như người lớn),
    ngân sách vé mỗi người (0 = không có) · Output: giờ đến từng điểm, vi phạm, tiền vé, tiền xe ·
    Không tác động ra ngoài."""
    so_nguoi = nguoi_lon + len(tuoi_tre_em)
    so_xe = max(1, math.ceil(so_nguoi / DATA["khach_moi_xe"]))
    vi_pham, out_ngay, tong_ve, tong_xe = [], [], 0, 0
    for i, ids in enumerate(ngay):
        t = _phut(gio_bat_dau) if i == 0 else _phut("07:30")
        truoc, stops = HOTEL["id"], []
        for pid in ids:
            if pid not in POI:
                vi_pham.append("Ngày %d: '%s' không có trong dữ liệu" % (i + 1, pid))
                continue
            p = POI[pid]
            di = _phut_di(truoc, pid)
            tong_xe += round(_km(truoc, pid) * DATA["gia_xe_moi_km"]) * so_xe
            den = max(t + di, _phut(p["mo"]))
            xong = den + p["phut_tham_quan"]
            if xong > _phut(p["dong"]):
                vi_pham.append("Ngày %d: %s đóng cửa %s, đến %s + tham quan %d phút thì không kịp"
                               % (i + 1, p["ten"], p["dong"], _gio(den), p["phut_tham_quan"]))
            mien = p.get("tre_em_mien_phi_duoi")
            tra_ve = nguoi_lon + sum(1 for a in tuoi_tre_em if a is None or not mien or a >= mien)
            ve = p["gia_ve"] * tra_ve
            tong_ve += ve
            stops.append({"id": pid, "name": p["ten"], "arrive": _gio(den), "visit_min": p["phut_tham_quan"],
                          "travel_min_from_prev": di, "ticket_vnd": ve, "mo": p["mo"], "dong": p["dong"]})
            t, truoc = xong, pid
        ve_ks = t + _phut_di(truoc, HOTEL["id"])
        tong_xe += round(_km(truoc, HOTEL["id"]) * DATA["gia_xe_moi_km"]) * so_xe if ids else 0
        if t > GIO_MUON_NHAT:
            vi_pham.append("Ngày %d: kết thúc %s, quá 22:00" % (i + 1, _gio(t)))
        out_ngay.append({"day": i + 1, "stops": stops, "ket_thuc": _gio(t), "ve_khach_san": _gio(ve_ks)})
    ve_moi_nguoi = round(tong_ve / so_nguoi) if so_nguoi else 0
    if ngan_sach_moi_nguoi and ve_moi_nguoi > ngan_sach_moi_nguoi:
        vi_pham.append("Tiền vé %dđ/người, vượt ngân sách %dđ/người %dđ"
                       % (ve_moi_nguoi, ngan_sach_moi_nguoi, ve_moi_nguoi - ngan_sach_moi_nguoi))
    return {"days": out_ngay, "vi_pham": vi_pham, "total_vnd": tong_ve, "per_person_vnd": ve_moi_nguoi,
            "xe_vnd": round(tong_xe, -3), "so_nguoi": so_nguoi}  # taxi là ước tính: làm tròn nghìn


# ---------- Thời tiết (Open-Meteo, miễn phí phi thương mại, không cần key, dữ liệu CC BY 4.0) ----------
GIO_VN = datetime.timezone(datetime.timedelta(hours=7))
DU_BAO_SO_NGAY = 16  # Open-Meteo dự báo tối đa 16 ngày
MUA_NHIEU = 60       # % khả năng mưa từ mức này coi là ngày mưa
_URL_DU_BAO = ("https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&timezone=auto"
               "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum"
               "&start_date=%s&end_date=%s")
_THOI_TIET = {0: "Trời quang", 1: "Ít mây", 2: "Mây rải rác", 3: "Nhiều mây", 45: "Sương mù", 48: "Sương mù",
              51: "Mưa phùn nhẹ", 53: "Mưa phùn", 55: "Mưa phùn dày", 56: "Mưa phùn lạnh", 57: "Mưa phùn lạnh",
              61: "Mưa nhẹ", 63: "Mưa vừa", 65: "Mưa to", 66: "Mưa lạnh", 67: "Mưa lạnh to",
              71: "Tuyết", 73: "Tuyết", 75: "Tuyết", 77: "Tuyết", 80: "Mưa rào nhẹ", 81: "Mưa rào", 82: "Mưa rào rất to",
              85: "Mưa tuyết", 86: "Mưa tuyết", 95: "Dông", 96: "Dông kèm mưa đá", 97: "Dông mạnh", 99: "Dông kèm mưa đá"}


def hom_nay():
    return datetime.datetime.now(GIO_VN).date()


def _tai_du_bao(url):
    """Gọi Open-Meteo. Tách riêng để test thay bằng dữ liệu giả, không gọi mạng."""
    req = urllib.request.Request(url, headers={"User-Agent": "hanoi-itinerary-weather/1.0 (python-urllib)"})
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read().decode("utf-8"))


@tool
def thoi_tiet(ngay_bat_dau: str, so_ngay: int) -> dict:
    """thoi_tiet · Input: ngày bắt đầu "YYYY-MM-DD", số ngày · Output: {"ngay": [{ngay, mo_ta, nhiet_do_thap,
    nhiet_do_cao, kha_nang_mua, luong_mua_mm}], "nguon"} — chỉ các ngày nằm trong 16 ngày tới — hoặc {"loi": lý do} ·
    Chỉ đọc API Open-Meteo cho toạ độ trung tâm Hà Nội; không gửi dữ liệu người dùng · Không tác động ra ngoài."""
    try:
        d0 = datetime.date.fromisoformat(ngay_bat_dau)
    except (TypeError, ValueError):
        return {"loi": "ngày đi không hợp lệ"}
    nay = hom_nay()
    cuoi_du_bao = nay + datetime.timedelta(days=DU_BAO_SO_NGAY - 1)
    d1 = d0 + datetime.timedelta(days=max(1, so_ngay) - 1)
    if d1 < nay:
        return {"loi": "ngày đi đã qua"}
    if d0 > cuoi_du_bao:
        return {"loi": "dự báo chỉ có đến %s (16 ngày tới)" % cuoi_du_bao.strftime("%d/%m")}
    try:
        data = _tai_du_bao(_URL_DU_BAO % (HOTEL["lat"], HOTEL["lon"], max(d0, nay).isoformat(),
                                          min(d1, cuoi_du_bao).isoformat()))
        daily = data["daily"]
        out = []
        for i, ngay in enumerate(daily["time"]):
            ma, mua, ml = (daily["weather_code"][i], daily["precipitation_probability_max"][i],
                           daily["precipitation_sum"][i])
            out.append({"ngay": ngay, "mo_ta": _THOI_TIET.get(int(ma), "Không rõ") if ma is not None else "Không rõ",
                        "nhiet_do_thap": round(daily["temperature_2m_min"][i]),
                        "nhiet_do_cao": round(daily["temperature_2m_max"][i]),
                        "kha_nang_mua": None if mua is None else round(mua),
                        "luong_mua_mm": None if ml is None else round(ml, 1)})
    except (OSError, ValueError, KeyError, TypeError, IndexError) as e:  # mất mạng, HTTP lỗi, JSON lạ → không chặn lịch
        return {"loi": "chưa lấy được dự báo (%s)" % type(e).__name__}
    return {"ngay": out, "nguon": "Open-Meteo.com (CC BY 4.0)"}
