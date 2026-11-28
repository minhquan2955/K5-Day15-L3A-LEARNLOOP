"""Lấy ỨNG VIÊN điểm tham quan Hà Nội từ Wikidata + OpenStreetMap + Wikivoyage → data/ung_vien_poi.csv để NGƯỜI duyệt.

KHÔNG sửa data/hanoi_poi.json. Giờ mở cửa, giá vé, thời lượng, nhãn sở thích phải được người kiểm trên trang chính
thức của từng điểm rồi mới thêm tay vào hanoi_poi.json (ghi nguồn + ngày xem vào data/DATA_CARD.md).

  python data/lay_ung_vien_poi.py                  khung nội thành (mặc định) → data/ung_vien_poi.csv
  python data/lay_ung_vien_poi.py --rong           khung cả Hà Nội (gồm Chùa Hương, Bát Tràng, Sơn Tây…)
  python data/lay_ung_vien_poi.py --chi wikivoyage chỉ một nguồn (wikidata | osm | wikivoyage)

Mỗi nguồn gọi đúng 1 request:
- Wikidata Query Service (query.wikidata.org): dữ liệu CC0, cần User-Agent, giới hạn 60 giây / truy vấn.
- Overpass API (overpass-api.de): dữ liệu OpenStreetMap, ODbL — phải ghi "© OpenStreetMap contributors" khi dùng.
- Wikivoyage tiếng Anh, trang "Hanoi" (MediaWiki action=raw, không cào HTML): các mục {{see}} / {{do}} có sẵn giờ mở
  cửa, giá vé, toạ độ — CC BY-SA 4.0, phải ghi "Wikivoyage contributors". Do cộng đồng viết, có thể cũ: chỉ để tham khảo.
Chỉ dùng thư viện chuẩn.
"""
import argparse
import csv
import json
import math
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "ung_vien_poi.csv")
UA = "hanoi-poi-candidates/1.0 (python-urllib; one-off research script)"
KHUNG = {  # nam, tây, bắc, đông
    "noi_thanh": (20.95, 105.70, 21.12, 105.95),
    "ca_ha_noi": (20.55, 105.30, 21.40, 106.05),
}
# Lớp Wikidata coi là điểm tham quan (gồm lớp con qua P279*)
LOP_WIKIDATA = {
    "Q570116": "điểm du lịch", "Q33506": "bảo tàng", "Q44539": "đền / chùa", "Q1370598": "nơi thờ tự",
    "Q839954": "di chỉ khảo cổ", "Q4989906": "đài tưởng niệm", "Q1081138": "di tích lịch sử", "Q23397": "hồ",
    "Q22698": "công viên", "Q24354": "nhà hát", "Q330284": "chợ", "Q2065736": "di sản văn hoá",
}
CAU_WIKIDATA = """
SELECT ?item ?ten ?tenEn ?coord ?lop ?xepHang ?moTa ?web ?anh ?viwiki WHERE {
  SERVICE wikibase:box {
    ?item wdt:P625 ?coord .
    bd:serviceParam wikibase:cornerSouthWest "Point(%(tay)s %(nam)s)"^^geo:wktLiteral .
    bd:serviceParam wikibase:cornerNorthEast "Point(%(dong)s %(bac)s)"^^geo:wktLiteral .
  }
  VALUES ?lop { %(lop)s }
  ?item wdt:P31/wdt:P279* ?lop .
  ?item rdfs:label ?ten FILTER(LANG(?ten) = "vi")
  OPTIONAL { ?item rdfs:label ?tenEn FILTER(LANG(?tenEn) = "en") }
  OPTIONAL { ?item schema:description ?moTa FILTER(LANG(?moTa) = "vi") }
  OPTIONAL { ?item wdt:P1435 ?xh . ?xh rdfs:label ?xepHang FILTER(LANG(?xepHang) IN ("vi", "en")) }
  OPTIONAL { ?item wdt:P856 ?web }
  OPTIONAL { ?item wdt:P18 ?anh }
  OPTIONAL { ?viwiki schema:about ?item ; schema:isPartOf <https://vi.wikipedia.org/> }
}
"""
CAU_OVERPASS = """
[out:json][timeout:90];
(
  nwr["tourism"~"^(attraction|museum|gallery|viewpoint|zoo|theme_park)$"]["name"](%(bbox)s);
  nwr["historic"~"^(monument|memorial|archaeological_site|castle|fort|ruins|city_gate|heritage|temple)$"]["name"](%(bbox)s);
  nwr["amenity"="place_of_worship"]["name"]["wikidata"](%(bbox)s);
  nwr["amenity"="theatre"]["name"]["wikidata"](%(bbox)s);
);
out center tags;
"""
COT = ["ung_vien", "ten", "ten_en", "loai", "xep_hang_di_tich", "lat", "lon", "gio_mo_osm", "gio_wikivoyage",
       "gia_wikivoyage", "website", "wikidata", "osm", "wikipedia_vi", "anh", "mo_ta", "da_co_trong_du_lieu", "nguon",
       # người duyệt điền (kiểm trên trang chính thức):
       "mo", "dong", "gia_ve", "tre_em_mien_phi_duoi", "phut_tham_quan", "so_thich", "nguon_kiem", "ngay_kiem",
       "nguoi_kiem", "quyet_dinh"]


def _fold(s):
    s = unicodedata.normalize("NFD", (s or "").lower()).replace("đ", "d")
    return " ".join("".join(c for c in s if unicodedata.category(c) != "Mn").replace("–", " ").replace("-", " ").split())


def _km(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * 6371.0 * math.asin(math.sqrt(h))


def _goi(url, data=None, tho=False):
    """POST form (truy vấn dài) → JSON (tho=True: trả chữ thô). Gặp 429 thì nghỉ theo Retry-After (tối đa 30 giây) rồi thử lại 1 lần."""
    for lan in range(2):
        req = urllib.request.Request(url, data=data, headers={
            "User-Agent": UA, "Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                chu = r.read().decode("utf-8")
                return chu if tho else json.loads(chu)
        except urllib.error.HTTPError as e:
            if e.code == 429 and lan == 0:
                nghi = min(30, int(e.headers.get("Retry-After") or 10))
                print("  %s báo 429, nghỉ %d giây rồi thử lại…" % (url.split("/")[2], nghi))
                time.sleep(nghi)
                continue
            body = " ".join(e.read().decode("utf-8", "replace").split())[:300]
            sys.exit("HTTP %d từ %s: %s" % (e.code, url, body))
        except urllib.error.URLError as e:
            sys.exit("Không gọi được %s (%s)" % (url, e.reason))


def _tach_mau(s, ten_mau):
    """Tìm các mẫu {{see|...}} / {{do|...}} trong wikitext; trả dict tham số (tách '|' ở cấp ngoài cùng)."""
    out, i = [], 0
    mo = re.compile(r"\{\{\s*(%s)\s*\|" % "|".join(ten_mau), re.I)
    while True:
        m = mo.search(s, i)
        if not m:
            return out
        j, sau, phan, cur = m.end(), 0, [], []
        while j < len(s):
            if s.startswith("{{", j) or s.startswith("[[", j):
                sau += 1
                cur.append(s[j:j + 2])
                j += 2
                continue
            if s.startswith("}}", j) or s.startswith("]]", j):
                if sau == 0 and s.startswith("}}", j):
                    break
                sau -= 1
                cur.append(s[j:j + 2])
                j += 2
                continue
            if s[j] == "|" and sau == 0:
                phan.append("".join(cur))
                cur = []
            else:
                cur.append(s[j])
            j += 1
        phan.append("".join(cur))
        tham_so = {"_loai": m.group(1).lower()}
        for x in phan:
            if "=" in x:
                k, v = x.split("=", 1)
                tham_so[k.strip().lower()] = _sach_wiki(v)
        out.append(tham_so)
        i = j + 2


def _sach_wiki(v):
    v = re.sub(r"\[\[(?:[^|\]]*\|)?([^\]]*)\]\]", r"\1", v)        # [[a|b]] → b
    v = re.sub(r"\{\{[^{}]*\}\}", "", v)                            # mẫu lồng (vd {{VND|…}})
    v = re.sub(r"'{2,}|<[^>]+>", "", v)                              # in đậm / nghiêng, thẻ HTML
    return " ".join(v.split())


def lay_wikivoyage(khung):
    nam, tay, bac, dong = khung
    s = _goi("https://en.wikivoyage.org/w/index.php?" + urllib.parse.urlencode({"title": "Hanoi", "action": "raw"}),
             tho=True)
    out = []
    for t in _tach_mau(s, ["see", "do"]):
        try:
            lat, lon = float(t.get("lat", "")), float(t.get("long", ""))
        except ValueError:
            continue
        if not (t.get("name") and nam <= lat <= bac and tay <= lon <= dong):
            continue
        out.append({"ten": t.get("alt") or t["name"], "ten_en": t["name"], "lat": round(lat, 5), "lon": round(lon, 5),
                    "loai": {"wikivoyage " + t["_loai"]}, "xep_hang_di_tich": set(), "mo_ta": t.get("content", "")[:300],
                    "website": t.get("url", ""), "anh": "", "wikipedia_vi": "", "wikidata": t.get("wikidata", ""),
                    "gio_wikivoyage": t.get("hours", ""), "gia_wikivoyage": t.get("price", ""), "nguon": {"wikivoyage"}})
    return out


def lay_wikidata(khung):
    nam, tay, bac, dong = khung
    cau = CAU_WIKIDATA % {"nam": nam, "tay": tay, "bac": bac, "dong": dong,
                          "lop": " ".join("wd:" + q for q in LOP_WIKIDATA)}
    res = _goi("https://query.wikidata.org/sparql",
               urllib.parse.urlencode({"query": cau, "format": "json"}).encode("utf-8"))
    gop = {}
    for b in res["results"]["bindings"]:
        v = {k: x["value"] for k, x in b.items()}
        q = v["item"].rsplit("/", 1)[-1]
        lon, lat = v["coord"].replace("Point(", "").rstrip(")").split()
        d = gop.setdefault(q, {"wikidata": q, "ten": v["ten"], "ten_en": v.get("tenEn", ""), "lat": round(float(lat), 5),
                               "lon": round(float(lon), 5), "loai": set(), "xep_hang_di_tich": set(),
                               "mo_ta": v.get("moTa", ""), "website": v.get("web", ""), "anh": v.get("anh", ""),
                               "wikipedia_vi": v.get("viwiki", ""), "nguon": {"wikidata"}})
        d["loai"].add(LOP_WIKIDATA.get(v["lop"].rsplit("/", 1)[-1], ""))
        if v.get("xepHang"):
            d["xep_hang_di_tich"].add(v["xepHang"])
    return list(gop.values())


def lay_osm(khung):
    nam, tay, bac, dong = khung
    cau = CAU_OVERPASS % {"bbox": "%s,%s,%s,%s" % (nam, tay, bac, dong)}
    res = _goi("https://overpass-api.de/api/interpreter", urllib.parse.urlencode({"data": cau}).encode("utf-8"))
    out = []
    for e in res.get("elements", []):
        t = e.get("tags", {})
        lat, lon = (e.get("lat"), e.get("lon")) if "lat" in e else (e.get("center", {}).get("lat"), e.get("center", {}).get("lon"))
        if lat is None or not t.get("name"):
            continue
        loai = t.get("tourism") or t.get("historic") or t.get("amenity") or ""
        out.append({"ten": t.get("name:vi") or t["name"], "ten_en": t.get("name:en", ""), "lat": round(lat, 5),
                    "lon": round(lon, 5), "loai": {loai}, "xep_hang_di_tich": set(), "mo_ta": t.get("description", ""),
                    "website": t.get("website") or t.get("contact:website", ""), "anh": "", "wikipedia_vi": "",
                    "wikidata": t.get("wikidata", ""), "osm": "%s/%s" % (e["type"], e["id"]),
                    "gio_mo_osm": t.get("opening_hours", ""), "nguon": {"osm"}})
    return out


def gop(wd, *nguon_khac):
    """Gộp theo mã Wikidata; không có thì theo tên (vi hoặc en) giống nhau và cách < 150 m (< 300 m nếu tên khớp
    một phần — Wikivoyage hay viết tên khác OSM)."""
    theo_q = {d["wikidata"]: d for d in wd}
    ket = list(wd)
    for o in (o for ds in nguon_khac for o in ds):
        d = theo_q.get(o["wikidata"]) if o["wikidata"] else None
        if d is None:
            ten_o = {_fold(o["ten"]), _fold(o.get("ten_en", ""))} - {""}
            for x in ket:
                ten_x = {_fold(x["ten"]), _fold(x.get("ten_en", ""))} - {""}
                km = _km((x["lat"], x["lon"]), (o["lat"], o["lon"]))
                if (ten_o & ten_x and km < 0.15) or (km < 0.3 and any(a in b or b in a for a in ten_o for b in ten_x)):
                    d = x
                    break
        if d is None:
            ket.append(o)
            continue
        d["nguon"] |= o["nguon"]
        d["loai"] |= o["loai"]
        for k in ("osm", "gio_mo_osm", "gio_wikivoyage", "gia_wikivoyage", "website", "ten_en", "mo_ta", "wikidata"):
            if o.get(k) and not d.get(k):
                d[k] = o[k]
    return ket


def danh_dau_da_co(ung_vien):
    with open(os.path.join(ROOT, "data", "hanoi_poi.json"), encoding="utf-8") as f:
        diem = json.load(f)["diem"]
    for u in ung_vien:
        fu = _fold(u["ten"])
        for p in diem:
            ten = [_fold(x) for x in p["ten_khac"] + [p["ten"]]]
            gan = _km((u["lat"], u["lon"]), (p["lat"], p["lon"])) < 0.3
            if gan and (any(t in fu or fu in t for t in ten) or _km((u["lat"], u["lon"]), (p["lat"], p["lon"])) < 0.05):
                u["da_co_trong_du_lieu"] = p["id"]
                break


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--rong", action="store_true", help="khung cả Hà Nội thay vì nội thành")
    ap.add_argument("--chi", choices=["wikidata", "osm", "wikivoyage"], help="chỉ lấy một nguồn")
    args = ap.parse_args(argv)
    khung = KHUNG["ca_ha_noi" if args.rong else "noi_thanh"]

    wd = [] if args.chi == "osm" else lay_wikidata(khung)
    print("Wikidata: %d điểm" % len(wd))
    osm = [] if args.chi == "wikidata" else lay_osm(khung)
    print("OpenStreetMap: %d điểm" % len(osm))
    wv = [] if args.chi in ("wikidata", "osm") else lay_wikivoyage(khung)
    print("Wikivoyage: %d điểm (%d có giờ mở cửa, %d có giá)"
          % (len(wv), sum(1 for x in wv if x["gio_wikivoyage"]), sum(1 for x in wv if x["gia_wikivoyage"])))
    ung_vien = gop(wd, osm, wv)
    danh_dau_da_co(ung_vien)
    # Ưu tiên duyệt: có trên Wikivoyage (có giờ / giá) > có xếp hạng di tích > có bài Wikipedia tiếng Việt > nhiều nguồn
    ung_vien.sort(key=lambda u: ("wikivoyage" not in u["nguon"], not u["xep_hang_di_tich"], not u["wikipedia_vi"],
                                 -len(u["nguon"]), _fold(u["ten"])))
    with open(OUT, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COT, extrasaction="ignore")
        w.writeheader()
        for i, u in enumerate(ung_vien, 1):
            w.writerow(dict(u, ung_vien="U%03d" % i, loai="; ".join(sorted(x for x in u["loai"] if x)),
                            xep_hang_di_tich="; ".join(sorted(u["xep_hang_di_tich"])),
                            nguon=" + ".join(sorted(u["nguon"])), da_co_trong_du_lieu=u.get("da_co_trong_du_lieu", "")))
    da_co = sum(1 for u in ung_vien if u.get("da_co_trong_du_lieu"))
    print("Đã ghi %s: %d ứng viên (%d trùng điểm đã có, %d có xếp hạng di tích, %d có từ 2 nguồn, %d có giờ hoặc giá "
          "Wikivoyage)." % (os.path.relpath(OUT, ROOT), len(ung_vien), da_co,
                            sum(1 for u in ung_vien if u["xep_hang_di_tich"]), sum(1 for u in ung_vien if len(u["nguon"]) > 1),
                            sum(1 for u in ung_vien if u.get("gio_wikivoyage") or u.get("gia_wikivoyage"))))
    print("Bước tiếp: người duyệt điền cột mo / dong / gia_ve / phut_tham_quan / so_thich từ trang chính thức, "
          "ghi nguon_kiem + ngay_kiem, rồi mới thêm vào data/hanoi_poi.json.")
    return 0


if __name__ == "__main__":
    for _s in (sys.stdout, sys.stderr):
        try:
            _s.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
    sys.exit(main(sys.argv[1:]))
