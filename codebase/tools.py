"""Công cụ của bài toán — thiết kế ở spec.md §4. Ba công cụ chính chỉ đọc data/hanoi_poi.json; thoi_tiet chỉ đọc
API Open-Meteo (khi biết ngày đi); tim_noi_o chỉ đọc Nominatim (OpenStreetMap) khi người dùng nêu chỗ ở;
toi_uu_lo_trinh chỉ tính. Không công cụ nào tác động ra ngoài.

Điểm xuất phát mỗi ngày: id "khach_san". Mặc định là khách sạn dựng ở phố cổ (data); người dùng nêu chỗ ở thì truyền
xp = {"ten", "lat", "lon"} cho thoi_gian_di / kiem_lich_trinh / toi_uu_lo_trinh.

Mọi con số người dùng thấy (giờ, phút đi, tiền) đến từ đây, không từ model.
"""
import datetime
import json
import math
import os
import re
import unicodedata
import urllib.parse
import urllib.request

from tracing import tool, TOOLS  # noqa: F401

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(ROOT, "data", "hanoi_poi.json"), encoding="utf-8") as _f:
    DATA = json.load(_f)
try:
    with open(os.path.join(ROOT, "data", "hanoi_rag.json"), encoding="utf-8") as _rf:
        RAG_DATA = json.load(_rf)
except OSError:
    RAG_DATA = {"doan": []}
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


def _toa_do(pid, xp=None):
    p = (xp or HOTEL) if pid == HOTEL["id"] else POI[pid]
    return p["lat"], p["lon"]


def _km(a, b, xp=None):
    (la1, lo1), (la2, lo2) = _toa_do(a, xp), _toa_do(b, xp)
    r = 6371.0
    dla, dlo = math.radians(la2 - la1), math.radians(lo2 - lo1)
    h = math.sin(dla / 2) ** 2 + math.cos(math.radians(la1)) * math.cos(math.radians(la2)) * math.sin(dlo / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h)) * DATA["he_so_duong"]


def _phut_di(a, b, xp=None):
    """Công thức DATA_CARD: chim bay × hệ số đường ÷ tốc độ + phút cộng thêm."""
    if a == b:
        return 0
    return round(_km(a, b, xp) / DATA["toc_do_kmh"] * 60) + DATA["phut_cong_them"]


def link_google_maps(diem_den: list, tu: str = None, xp: dict = None) -> str:
    """Link chỉ đường Google Maps (Maps URLs, không cần API key) qua các id theo thứ tự.
    tu = id điểm xuất phát ("khach_san" = chỗ ở xp); None = vị trí hiện tại của máy người dùng. Đi ô tô (khớp tiền taxi)."""
    q = [("api", "1")]
    if tu:
        q.append(("origin", "%s,%s" % _toa_do(tu, xp)))
    q.append(("destination", "%s,%s" % _toa_do(diem_den[-1])))
    if len(diem_den) > 1:
        q.append(("waypoints", "|".join("%s,%s" % _toa_do(i) for i in diem_den[:-1])))
    q.append(("travelmode", "driving"))
    return "https://www.google.com/maps/dir/?" + urllib.parse.urlencode(q, quote_via=urllib.parse.quote, safe="")


def _khop_ten(ten):
    """Điểm khớp tên người dùng nêu nhất: trùng khít > tên dài nhất nằm trong chữ người dùng > tên ngắn nhất chứa chữ
    người dùng. Tránh "Phố đi bộ Hồ Gươm" khớp nhầm Hồ Gươm chỉ vì đứng trước trong dữ liệu. Không khớp → None."""
    f = _fold(ten or "")
    if not f:
        return None
    tot, diem_tot = None, None
    for p in DATA["diem"]:
        for x in (_fold(x) for x in p["ten_khac"] + [p["ten"]]):
            if x == f:
                diem = (3, len(x))
            elif x in f:
                diem = (2, len(x))
            elif f in x:
                diem = (1, -len(x))
            else:
                continue
            if diem_tot is None or diem > diem_tot:
                tot, diem_tot = p, diem
    return tot


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
        hit = _khop_ten(ten)
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
def thoi_gian_di(ids: list, xp: dict = None) -> dict:
    """thoi_gian_di · Input: danh sách id điểm (tự thêm điểm xuất phát "khach_san"), chỗ ở xp (None = mặc định) ·
    Output: {"a>b": số phút đi} cho mọi cặp · Không tác động ra ngoài."""
    ids = [HOTEL["id"]] + [i for i in ids if i in POI]
    return {"%s>%s" % (a, b): _phut_di(a, b, xp) for a in ids for b in ids if a != b}


@tool
def kiem_lich_trinh(ngay: list, gio_bat_dau, nguoi_lon: int, tuoi_tre_em: list,
                    ngan_sach_moi_nguoi: int = 0, xp: dict = None) -> dict:
    """kiem_lich_trinh · Input: mỗi ngày một dãy id (xuất phát và về chỗ ở), giờ bắt đầu ("HH:MM" cho ngày 1,
    các ngày sau 07:30 · hoặc danh sách từng ngày), số người lớn, tuổi từng trẻ em (null = chưa biết, tính như người
    lớn), ngân sách vé mỗi người (0 = không có), chỗ ở xp (None = mặc định) · Output: giờ đến từng điểm, vi phạm,
    tiền vé, tiền xe · Không tác động ra ngoài."""
    gio = [gio_bat_dau] if isinstance(gio_bat_dau, str) else list(gio_bat_dau or [])
    so_nguoi = nguoi_lon + len(tuoi_tre_em)
    so_xe = max(1, math.ceil(so_nguoi / DATA["khach_moi_xe"]))
    vi_pham, out_ngay, tong_ve, tong_xe = [], [], 0, 0
    for i, ids in enumerate(ngay):
        t = _phut(gio[i] if i < len(gio) and gio[i] else "07:30")
        truoc, stops = HOTEL["id"], []
        for pid in ids:
            if pid not in POI:
                vi_pham.append("Ngày %d: '%s' không có trong dữ liệu" % (i + 1, pid))
                continue
            p = POI[pid]
            di = _phut_di(truoc, pid, xp)
            tong_xe += round(_km(truoc, pid, xp) * DATA["gia_xe_moi_km"]) * so_xe
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
        ve_ks = t + _phut_di(truoc, HOTEL["id"], xp)
        tong_xe += round(_km(truoc, HOTEL["id"], xp) * DATA["gia_xe_moi_km"]) * so_xe if ids else 0
        if t > GIO_MUON_NHAT:
            vi_pham.append("Ngày %d: kết thúc %s, quá 22:00" % (i + 1, _gio(t)))
        out_ngay.append({"day": i + 1, "stops": stops, "ket_thuc": _gio(t), "ve_khach_san": _gio(ve_ks)})
    ve_moi_nguoi = round(tong_ve / so_nguoi) if so_nguoi else 0
    if ngan_sach_moi_nguoi and ve_moi_nguoi > ngan_sach_moi_nguoi:
        vi_pham.append("Tiền vé %dđ/người, vượt ngân sách %dđ/người %dđ"
                       % (ve_moi_nguoi, ngan_sach_moi_nguoi, ve_moi_nguoi - ngan_sach_moi_nguoi))
    return {"days": out_ngay, "vi_pham": vi_pham, "total_vnd": tong_ve, "per_person_vnd": ve_moi_nguoi,
            "xe_vnd": round(tong_xe, -3), "so_nguoi": so_nguoi}  # taxi là ước tính: làm tròn nghìn


# ---------- Chỗ ở người dùng (Nominatim / OpenStreetMap, dữ liệu ODbL) ----------
_HA_NOI = (20.55, 21.40, 105.30, 106.05)  # lat min, lat max, lon min, lon max — gồm cả Chùa Hương
_URL_DIA_CHI = "https://nominatim.openstreetmap.org/search?"


def _tra_dia_chi(q):
    """Gọi Nominatim (1 request, giới hạn khung Hà Nội). Tách riêng để test thay bằng dữ liệu giả."""
    url = _URL_DIA_CHI + urllib.parse.urlencode({
        "q": q, "format": "jsonv2", "limit": 1, "countrycodes": "vn", "bounded": 1,
        "viewbox": "%s,%s,%s,%s" % (_HA_NOI[2], _HA_NOI[1], _HA_NOI[3], _HA_NOI[0])})
    req = urllib.request.Request(url, headers={"User-Agent": "hanoi-itinerary-geocode/1.0 (python-urllib)",
                                               "Accept-Language": "vi"})
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read().decode("utf-8"))


@tool
def tim_noi_o(mo_ta: str) -> dict:
    """tim_noi_o · Input: chỗ ở người dùng nêu (tên khách sạn, địa chỉ, khu vực) · Output: {"ten", "lat", "lon",
    "nguon": "du_lieu" | "openstreetmap"} hoặc {"loi": lý do} · Khớp tên điểm trong dữ liệu trước ("gần Hồ Gươm");
    không có thì tra Nominatim trong khung Hà Nội, chỉ gửi chuỗi chỗ ở · Không tác động ra ngoài."""
    if not _fold(mo_ta or ""):
        return {"loi": "chưa có chỗ ở"}
    p = _khop_ten(mo_ta)
    if p and _fold(mo_ta) not in _fold(p["ten"]) and not any(_fold(x) in _fold(mo_ta) for x in p["ten_khac"] + [p["ten"]]):
        p = None  # chỗ ở chỉ khớp khi tên điểm nằm trong chữ người dùng ("gần Hồ Tây"), không theo chiều ngược lại
    if p:
        return {"ten": "gần " + p["ten"], "lat": p["lat"], "lon": p["lon"], "nguon": "du_lieu"}
    try:
        kq = _tra_dia_chi(mo_ta)
        if not kq:
            return {"loi": "không tìm thấy \"%s\" ở Hà Nội" % mo_ta}
        lat, lon = float(kq[0]["lat"]), float(kq[0]["lon"])
    except (OSError, ValueError, KeyError, TypeError, IndexError) as e:
        return {"loi": "chưa tra được địa chỉ (%s)" % type(e).__name__}
    if not (_HA_NOI[0] <= lat <= _HA_NOI[1] and _HA_NOI[2] <= lon <= _HA_NOI[3]):
        return {"loi": "địa chỉ tìm được nằm ngoài Hà Nội"}
    ten = ", ".join(x.strip() for x in str(kq[0].get("display_name", mo_ta)).split(",")[:2])
    return {"ten": ten, "lat": round(lat, 5), "lon": round(lon, 5), "nguon": "openstreetmap"}


# ---------- Tối ưu thời gian di chuyển (chế độ "đi lại ít nhất") ----------
TOI_DA_HOAN_VI = 8  # ngày quá số điểm này thì giữ thứ tự AI (8! = 40.320 thứ tự, có cắt nhánh)
TAI_NGAY_TOI_THIEU = 420  # phút tham quan tối đa / ngày khi chuyển điểm: max(420, ngày dày nhất AI đã chia)
_HUONG = ["phía Bắc", "phía Đông Bắc", "phía Đông", "phía Đông Nam", "phía Nam", "phía Tây Nam", "phía Tây", "phía Tây Bắc"]


def _thu_tu_tot_nhat(ids, bat_dau, xp=None, _nho=None):
    """Thử mọi thứ tự của một ngày (DFS, bỏ nhánh trễ giờ mở cửa hoặc đã dài hơn phương án tốt nhất).
    Trả (thứ tự, tổng phút đi kể cả về chỗ ở) — ít phút nhất, hoà thì xong sớm hơn; không thứ tự nào kịp → (None, None)."""
    khoa = (tuple(sorted(ids)), bat_dau)
    if _nho is not None and khoa in _nho:
        return _nho[khoa]
    h = HOTEL["id"]
    if len(ids) > TOI_DA_HOAN_VI:  # quá nhiều điểm: chỉ đánh giá thứ tự đang có
        thu, ket = [list(ids)], (None, None)
    else:
        thu, ket = None, (None, None)
    tot = [None, math.inf, math.inf]

    def dfs(con_lai, thu_tu, t, truoc, tong):
        if tong > tot[1]:
            return
        if not con_lai:
            ve = tong + (_phut_di(truoc, h, xp) if thu_tu else 0)
            if t <= GIO_MUON_NHAT and (ve, t) < (tot[1], tot[2]):
                tot[:] = [list(thu_tu), ve, t]
            return
        for pid in sorted(con_lai):
            p = POI[pid]
            di = _phut_di(truoc, pid, xp)
            xong = max(t + di, _phut(p["mo"])) + p["phut_tham_quan"]
            if xong > _phut(p["dong"]):
                continue
            thu_tu.append(pid)
            dfs(con_lai - {pid}, thu_tu, xong, pid, tong + di)
            thu_tu.pop()

    if thu is None:
        dfs(frozenset(ids), [], bat_dau, h, 0)
        ket = (tot[0], tot[1]) if tot[0] is not None else (None, None)
    else:  # chỉ kiểm thứ tự sẵn có
        t, truoc, tong, ok = bat_dau, h, 0, True
        for pid in ids:
            p = POI[pid]
            di = _phut_di(truoc, pid, xp)
            t = max(t + di, _phut(p["mo"])) + p["phut_tham_quan"]
            ok = ok and t <= _phut(p["dong"])
            tong, truoc = tong + di, pid
        if ok and t <= GIO_MUON_NHAT:
            ket = (list(ids), tong + _phut_di(truoc, h, xp))
    if _nho is not None:
        _nho[khoa] = ket
    return ket


def _phut_theo_thu_tu(ids, xp=None):
    """Tổng phút đi của một ngày theo đúng thứ tự (chỗ ở → ... → chỗ ở), không xét giờ mở cửa."""
    h, tong, truoc = HOTEL["id"], 0, HOTEL["id"]
    for pid in ids:
        tong, truoc = tong + _phut_di(truoc, pid, xp), pid
    return tong + (_phut_di(truoc, h, xp) if ids else 0)


def _huong_ngay(ids, xp=None):
    """Hướng của cụm điểm trong ngày so với chỗ ở (8 hướng); gần chỗ ở (< 1,5 km) → "quanh chỗ ở"."""
    if not ids:
        return ""
    la0, lo0 = _toa_do(HOTEL["id"], xp)
    la = sum(POI[i]["lat"] for i in ids) / len(ids)
    lo = sum(POI[i]["lon"] for i in ids) / len(ids)
    bac, dong = (la - la0) * 111.0, (lo - lo0) * 111.0 * math.cos(math.radians(la0))
    if math.hypot(bac, dong) < 1.5:
        return "quanh chỗ ở"
    goc = (math.degrees(math.atan2(dong, bac)) + 360) % 360  # 0 = Bắc, 90 = Đông
    return _HUONG[int((goc + 22.5) // 45) % 8]


@tool
def toi_uu_lo_trinh(ngay: list, gio_bat_dau, xp: dict = None) -> dict:
    """toi_uu_lo_trinh · Input: mỗi ngày một dãy id (AI đã chia), giờ bắt đầu (như kiem_lich_trinh), chỗ ở xp ·
    Output: {"ngay": dãy id mới, "phut_di_truoc", "phut_di_sau": tổng phút đi cả chuyến theo thứ tự cũ / mới,
    "huong": hướng từng ngày so với chỗ ở, "da_doi": có đổi không} · Thử mọi thứ tự trong ngày, rồi chuyển / đổi
    điểm giữa các ngày; chỉ nhận khi mọi ngày vẫn kịp giờ mở cửa, tổng phút đi giảm, không ngày nào trống và không
    ngày nào dày hơn max(420 phút tham quan, ngày dày nhất AI đã chia) — tránh dồn hết vào một ngày ·
    Chỉ tính, không tác động ra ngoài."""
    gio = [gio_bat_dau] if isinstance(gio_bat_dau, str) else list(gio_bat_dau or [])
    bd = [_phut(gio[i] if i < len(gio) and gio[i] else "07:30") for i in range(len(ngay))]
    ngay = [[i for i in d if i in POI] for d in ngay]
    truoc = sum(_phut_theo_thu_tu(d, xp) for d in ngay)
    nho = {}

    def tai(d):
        return sum(POI[i]["phut_tham_quan"] for i in d)

    tran = max([TAI_NGAY_TOI_THIEU] + [tai(d) for d in ngay])

    def chi_phi(ds):
        out, tong = [], 0
        for i, d in enumerate(ds):
            if tai(d) > tran:
                return None, None
            tt, c = _thu_tu_tot_nhat(d, bd[i], xp, nho)
            if tt is None:
                return None, None
            out.append(tt)
            tong += c
        return tong, out

    tot_c, tot = chi_phi(ngay)
    if tot is None:  # thứ tự nào cũng trễ giờ: giữ nguyên để kiem_lich_trinh báo vi phạm
        return {"ngay": ngay, "phut_di_truoc": truoc, "phut_di_sau": truoc, "huong": [_huong_ngay(d, xp) for d in ngay],
                "da_doi": False}
    for _ in range(30):  # tìm kiếm cục bộ giữa các ngày
        doi = False
        for i in range(len(tot)):
            for j in range(len(tot)):
                if i == j:
                    continue
                for pid in list(tot[i]):  # chuyển 1 điểm từ ngày i sang ngày j
                    if len(tot[i]) == 1:
                        break
                    thu = [list(d) for d in tot]
                    thu[i].remove(pid)
                    thu[j].append(pid)
                    c, o = chi_phi(thu)
                    if c is not None and c < tot_c:
                        tot_c, tot, doi = c, o, True
                        break
                if doi:
                    break
                for a in list(tot[i]) if i < j else []:  # đổi chỗ 2 điểm giữa ngày i và j
                    for b in list(tot[j]):
                        thu = [list(d) for d in tot]
                        thu[i][thu[i].index(a)], thu[j][thu[j].index(b)] = b, a
                        c, o = chi_phi(thu)
                        if c is not None and c < tot_c:
                            tot_c, tot, doi = c, o, True
                            break
                    if doi:
                        break
                if doi:
                    break
            if doi:
                break
        if not doi:
            break
    return {"ngay": tot, "phut_di_truoc": truoc, "phut_di_sau": tot_c, "huong": [_huong_ngay(d, xp) for d in tot],
            "da_doi": tot != ngay}


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


# ---------- RAG tri thức tham quan (pgvector khi có DB, mặc định fallback BM25 cục bộ) ----------
_EMBED_MODEL_DEFAULT = "gemini-embedding-001"
_EMBED_DIM = 768
_URL_EMBED = "https://generativelanguage.googleapis.com/v1beta/models/%s:embedContent"


def _nhung_van_ban(van_ban: str) -> list:
    """Nhúng văn bản 768 chiều qua Gemini Embedding API (urllib). Tách riêng để test thay bằng mock."""
    api_key = (os.environ.get("EMBEDDING_API_KEY") or os.environ.get("API_KEY") or "").strip()
    if not api_key:
        raise ValueError("thiếu API_KEY / EMBEDDING_API_KEY")
    model_name = (os.environ.get("EMBEDDING_MODEL") or _EMBED_MODEL_DEFAULT).strip()
    body = {
        "model": "models/" + model_name,
        "content": {"parts": [{"text": str(van_ban or "")}]},
        "outputDimensionality": _EMBED_DIM,
    }
    req = urllib.request.Request(
        _URL_EMBED % urllib.parse.quote(model_name, safe=""),
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
    )
    with urllib.request.urlopen(req, timeout=8) as r:
        data = json.loads(r.read().decode("utf-8"))
    values = (data.get("embedding") or {}).get("values") or []
    if len(values) != _EMBED_DIM:
        raise ValueError("số chiều embedding không khớp %d: %d" % (_EMBED_DIM, len(values)))
    return [float(x) for x in values]


def _truy_van_pgvector(vec: list, model_name: str, gioi_han: int, dia_diem_ids: list = None) -> list:
    """Truy vấn learnloop.tim_doan_rag trên PostgreSQL (nếu bật DATABASE_URL và cài pg8000)."""
    db_url = (os.environ.get("DATABASE_URL") or "").strip()
    if not db_url:
        return []
    try:
        import pg8000.native as pg
    except ImportError:
        return []
    u = urllib.parse.urlparse(db_url)
    con = None
    try:
        con = pg.Connection(
            user=urllib.parse.unquote(u.username or ""),
            password=urllib.parse.unquote(u.password or ""),
            host=u.hostname or "localhost",
            port=u.port or 5432,
            database=(u.path or "/").lstrip("/"),
            timeout=4,
        )
        id_set = set(dia_diem_ids) if dia_diem_ids else None
        k_query = min(50, max(gioi_han * 4, 15)) if id_set else gioi_han
        vec_str = "[" + ",".join(str(float(x)) for x in vec) + "]"
        rows = con.run(
            "SELECT id, nguon, tieu_de, thu_tu, noi_dung, dia_diem_id, khoang_cach_cosine "
            "FROM learnloop.tim_doan_rag(CAST(:vec AS public.vector), :model, :k)",
            vec=vec_str,
            model=model_name,
            k=k_query,
        )
        out = []
        for row in rows:
            did = row[5]
            if id_set is not None and did not in id_set:
                continue
            out.append({
                "tieu_de": row[2],
                "noi_dung": row[4],
                "nguon": row[1],
                "dia_diem_id": did,
                "diem_khop": round(max(0.0, 1.0 - float(row[6])), 4),
            })
            if len(out) >= gioi_han:
                break
        return out
    except Exception:
        return []
    finally:
        if con is not None:
            try:
                con.close()
            except Exception:
                pass


def _tach_tu_rag(s: str) -> list:
    tokens = re.findall(r"[a-z0-9]+", _fold(s or ""))
    return tokens + [tokens[i] + "_" + tokens[i + 1] for i in range(len(tokens) - 1)]


def _truy_van_bm25(cau_hoi: str, dia_diem_ids: list = None, gioi_han: int = 3) -> list:
    """Tìm kiếm BM25 thuần Python trên data/hanoi_rag.json (làm fallback khi chưa bật pgvector)."""
    doan = list(RAG_DATA.get("doan") or [])
    id_list = [i for i in (dia_diem_ids or []) if i]
    id_set = set(id_list)
    ung = [d for d in doan if d.get("dia_diem_id") in id_set] if id_set else doan
    if not ung:
        return []

    pos = {pid: idx for idx, pid in enumerate(id_list)}
    docs_tokens = []
    df = {}
    for d in ung:
        text = " ".join([
            str(d.get("tieu_de") or ""),
            str(d.get("noi_dung") or ""),
            " ".join(d.get("tu_khoa") or []),
        ])
        toks = _tach_tu_rag(text)
        docs_tokens.append(toks)
        for t in set(toks):
            df[t] = df.get(t, 0) + 1

    avgdl = (sum(len(t) for t in docs_tokens) / len(docs_tokens)) or 1.0
    n_docs = len(ung)
    q_tokens = _tach_tu_rag(cau_hoi or "")
    k1, b = 1.5, 0.75

    scored = []
    for idx, (d, dtoks) in enumerate(zip(ung, docs_tokens)):
        tf = {}
        for t in dtoks:
            tf[t] = tf.get(t, 0) + 1
        dl = len(dtoks) or 1
        bm25 = 0.0
        for qt in q_tokens:
            if qt not in tf:
                continue
            idf = math.log((n_docs - df.get(qt, 0) + 0.5) / (df.get(qt, 0) + 0.5) + 1.0)
            freq = tf[qt]
            bm25 += idf * (freq * (k1 + 1.0)) / (freq + k1 * (1.0 - b + b * dl / avgdl))
        did = d.get("dia_diem_id")
        boost = (0.5 - pos[did] * 0.01) if (id_set and did in pos) else 0.0
        total = bm25 + boost
        scored.append((total, -(pos.get(did, 999)), -(d.get("thu_tu", 999)), d))

    if not id_set and max(s[0] for s in scored) <= 0:
        return []
    scored.sort(key=lambda x: (x[0], x[1], x[2]), reverse=True)
    return [
        {
            "tieu_de": d["tieu_de"],
            "noi_dung": d["noi_dung"],
            "nguon": d["nguon"],
            "dia_diem_id": d.get("dia_diem_id"),
            "diem_khop": round(score, 4),
        }
        for score, _, _, d in scored[:gioi_han]
    ]


@tool
def tra_cuu_rag(cau_hoi: str, dia_diem_ids: list = None, gioi_han: int = 3) -> dict:
    """tra_cuu_rag · Input: câu hỏi hoặc từ khoá, danh sách id điểm ưu tiên (tuỳ chọn), số đoạn tối đa (1..10) ·
    Output: {"doan": [{tieu_de, noi_dung, nguon, dia_diem_id, diem_khop}], "nguon_truy_xuat": "pgvector" |
    "local_bm25", "so_ket_qua": int} · Chỉ đọc pgvector (khi bật DATABASE_URL) hoặc data/hanoi_rag.json;
    không tác động ra ngoài."""
    gioi_han = max(1, min(10, int(gioi_han or 3)))
    has_db = bool((os.environ.get("DATABASE_URL") or "").strip())
    has_key = bool((os.environ.get("EMBEDDING_API_KEY") or os.environ.get("API_KEY") or "").strip())
    provider = (os.environ.get("MODEL_PROVIDER") or "").strip().lower()
    if has_db and has_key and provider != "fake":
        try:
            model_name = (os.environ.get("EMBEDDING_MODEL") or _EMBED_MODEL_DEFAULT).strip()
            vec = _nhung_van_ban(cau_hoi)
            rows = _truy_van_pgvector(vec, model_name, gioi_han, dia_diem_ids)
            if rows:
                return {"doan": rows, "nguon_truy_xuat": "pgvector", "so_ket_qua": len(rows)}
        except Exception:
            pass
    rows = _truy_van_bm25(cau_hoi, dia_diem_ids, gioi_han)
    return {"doan": rows, "nguon_truy_xuat": "local_bm25", "so_ket_qua": len(rows)}
