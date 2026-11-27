"""Lưu chuyến đi, check-in và sự kiện thao tác vào PostgreSQL (schema db/migrations 001 + 003).

Bật khi có biến môi trường DATABASE_URL (vd postgresql://learnloop:...@db:5432/learnloop); không có hoặc DB không chạy
→ BatTat được raise, API trả 503 và app vẫn chạy như trước (chỉ lưu trong phiên).
Driver pg8000 (thuần Python). Mỗi lần gọi mở một kết nối ngắn — đủ cho demo, quy mô thật nên dùng pool.

Quyền riêng tư: người dùng ẩn danh (UUID app tự sinh, không email, không tên thật); sự kiện chỉ ghi khi người dùng đã
đồng ý; không nhận nội dung câu hỏi hay toạ độ (lọc ở LOAI_SU_KIEN / _du_lieu_sach); xoá người dùng = xoá hết dữ liệu.
"""
import datetime
import json
import os
import re
import urllib.parse
import uuid

try:
    import pg8000.native as _pg
except ImportError:  # chưa cài: coi như tắt lưu trữ
    _pg = None

GIO_VN = datetime.timezone(datetime.timedelta(hours=7))
TOI_DA_SU_KIEN = 50
# Chỉ nhận các loại sự kiện này; trường du_lieu được phép của từng loại (giá trị số / chuỗi ngắn / bool)
LOAI_SU_KIEN = {
    "mo_man_hinh": {"man"},
    "gui_yeu_cau": {"so_ky_tu", "la_sua"},
    "nhan_lich": {"ok", "so_ngay", "so_diem", "kha_thi", "ms", "co_thoi_tiet"},
    "loi_yeu_cau": {"ma"},
    "bam_chi_duong": {"cap", "dia_diem_id"},
    "xem_chi_tiet": set(),
    "luu_trip": {"so_ngay", "so_diem"},
    "bo_luu_trip": set(),
    "xong_diem": {"dia_diem_id", "ngay_thu", "thu_tu", "xong"},
    "doi_dong_y": {"dong_y"},
}


class BatTat(Exception):
    """Lưu trữ chưa bật hoặc DB không kết nối được."""


class SaiDuLieu(ValueError):
    """Dữ liệu gửi lên không hợp lệ (→ HTTP 400)."""


def _ket_noi():
    url = os.environ.get("DATABASE_URL", "").strip()
    if not url or _pg is None:
        raise BatTat("chưa bật lưu trữ (DATABASE_URL / pg8000)")
    u = urllib.parse.urlparse(url)
    try:
        return _pg.Connection(user=urllib.parse.unquote(u.username or ""), password=urllib.parse.unquote(u.password or ""),
                              host=u.hostname or "localhost", port=u.port or 5432, database=(u.path or "/").lstrip("/"),
                              timeout=5)
    except Exception as e:  # mất kết nối, sai mật khẩu…
        raise BatTat("không kết nối được DB: %s" % type(e).__name__) from None


def _chay(sql, **tham_so):
    con = _ket_noi()
    try:
        return con.run(sql, **tham_so)
    finally:
        con.close()


def _uuid(v, ten="id"):
    try:
        return str(uuid.UUID(str(v)))
    except (ValueError, TypeError, AttributeError):
        raise SaiDuLieu("%s không phải UUID" % ten) from None


def bat():
    """Lưu trữ có dùng được không (cho /api/luu-tru)."""
    try:
        _chay("SELECT 1")
        return True
    except BatTat:
        return False


# ---------- người dùng ----------

def dang_ky(nguoi_dung, dong_y):
    """Tạo / cập nhật người dùng ẩn danh và lựa chọn đồng ý thu thập."""
    nd = _uuid(nguoi_dung, "nguoi_dung")
    _chay("""INSERT INTO learnloop.nguoi_dung (id, ten_hien_thi, an_danh, dong_y_thu_thap, dong_y_luc)
             VALUES (CAST(:id AS uuid), 'Khách ẩn danh', true, :dy, CASE WHEN :dy THEN now() END)
             ON CONFLICT (id) DO UPDATE SET dong_y_thu_thap = EXCLUDED.dong_y_thu_thap,
                                            dong_y_luc = EXCLUDED.dong_y_luc""", id=nd, dy=bool(dong_y))
    return {"nguoi_dung": nd, "dong_y": bool(dong_y)}


def xoa_nguoi_dung(nguoi_dung):
    """Xoá người dùng và mọi dữ liệu (chuyến, điểm dừng, sự kiện, điểm đã lưu — ON DELETE CASCADE)."""
    nd = _uuid(nguoi_dung, "nguoi_dung")
    kq = _chay("DELETE FROM learnloop.nguoi_dung WHERE id = CAST(:id AS uuid) AND an_danh RETURNING id", id=nd)
    return {"da_xoa": bool(kq)}


# ---------- sự kiện ----------

def _du_lieu_sach(loai, du_lieu):
    """Chỉ giữ trường được phép; giá trị là số, bool hoặc chuỗi ≤ 40 ký tự (không nhận nội dung tự do)."""
    out = {}
    for k, v in (du_lieu or {}).items() if isinstance(du_lieu, dict) else []:
        if k not in LOAI_SU_KIEN[loai]:
            continue
        if isinstance(v, bool) or (isinstance(v, (int, float)) and abs(v) < 1e7):
            out[k] = v
        elif isinstance(v, str) and len(v) <= 40 and re.fullmatch(r"[\w\-/ .]*", v):
            out[k] = v
    return out


def ghi_su_kien(nguoi_dung, su_kien):
    """Ghi tối đa TOI_DA_SU_KIEN sự kiện; người dùng chưa đồng ý (hoặc chưa đăng ký) → không ghi gì."""
    nd = _uuid(nguoi_dung, "nguoi_dung")
    if not isinstance(su_kien, list):
        raise SaiDuLieu("su_kien phải là danh sách")
    dong = _chay("SELECT dong_y_thu_thap FROM learnloop.nguoi_dung WHERE id = CAST(:id AS uuid)", id=nd)
    if not dong or not dong[0][0]:
        return {"nhan": 0, "ly_do": "chưa đồng ý thu thập"}
    con = _ket_noi()
    nhan = 0
    try:
        for e in su_kien[:TOI_DA_SU_KIEN]:
            if not isinstance(e, dict) or e.get("loai") not in LOAI_SU_KIEN:
                continue
            try:
                luc = datetime.datetime.fromisoformat(str(e.get("luc")))
            except ValueError:
                luc = datetime.datetime.now(GIO_VN)
            cd = e.get("chuyen_di")
            try:
                cd = _uuid(cd) if cd else None
            except SaiDuLieu:
                cd = None
            con.run("""INSERT INTO learnloop.su_kien (nguoi_dung_id, chuyen_di_id, loai, luc, du_lieu)
                       SELECT CAST(:nd AS uuid), cd.id, :loai, CAST(:luc AS timestamptz), CAST(:dl AS jsonb)
                       FROM (SELECT 1) AS x
                       LEFT JOIN learnloop.chuyen_di AS cd ON cd.id = CAST(:cd AS uuid) AND cd.nguoi_dung_id = CAST(:nd AS uuid)""",
                    nd=nd, loai=e["loai"], luc=luc.isoformat(), cd=cd,
                    dl=json.dumps(_du_lieu_sach(e["loai"], e.get("du_lieu")), ensure_ascii=False))
            nhan += 1
    finally:
        con.close()
    return {"nhan": nhan}


# ---------- chuyến đi ----------

def _buoi(gio):
    h = int(gio.split(":")[0])
    return "sang" if h < 11 else "trua" if h < 13 else "chieu" if h < 18 else "toi"


def luu_chuyen(nguoi_dung, ten, itinerary, ngay_bat_dau=None):
    """Lưu itinerary (dạng /api/plan trả về) thành chuyen_di + ngay_lich_trinh + diem_dung. Trả id và khoá từng điểm."""
    nd = _uuid(nguoi_dung, "nguoi_dung")
    days = (itinerary or {}).get("days") if isinstance(itinerary, dict) else None
    if not isinstance(days, list) or not days:
        raise SaiDuLieu("itinerary.days rỗng")
    if len(days) > 3:
        raise SaiDuLieu("chỉ lưu được chuyến tối đa 3 ngày")
    try:
        bat_dau = datetime.date.fromisoformat(str(ngay_bat_dau or days[0].get("date") or ""))
    except ValueError:
        bat_dau = datetime.datetime.now(GIO_VN).date()
    ten = (str(ten or "").strip() or "Chuyến Hà Nội")[:120]
    con = _ket_noi()
    try:
        con.run("START TRANSACTION")
        if not con.run("SELECT 1 FROM learnloop.nguoi_dung WHERE id = CAST(:id AS uuid)", id=nd):
            con.run("""INSERT INTO learnloop.nguoi_dung (id, ten_hien_thi, an_danh) VALUES (CAST(:id AS uuid), 'Khách ẩn danh', true)""", id=nd)
        cd = con.run("""INSERT INTO learnloop.chuyen_di (nguoi_dung_id, ten, ngay_bat_dau, so_ngay, kha_thi, tong_ve_vnd,
                                                         ve_moi_nguoi_vnd, taxi_uoc_tinh_vnd, ghi_chu)
                        VALUES (CAST(:nd AS uuid), :ten, CAST(:bd AS date), :sn, :kt, :tv, :vn, :tx, CAST(:gc AS text[]))
                        RETURNING id""",
                     nd=nd, ten=ten, bd=bat_dau.isoformat(), sn=len(days), kt=itinerary.get("feasible"),
                     tv=itinerary.get("total_vnd"), vn=itinerary.get("per_person_vnd"), tx=itinerary.get("taxi_vnd"),
                     gc=[str(x)[:500] for x in (itinerary.get("notes") or [])][:20])[0][0]
        diem = []
        for n, d in enumerate(days, 1):
            con.run("INSERT INTO learnloop.ngay_lich_trinh (chuyen_di_id, so_ngay, ngay_thu) VALUES (:cd, :sn, :n)",
                    cd=cd, sn=len(days), n=n)
            for k, s in enumerate(d.get("stops") or [], 1):
                gio = s.get("arrive") if isinstance(s.get("arrive"), str) and re.fullmatch(r"\d\d:\d\d", s.get("arrive", "")) else None
                con.run("""INSERT INTO learnloop.diem_dung (chuyen_di_id, ngay_thu, thu_tu, dia_diem_id, ten_luc_luu, gio_den,
                                                            buoi, phut_di_chuyen, phut_tham_quan, tien_ve_nhom_vnd, ly_do)
                           VALUES (:cd, :n, :k, (SELECT id FROM learnloop.dia_diem WHERE id = :dd), :ten, CAST(:gio AS time),
                                   :buoi, :di, :tq, :ve, :ld)""",
                        cd=cd, n=n, k=k, dd=s.get("id"), ten=str(s.get("name") or s.get("id") or "Điểm")[:200], gio=gio,
                        buoi=_buoi(gio) if gio else None, di=s.get("travel_min_from_prev"),
                        tq=s.get("visit_min") or None, ve=s.get("ticket_vnd"), ld=(s.get("reason") or None))
                diem.append({"ngay_thu": n, "thu_tu": k, "id": s.get("id")})
        con.run("COMMIT")
    except Exception:
        con.run("ROLLBACK")
        raise
    finally:
        con.close()
    return {"chuyen_di": str(cd), "diem": diem}


def danh_sach_chuyen(nguoi_dung):
    """Các chuyến của người dùng, mỗi chuyến kèm điểm dừng và trạng thái check-in."""
    nd = _uuid(nguoi_dung, "nguoi_dung")
    hang = _chay("""SELECT cd.id, cd.ten, cd.ngay_bat_dau, cd.so_ngay, cd.kha_thi, cd.tong_ve_vnd, cd.ve_moi_nguoi_vnd,
                           cd.taxi_uoc_tinh_vnd, cd.ghi_chu, dd.ngay_thu, dd.thu_tu, dd.dia_diem_id, dd.ten_luc_luu,
                           to_char(dd.gio_den, 'HH24:MI'), dd.phut_di_chuyen, dd.phut_tham_quan, dd.tien_ve_nhom_vnd,
                           dd.ly_do, dd.xong_luc
                    FROM learnloop.chuyen_di AS cd
                    LEFT JOIN learnloop.diem_dung AS dd ON dd.chuyen_di_id = cd.id
                    WHERE cd.nguoi_dung_id = CAST(:nd AS uuid)
                    ORDER BY cd.tao_luc DESC, dd.ngay_thu, dd.thu_tu""", nd=nd)
    ket, theo_id = [], {}
    for (cid, ten, bd, sn, kt, tv, vn, tx, gc, n, k, dd, tdd, gio, di, tq, ve, ld, xong) in hang:
        c = theo_id.get(cid)
        if c is None:
            c = theo_id[cid] = {"chuyen_di": str(cid), "ten": ten, "ngay_bat_dau": bd.isoformat(), "itinerary": {
                "days": [{"day": i, "date": (bd + datetime.timedelta(days=i - 1)).isoformat(), "stops": []}
                         for i in range(1, sn + 1)],
                "feasible": kt, "total_vnd": tv, "per_person_vnd": vn, "taxi_vnd": tx, "notes": list(gc or [])}}
            ket.append(c)
        if n is not None:
            c["itinerary"]["days"][n - 1]["stops"].append({
                "id": dd, "name": tdd, "arrive": gio or "", "travel_min_from_prev": di, "visit_min": tq,
                "ticket_vnd": ve, "reason": ld or "", "thu_tu": k, "xong_luc": xong.isoformat() if xong else None})
    return {"chuyen_di": ket}


def check_in(nguoi_dung, chuyen_di, ngay_thu, thu_tu, xong=True):
    """Đánh dấu / bỏ đánh dấu "Đã xong" một điểm dừng (chỉ chủ chuyến)."""
    nd, cd = _uuid(nguoi_dung, "nguoi_dung"), _uuid(chuyen_di, "chuyen_di")
    try:
        n, k = int(ngay_thu), int(thu_tu)
    except (TypeError, ValueError):
        raise SaiDuLieu("ngay_thu / thu_tu phải là số") from None
    kq = _chay("""UPDATE learnloop.diem_dung AS dd SET xong_luc = CASE WHEN :xong THEN now() END
                  FROM learnloop.chuyen_di AS c
                  WHERE dd.chuyen_di_id = c.id AND c.id = CAST(:cd AS uuid) AND c.nguoi_dung_id = CAST(:nd AS uuid)
                    AND dd.ngay_thu = :n AND dd.thu_tu = :k
                  RETURNING dd.xong_luc""", xong=bool(xong), cd=cd, nd=nd, n=n, k=k)
    if not kq:
        raise SaiDuLieu("không tìm thấy điểm dừng của chuyến này")
    return {"xong_luc": kq[0][0].isoformat() if kq[0][0] else None}


def xoa_chuyen(nguoi_dung, chuyen_di):
    nd, cd = _uuid(nguoi_dung, "nguoi_dung"), _uuid(chuyen_di, "chuyen_di")
    kq = _chay("DELETE FROM learnloop.chuyen_di WHERE id = CAST(:cd AS uuid) AND nguoi_dung_id = CAST(:nd AS uuid) RETURNING id",
               cd=cd, nd=nd)
    return {"da_xoa": bool(kq)}
