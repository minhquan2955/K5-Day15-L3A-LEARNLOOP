"""Tra trước thông tin địa điểm từ Wikidata, Wikipedia tiếng Việt, Wikimedia Commons và OpenStreetMap,
ghi ra data/dia_diem_nguon.json để seed vào DB (db/seed/002_dia_diem_nguon.sql). App không gọi các nguồn này lúc chạy.

python db/fetch_sources.py
Wikimedia yêu cầu User-Agent có thông tin liên hệ: đặt WIKIMEDIA_UA="TenApp/1.0 (email-cua-ban)" nếu bị 429.

Giấy phép: dữ liệu OSM theo ODbL (ghi "© OpenStreetMap contributors"), Wikidata CC0,
đoạn trích Wikipedia CC BY-SA 4.0 (ghi link bài), ảnh Commons theo giấy phép từng ảnh (lưu ở anh_ghi_cong).
"""
import datetime as dt
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "dia_diem_nguon.json")
UA = os.environ.get("WIKIMEDIA_UA", "LearnLoopHackathon/1.0 (student project)")

# Mã Wikidata đã đối chiếu nhãn và mô tả; điểm chưa chắc chắn thì để trống chứ không đoán.
WIKIDATA = {
    "lang_bac": "Q874234",
    "chua_mot_cot": "Q1186292",
    "hoang_thanh": "Q206219",
    "van_mieu": "Q1202019",
    "ho_guom": "Q1151254",
    "hoa_lo": "Q1359941",
    "dong_xuan": "Q1094375",
    "pho_duong_tau": "Q85788921",
    "tran_quoc": "Q864770",
}


def fetch(url, data=None):
    for attempt in range(6):
        time.sleep(1.5)  # nhẹ tay với API công cộng
        req = urllib.request.Request(url, data=data, headers={"User-Agent": UA, "Accept": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            if e.code not in (429, 502, 503, 504):
                raise
            wait = int(e.headers.get("Retry-After") or 0) or 10 * 2 ** attempt
            print("  %s → %s, chờ %ss" % (url[:70], e.code, wait), file=sys.stderr)
            time.sleep(min(wait, 120))
    raise RuntimeError("Hết lượt thử: " + url)


def claim(entity, prop):
    for c in entity.get("claims", {}).get(prop, []):
        value = c["mainsnak"].get("datavalue", {}).get("value")
        if value:
            return value
    return None


def plain(text):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", text or ""))).strip()


def source(qid):
    out = {"wikidata": qid}
    entity = fetch("https://www.wikidata.org/wiki/Special:EntityData/%s.json" % qid)["entities"][qid]
    out["website"] = claim(entity, "P856")

    title = entity.get("sitelinks", {}).get("viwiki", {}).get("title")
    if title:
        page = fetch("https://vi.wikipedia.org/api/rest_v1/page/summary/" + urllib.parse.quote(title.replace(" ", "_")))
        if page:
            out["mo_ta"] = page.get("extract")
            out["wikipedia_url"] = page.get("content_urls", {}).get("desktop", {}).get("page")

    image = claim(entity, "P18")
    if image:
        info = fetch("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
            "action": "query", "titles": "File:" + image, "prop": "imageinfo",
            "iiprop": "url|extmetadata", "iiurlwidth": 800, "format": "json"}))
        ii = next(iter(info["query"]["pages"].values())).get("imageinfo", [{}])[0]
        meta = ii.get("extmetadata", {})
        out["anh"] = ii.get("thumburl")
        out["anh_ghi_cong"] = " · ".join(x for x in (
            plain(meta.get("Artist", {}).get("value")),
            plain(meta.get("LicenseShortName", {}).get("value")),
            "Wikimedia Commons") if x)

    query = '[out:json][timeout:25];nwr["wikidata"="%s"];out tags 1;' % qid
    osm = fetch("https://overpass-api.de/api/interpreter", urllib.parse.urlencode({"data": query}).encode())
    tags = (osm or {}).get("elements", [{}])[0].get("tags", {}) if (osm or {}).get("elements") else {}
    out["gio_mo_cua_osm"] = tags.get("opening_hours")
    out["website"] = out["website"] or tags.get("website") or tags.get("contact:website")
    street = " ".join(x for x in (tags.get("addr:housenumber"), tags.get("addr:street")) if x)
    out["dia_chi"] = ", ".join(x for x in (street, tags.get("addr:subdistrict"), tags.get("addr:district"),
                                           tags.get("addr:city")) if x) or None
    return out


def main():
    rows = []
    for id, qid in WIKIDATA.items():
        print("·", id, qid, file=sys.stderr)
        rows.append({"id": id, **source(qid)})
    data = {
        "_nguon": "Wikidata (CC0), Wikipedia tiếng Việt (CC BY-SA 4.0), Wikimedia Commons (giấy phép theo ảnh), "
                  "OpenStreetMap (ODbL, © OpenStreetMap contributors)",
        "tra_luc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "diem": rows,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("Đã ghi", OUT, file=sys.stderr)


if __name__ == "__main__":
    main()
