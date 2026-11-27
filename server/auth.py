"""Đăng ký / đăng nhập bằng email + mật khẩu. Token phiên gửi qua `Authorization: Bearer <token>`."""
import hashlib
import hmac
import secrets

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field

from server.database import db

router = APIRouter(prefix="/api")
SESSION_DAYS = 30
_N, _R, _P = 2 ** 14, 8, 1  # tham số scrypt


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(password.encode(), salt=salt, n=_N, r=_R, p=_P)
    return "scrypt$%d$%d$%d$%s$%s" % (_N, _R, _P, salt.hex(), digest.hex())


def check_password(password: str, stored: str | None) -> bool:
    if not stored:
        return False
    _, n, r, p, salt, digest = stored.split("$")
    got = hashlib.scrypt(password.encode(), salt=bytes.fromhex(salt), n=int(n), r=int(r), p=int(p))
    return hmac.compare_digest(got.hex(), digest)


def _token_hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def current_user(authorization: str = Header(default=""), conn=Depends(db)):
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(401, "Chưa đăng nhập")
    user = conn.execute(
        "SELECT u.* FROM learnloop.phien p JOIN learnloop.nguoi_dung u ON u.id = p.nguoi_dung_id "
        "WHERE p.token_bam = %s AND p.het_han > now()", (_token_hash(token),)).fetchone()
    if user is None:
        raise HTTPException(401, "Phiên đăng nhập đã hết hạn")
    return user


def admin_user(user=Depends(current_user)):
    if not user["quan_tri"]:
        raise HTTPException(403, "Chỉ quản trị viên được sửa danh mục")
    return user


def public(user):
    return {k: user[k] for k in ("id", "ten_hien_thi", "email", "so_dien_thoai", "anh_dai_dien", "quan_tri")}


def _session(conn, user):
    token = secrets.token_urlsafe(32)
    conn.execute("DELETE FROM learnloop.phien WHERE nguoi_dung_id = %s AND het_han <= now()", (user["id"],))
    conn.execute("INSERT INTO learnloop.phien VALUES (%s, %s, now() + make_interval(days => %s))",
                 (_token_hash(token), user["id"], SESSION_DAYS))
    return {"token": token, "nguoi_dung": public(user)}


class DangKy(BaseModel):
    ten_hien_thi: str = Field(min_length=1, max_length=100)
    email: str = Field(pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$", max_length=254)
    mat_khau: str = Field(min_length=8, max_length=200)


class DangNhap(BaseModel):
    email: str
    mat_khau: str


@router.post("/dang-ky", status_code=201)
def register(body: DangKy, conn=Depends(db)):
    user = conn.execute(
        "INSERT INTO learnloop.nguoi_dung (ten_hien_thi, email, mat_khau_bam) VALUES (%s, %s, %s) RETURNING *",
        (body.ten_hien_thi.strip(), body.email.strip().lower(), hash_password(body.mat_khau))).fetchone()
    return _session(conn, user)


@router.post("/dang-nhap")
def login(body: DangNhap, conn=Depends(db)):
    # shortcut: chưa giới hạn số lần thử sai; thêm rate limit trước khi mở công khai
    user = conn.execute("SELECT * FROM learnloop.nguoi_dung WHERE lower(email) = %s",
                        (body.email.strip().lower(),)).fetchone()
    if user is None or not check_password(body.mat_khau, user["mat_khau_bam"]):
        raise HTTPException(401, "Sai email hoặc mật khẩu")
    return _session(conn, user)


@router.post("/dang-xuat", status_code=204)
def logout(authorization: str = Header(default=""), conn=Depends(db)):
    token = authorization.partition(" ")[2]
    conn.execute("DELETE FROM learnloop.phien WHERE token_bam = %s", (_token_hash(token),))

