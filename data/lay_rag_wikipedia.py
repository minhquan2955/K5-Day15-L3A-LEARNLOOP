"""Lấy tóm tắt mở đầu từ Wikipedia tiếng Việt (CC BY-SA 4.0) cho các điểm trong data/hanoi_poi.json
và cập nhật vào data/hanoi_rag.json để dùng cho RAG (BM25 cục bộ và pgvector).

Chạy từ thư mục gốc:
    python3 data/lay_rag_wikipedia.py

Chỉ dùng thư viện chuẩn Python; giữ nguyên các đoạn tự biên soạn / báo chí trong hanoi_rag.json,
lọc sạch giờ mở cửa, giá vé, thời lượng phút và các từ cấm của bộ kiểm thử.
"""
import json
import os
import re
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POI_PATH = os.path.join(ROOT, "data", "hanoi_poi.json")
RAG_PATH = os.path.join(ROOT, "data", "hanoi_rag.json")

WIKI_SOURCE = "Wikipedia tiếng Việt (CC BY-SA 4.0)"
UA = "learnloop-hanoi-rag/1.0 (python-urllib; hackathon-educational)"
API_URL = "https://vi.wikipedia.org/w/api.php?"

WIKI_TITLES = {
    "lang_bac": "Lăng Chủ tịch Hồ Chí Minh",
    "chua_mot_cot": "Chùa Một Cột",
    "hoang_thanh": "Hoàng thành Thăng Long",
    "van_mieu": "Văn Miếu – Quốc Tử Giám",
    "ho_guom": "Hồ Hoàn Kiếm",
    "hoa_lo": "Nhà tù Hỏa Lò",
    "dong_xuan": "Chợ Đồng Xuân",
    "pho_duong_tau": "Đường sắt Bắc – Nam",
    "tran_quoc": "Chùa Trấn Quốc",
    "bt_dan_toc_hoc": "Bảo tàng Dân tộc học Việt Nam",
    "pho_di_bo": "Đền Ngọc Sơn",
    "nha_hat_lon": "Nhà hát Lớn Hà Nội",
    "bat_trang": "Bát Tràng",
    "chua_huong": "Chùa Hương",
    "nha_tho_lon": "Nhà thờ Lớn Hà Nội",
    "bt_phu_nu": "Bảo tàng Phụ nữ Việt Nam",
    "bt_lich_su": "Bảo tàng Lịch sử quốc gia (Việt Nam)",
    "bt_ho_chi_minh": "Bảo tàng Hồ Chí Minh",
    "bt_quan_su": "Bảo tàng Lịch sử Quân sự Việt Nam",
    "phu_chu_tich": "Khu di tích Phủ Chủ tịch",
    "den_quan_thanh": "Đền Quán Thánh",
    "den_bach_ma": "Đền Bạch Mã",
    "chua_quan_su": "Chùa Quán Sứ",
    "thu_le": "Công viên Thủ Lệ",
}

TU_CAM = (
    "đông",
    "buổi chiều",
    "trong ngân sách",
    "ngày đầu tiên",
    "đi lại ít nhất",
    "google.com",
    "vắng",
)
_GIO_GIA = re.compile(
    r"(?:\b\d{1,2}\s*(?:h|giờ|:)\s*\d{0,2}\b"
    r"|\b\d[\d.,]*\s*(?:đồng|đ\b|vnd|nghìn)\b"
    r"|\b\d+\s*(?:phút|tiếng)\b)",
    re.I,
)
_CHU_THICH = re.compile(r"\[[^\]]{1,20}\]")


def _sach_cau(cau: str) -> bool:
    low = cau.lower()
    if len(cau.strip()) < 25:
        return False
    if _GIO_GIA.search(cau):
        return False
    return not any(cam in low for cam in TU_CAM)


def _loc_noi_dung(raw: str, max_len: int = 360) -> str:
    txt = _CHU_THICH.sub("", raw or "")
    txt = re.sub(r"\s+", " ", txt).strip()
    if not txt:
        return ""
    cau_ds = re.split(r"(?<=[.!?])\s+", txt)
    chon = []
    tong = 0
    for cau in cau_ds:
        cau = cau.strip()
        if not _sach_cau(cau):
            continue
        cong = len(cau) + (1 if chon else 0)
        if chon and tong + cong > max_len:
            break
        chon.append(cau)
        tong += cong
        if len(chon) >= 2:
            break
    kq = " ".join(chon).strip()
    if len(kq) > max_len:
        cat = kq[: max_len - 1].rsplit(" ", 1)[0].rstrip(",;:")
        kq = (cat or kq[: max_len - 1]) + "…"
    return kq


def tai_wikipedia(titles_by_id: dict) -> list:
    """Gọi MediaWiki API theo batch tối đa 20 tiêu đề/lần, trả danh sách đoạn đạt chuẩn."""
    with open(POI_PATH, encoding="utf-8") as f:
        poi_map = {p["id"]: p for p in json.load(f).get("diem", [])}

    items = list(titles_by_id.items())
    results = []
    for start in range(0, len(items), 20):
        batch = items[start : start + 20]
        url = API_URL + urllib.parse.urlencode({
            "action": "query",
            "prop": "extracts|info",
            "exintro": 1,
            "explaintext": 1,
            "inprop": "url",
            "redirects": 1,
            "format": "json",
            "utf8": 1,
            "titles": "|".join(t for _, t in batch),
        })
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=15) as r:
            data = json.loads(r.read().decode("utf-8"))

        query = data.get("query") or {}
        norm = {x["from"]: x["to"] for x in query.get("normalized") or []}
        redir = {x["from"]: x["to"] for x in query.get("redirects") or []}
        pages_by_title = {}
        for p in (query.get("pages") or {}).values():
            if not p.get("missing"):
                pages_by_title[p.get("title", "")] = p

        for pid, req_title in batch:
            t = norm.get(req_title, req_title)
            t = redir.get(t, t)
            page = pages_by_title.get(t)
            if not page:
                continue
            noi_dung = _loc_noi_dung(page.get("extract", ""))
            title = str(page.get("title") or t).strip()
            tieu_de = "Tổng quan từ Wikipedia: %s" % title
            if not noi_dung or any(cam in tieu_de.lower() for cam in TU_CAM):
                continue
            poi = poi_map.get(pid) or {}
            tu_khoa = [k for k in [poi.get("ten", ""), title, "hà nội", "wikipedia"] if k]
            tu_khoa.extend(poi.get("ten_khac") or [])
            results.append({
                "nguon": WIKI_SOURCE,
                "url": page.get("fullurl") or (
                    "https://vi.wikipedia.org/wiki/" + urllib.parse.quote(title.replace(" ", "_"), safe="/:")
                ),
                "tieu_de": tieu_de,
                "dia_diem_id": pid,
                "noi_dung": noi_dung,
                "tu_khoa": list(dict.fromkeys(x.lower() for x in tu_khoa if x)),
            })
    return results


def cap_nhat_rag() -> dict:
    with open(RAG_PATH, encoding="utf-8") as f:
        rag = json.load(f)
    giu_lai = [d for d in (rag.get("doan") or []) if d.get("nguon") != WIKI_SOURCE]
    wiki_doan = tai_wikipedia(WIKI_TITLES)
    tat_ca = giu_lai + wiki_doan
    for idx, d in enumerate(tat_ca, 1):
        d["thu_tu"] = idx
    rag["phien_ban"] = "hanoi-rag-v3 · 28/11/2026"
    rag["_ghi_chu"] = (
        "Mẹo tham quan và ngữ cảnh văn hoá-lịch sử cho 24 điểm trong data/hanoi_poi.json "
        "(tổng hợp từ cẩm nang nhóm, Wikipedia tiếng Việt CC BY-SA 4.0 và báo chính thống; "
        "không chứa giờ mở cửa hay giá vé)."
    )
    rag["doan"] = tat_ca
    with open(RAG_PATH, "w", encoding="utf-8") as f:
        json.dump(rag, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return {"giu_lai": len(giu_lai), "wikipedia": len(wiki_doan), "tong": len(tat_ca)}


if __name__ == "__main__":
    kq = cap_nhat_rag()
    print("Đã cập nhật %s: giữ %d đoạn có sẵn + %d đoạn Wikipedia = %d đoạn"
          % (RAG_PATH, kq["giu_lai"], kq["wikipedia"], kq["tong"]))
