"""CRUD cho dữ liệu app (địa điểm, hồ sơ, địa điểm đã lưu, chuyến đi) trên schema `learnloop` — xem db/README.md.

Dữ liệu cá nhân gắn với người đang đăng nhập (server/auth.py); sửa danh mục cần quyền quản trị.
"""
import datetime as dt
import uuid
from typing import Literal, Optional

from fastapi import APIRouter, Depends, FastAPI, HTTPException
from pydantic import BaseModel, Field

from server import auth
from server.auth import admin_user, current_user
from server.database import db, install_errors

router = APIRouter(prefix="/api")
MAX_TRIP_DAYS = 14  # khớp chuyen_di_so_ngay_check (migration 005)


def install(app: FastAPI):
    app.include_router(auth.router)
    app.include_router(router)
    install_errors(app)


def _must(row, what):
    if row is None:
        raise HTTPException(404, "Không tìm thấy %s" % what)
    return row


# ---------- Địa điểm (danh mục) ----------

PLACE_SQL = """
SELECT d.*, coalesce(array_agg(s.so_thich_ma ORDER BY s.so_thich_ma)
                     FILTER (WHERE s.so_thich_ma IS NOT NULL), '{}') AS so_thich
FROM learnloop.dia_diem d LEFT JOIN learnloop.dia_diem_so_thich s ON s.dia_diem_id = d.id
"""


class DiaDiemIn(BaseModel):
    ten: str = Field(min_length=1)
    ten_khac: list[str] = []
    quan: Optional[str] = None
    mo_ta: Optional[str] = None
    anh: Optional[str] = None
    vi_do: float = Field(ge=-90, le=90)
    kinh_do: float = Field(ge=-180, le=180)
    gio_mo: dt.time
    gio_dong: dt.time
    phut_tham_quan: int = Field(gt=0)
    gia_ve_vnd: int = Field(ge=0)
    tre_em_mien_phi_duoi: Optional[int] = Field(default=None, ge=1, le=18)
    wikidata: Optional[str] = Field(default=None, pattern=r"^Q[0-9]+$")
    dia_chi: Optional[str] = None
    website: Optional[str] = None
    gio_mo_cua_osm: Optional[str] = None
    wikipedia_url: Optional[str] = None
    anh_ghi_cong: Optional[str] = None
    so_thich: list[str] = []


class DiaDiemTao(DiaDiemIn):
    id: str = Field(pattern=r"^[a-z][a-z0-9_]*$")


def _place(conn, id):
    return _must(conn.execute(PLACE_SQL + " WHERE d.id = %s GROUP BY d.id", (id,)).fetchone(), "địa điểm")


def _set_tags(conn, id, tags):
    conn.execute("DELETE FROM learnloop.dia_diem_so_thich WHERE dia_diem_id = %s", (id,))
    for tag in set(tags):  # mã sở thích lạ → khoá ngoại báo lỗi → 400
        conn.execute("INSERT INTO learnloop.dia_diem_so_thich VALUES (%s, %s)", (id, tag))


@router.get("/so-thich")
def list_tags(conn=Depends(db)):
    return [r["ma"] for r in conn.execute("SELECT ma FROM learnloop.so_thich ORDER BY ma")]


@router.get("/dia-diem")
def list_places(conn=Depends(db)):
    return conn.execute(PLACE_SQL + " GROUP BY d.id ORDER BY d.ten").fetchall()


@router.get("/dia-diem/{id}")
def get_place(id: str, conn=Depends(db)):
    return _place(conn, id)


@router.post("/dia-diem", status_code=201)
def create_place(body: DiaDiemTao, conn=Depends(db), _=Depends(admin_user)):
    d = body.model_dump(exclude={"so_thich"})
    cols = ", ".join(d)
    conn.execute("INSERT INTO learnloop.dia_diem (%s, du_lieu_mau) VALUES (%s, false)"
                 % (cols, ", ".join("%%(%s)s" % k for k in d)), d)
    _set_tags(conn, body.id, body.so_thich)
    return _place(conn, body.id)


@router.put("/dia-diem/{id}")
def update_place(id: str, body: DiaDiemIn, conn=Depends(db), _=Depends(admin_user)):
    d = body.model_dump(exclude={"so_thich"})
    sets = ", ".join("%s = %%(%s)s" % (k, k) for k in d)
    _must(conn.execute("UPDATE learnloop.dia_diem SET %s WHERE id = %%(id)s RETURNING id" % sets,
                       {**d, "id": id}).fetchone(), "địa điểm")
    _set_tags(conn, id, body.so_thich)
    return _place(conn, id)


@router.delete("/dia-diem/{id}", status_code=204)
def delete_place(id: str, conn=Depends(db), _=Depends(admin_user)):
    # điểm dừng giữ ten_luc_luu, dia_diem_id thành NULL (ON DELETE SET NULL)
    _must(conn.execute("DELETE FROM learnloop.dia_diem WHERE id = %s RETURNING id", (id,)).fetchone(), "địa điểm")


# ---------- Hồ sơ ----------

class HoSoIn(BaseModel):
    ten_hien_thi: str = Field(min_length=1, max_length=100)
    email: str = Field(pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$", max_length=254)
    so_dien_thoai: Optional[str] = None
    anh_dai_dien: Optional[str] = None


@router.get("/toi")
def get_me(user=Depends(current_user)):
    return auth.public(user)


@router.put("/toi")
def update_me(body: HoSoIn, conn=Depends(db), user=Depends(current_user)):
    d = body.model_dump()
    d["email"] = d["email"].strip().lower()
    return auth.public(conn.execute(
        "UPDATE learnloop.nguoi_dung SET ten_hien_thi = %(ten_hien_thi)s, email = %(email)s, "
        "so_dien_thoai = %(so_dien_thoai)s, anh_dai_dien = %(anh_dai_dien)s WHERE id = %(id)s RETURNING *",
        {**d, "id": user["id"]}).fetchone())


# ---------- Địa điểm đã lưu ----------

@router.get("/da-luu")
def list_saved(conn=Depends(db), user=Depends(current_user)):
    return conn.execute(
        PLACE_SQL + " JOIN learnloop.dia_diem_da_luu l ON l.dia_diem_id = d.id AND l.nguoi_dung_id = %s"
        " GROUP BY d.id, l.luu_luc ORDER BY l.luu_luc DESC", (user["id"],)).fetchall()


@router.put("/da-luu/{dia_diem_id}", status_code=204)
def save_place(dia_diem_id: str, conn=Depends(db), user=Depends(current_user)):
    _place(conn, dia_diem_id)
    conn.execute("INSERT INTO learnloop.dia_diem_da_luu (nguoi_dung_id, dia_diem_id) VALUES (%s, %s) "
                 "ON CONFLICT DO NOTHING", (user["id"], dia_diem_id))


@router.delete("/da-luu/{dia_diem_id}", status_code=204)
def unsave_place(dia_diem_id: str, conn=Depends(db), user=Depends(current_user)):
    conn.execute("DELETE FROM learnloop.dia_diem_da_luu WHERE nguoi_dung_id = %s AND dia_diem_id = %s",
                 (user["id"], dia_diem_id))


# ---------- Chuyến đi ----------

class DiemDungIn(BaseModel):
    ten_luc_luu: str = Field(min_length=1)
    dia_diem_id: Optional[str] = None
    gio_den: Optional[dt.time] = None
    buoi: Optional[Literal["sang", "trua", "chieu", "toi"]] = None
    phut_di_chuyen: Optional[int] = Field(default=None, ge=0)
    phut_tham_quan: Optional[int] = Field(default=None, gt=0)
    tien_ve_nhom_vnd: Optional[int] = Field(default=None, ge=0)
    ly_do: Optional[str] = None


class NgayIn(BaseModel):
    diem_dung: list[DiemDungIn] = []


class ChuyenDiSua(BaseModel):
    ten: Optional[str] = Field(default=None, min_length=1)
    ngay_bat_dau: Optional[dt.date] = None
    yeu_thich: Optional[bool] = None
    kha_thi: Optional[bool] = None
    tong_ve_vnd: Optional[int] = Field(default=None, ge=0)
    ve_moi_nguoi_vnd: Optional[int] = Field(default=None, ge=0)
    taxi_uoc_tinh_vnd: Optional[int] = Field(default=None, ge=0)
    ghi_chu: Optional[list[str]] = None
    ngay: Optional[list[NgayIn]] = Field(default=None, min_length=1, max_length=MAX_TRIP_DAYS)  # có thì thay cả lịch trình


class ChuyenDiTao(ChuyenDiSua):
    ten: str = Field(min_length=1)
    ngay_bat_dau: dt.date
    ngay: list[NgayIn] = Field(min_length=1, max_length=MAX_TRIP_DAYS)


TRIP_SQL = """
SELECT t.*, (SELECT count(*) FROM learnloop.diem_dung s WHERE s.chuyen_di_id = t.id) AS so_diem_dung,
       (SELECT d.anh FROM learnloop.diem_dung s JOIN learnloop.dia_diem d ON d.id = s.dia_diem_id
        WHERE s.chuyen_di_id = t.id AND d.anh IS NOT NULL ORDER BY s.ngay_thu, s.thu_tu LIMIT 1) AS anh
FROM learnloop.chuyen_di_theo_trang_thai t WHERE t.nguoi_dung_id = %s
"""


def _trip(conn, uid, id):
    trip = _must(conn.execute(TRIP_SQL + " AND t.id = %s", (uid, id)).fetchone(), "chuyến đi")
    stops = conn.execute("SELECT * FROM learnloop.diem_dung WHERE chuyen_di_id = %s ORDER BY ngay_thu, thu_tu",
                         (id,)).fetchall()
    trip["ngay"] = [{"ngay_thu": n, "diem_dung": [s for s in stops if s["ngay_thu"] == n]}
                    for n in range(1, trip["so_ngay"] + 1)]
    return trip


def _write_days(conn, id, days):
    """Xoá ngày cũ (kéo theo điểm dừng) rồi ghi lại; so_ngay đổi theo số ngày gửi lên."""
    conn.execute("DELETE FROM learnloop.ngay_lich_trinh WHERE chuyen_di_id = %s", (id,))
    conn.execute("UPDATE learnloop.chuyen_di SET so_ngay = %s WHERE id = %s", (len(days), id))
    for n, day in enumerate(days, 1):
        conn.execute("INSERT INTO learnloop.ngay_lich_trinh VALUES (%s, %s, %s)", (id, len(days), n))
        for k, stop in enumerate(day.diem_dung, 1):
            d = stop.model_dump()
            conn.execute("INSERT INTO learnloop.diem_dung (chuyen_di_id, ngay_thu, thu_tu, %s) VALUES (%%s, %%s, %%s, %s)"
                         % (", ".join(d), ", ".join(["%s"] * len(d))), (id, n, k, *d.values()))


TRIP_FIELDS = ["ten", "ngay_bat_dau", "yeu_thich", "kha_thi", "tong_ve_vnd", "ve_moi_nguoi_vnd",
               "taxi_uoc_tinh_vnd", "ghi_chu"]


@router.get("/chuyen-di")
def list_trips(conn=Depends(db), user=Depends(current_user)):
    return conn.execute(TRIP_SQL + " ORDER BY t.ngay_bat_dau DESC, t.tao_luc DESC", (user["id"],)).fetchall()


@router.get("/chuyen-di/{id}")
def get_trip(id: str, conn=Depends(db), user=Depends(current_user)):
    return _trip(conn, user["id"], _uuid(id))


@router.post("/chuyen-di", status_code=201)
def create_trip(body: ChuyenDiTao, conn=Depends(db), user=Depends(current_user)):
    d = body.model_dump(include=set(TRIP_FIELDS), exclude_none=True)
    row = conn.execute("INSERT INTO learnloop.chuyen_di (nguoi_dung_id, so_ngay, %s) VALUES (%%s, %%s, %s) RETURNING id"
                       % (", ".join(d), ", ".join(["%s"] * len(d))),
                       (user["id"], len(body.ngay), *d.values())).fetchone()
    _write_days(conn, row["id"], body.ngay)
    return _trip(conn, user["id"], row["id"])


@router.patch("/chuyen-di/{id}")
def update_trip(id: str, body: ChuyenDiSua, conn=Depends(db), user=Depends(current_user)):
    id = _uuid(id)
    _trip(conn, user["id"], id)  # 404 nếu không phải chuyến của người dùng này
    d = body.model_dump(include=set(TRIP_FIELDS), exclude_unset=True)
    if d:
        conn.execute("UPDATE learnloop.chuyen_di SET %s WHERE id = %%s" % ", ".join("%s = %%s" % k for k in d),
                     (*d.values(), id))
    if body.ngay is not None:
        _write_days(conn, id, body.ngay)
    return _trip(conn, user["id"], id)


@router.delete("/chuyen-di/{id}", status_code=204)
def delete_trip(id: str, conn=Depends(db), user=Depends(current_user)):
    _must(conn.execute("DELETE FROM learnloop.chuyen_di WHERE id = %s AND nguoi_dung_id = %s RETURNING id",
                       (_uuid(id), user["id"])).fetchone(), "chuyến đi")


def _uuid(id):
    try:
        return str(uuid.UUID(str(id)))
    except ValueError:
        raise HTTPException(404, "Không tìm thấy chuyến đi")
