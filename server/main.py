"""HTTP API bọc answer() cho app Flutter — xem docs/plan-app.md.
Lưu chuyến / check-in / sự kiện thao tác (P0): server/luu_tru.py, bật khi có DATABASE_URL; không có thì 503.

Chạy local: uvicorn server.main:app --reload   (đứng ở gốc repo)
"""
import os
import sys
import threading

from typing import Optional

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "codebase"))

import tracing  # noqa: E402
from server import crud  # noqa: E402
from agent import answer  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luu_tru  # noqa: E402

ACCESS_CODE = os.environ.get("ACCESS_CODE", "")
# shortcut: tracing dùng biến toàn cục nên khoá để mỗi lúc một request; đủ cho demo, tách trace theo request nếu cần chạy song song
_lock = threading.Lock()

app = FastAPI(title="LEARNLOOP API")
# chỉ cho `flutter run -d chrome` (cổng ngẫu nhiên) gọi khi dev; bản deploy cùng origin nên không cần
app.add_middleware(CORSMiddleware, allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+",
                   allow_methods=["*"], allow_headers=["*"])


class PlanIn(BaseModel):
    text: str


@app.get("/api/health")
def health():
    return {"ok": True}


@app.post("/api/plan")
def plan(body: PlanIn, x_access_code: str = Header(default="")):
    if ACCESS_CODE and x_access_code != ACCESS_CODE:
        raise HTTPException(401, "Sai mã truy cập")
    text = body.text.strip()
    if not text or len(text) > 4000:
        raise HTTPException(400, "text rỗng hoặc dài quá 4000 ký tự")
    with _lock:
        tracing.begin("api")
        try:
            result = answer(text)
        except Exception as e:
            tracing.end()
            raise HTTPException(502, "%s: %s" % (type(e).__name__, e))
        s, _ = tracing.end()
    return {
        "output": result.get("output", ""),
        "itinerary": result.get("itinerary"),
        "tokens": s["tokens_in"] + s["tokens_out"],
    }


# ---------- Lưu trữ P0: người dùng ẩn danh, chuyến đi, check-in, sự kiện thao tác ----------

def _kiem_ma(x_access_code):
    if ACCESS_CODE and x_access_code != ACCESS_CODE:
        raise HTTPException(401, "Sai mã truy cập")


def _goi(ham, *args):
    try:
        return ham(*args)
    except luu_tru.BatTat as e:
        raise HTTPException(503, "Chưa bật lưu trữ: %s" % e)
    except luu_tru.SaiDuLieu as e:
        raise HTTPException(400, str(e))


class NguoiDungIn(BaseModel):
    nguoi_dung: str
    dong_y: bool = False


class SuKienIn(BaseModel):
    nguoi_dung: str
    su_kien: list


class ChuyenDiIn(BaseModel):
    nguoi_dung: str
    ten: str = ""
    itinerary: dict
    ngay_bat_dau: Optional[str] = None


class CheckInIn(BaseModel):
    nguoi_dung: str
    ngay_thu: int
    thu_tu: int
    xong: bool = True


@app.get("/api/luu-tru")
def luu_tru_bat():
    return {"bat": luu_tru.bat()}


@app.post("/api/nguoi-dung")
def nguoi_dung(body: NguoiDungIn, x_access_code: str = Header(default="")):
    _kiem_ma(x_access_code)
    return _goi(luu_tru.dang_ky, body.nguoi_dung, body.dong_y)


@app.delete("/api/nguoi-dung/{nguoi_dung}")
def xoa_nguoi_dung(nguoi_dung: str, x_access_code: str = Header(default="")):
    _kiem_ma(x_access_code)
    return _goi(luu_tru.xoa_nguoi_dung, nguoi_dung)


@app.post("/api/su-kien")
def su_kien(body: SuKienIn, x_access_code: str = Header(default="")):
    _kiem_ma(x_access_code)
    return _goi(luu_tru.ghi_su_kien, body.nguoi_dung, body.su_kien)


@app.post("/api/chuyen-di")
def luu_chuyen(body: ChuyenDiIn, x_access_code: str = Header(default="")):
    _kiem_ma(x_access_code)
    return _goi(luu_tru.luu_chuyen, body.nguoi_dung, body.ten, body.itinerary, body.ngay_bat_dau)


@app.get("/api/chuyen-di")
def danh_sach_chuyen(nguoi_dung: str, x_access_code: str = Header(default="")):
    _kiem_ma(x_access_code)
    return _goi(luu_tru.danh_sach_chuyen, nguoi_dung)


@app.post("/api/chuyen-di/{chuyen_di}/xong")
def check_in(chuyen_di: str, body: CheckInIn, x_access_code: str = Header(default="")):
    _kiem_ma(x_access_code)
    return _goi(luu_tru.check_in, body.nguoi_dung, chuyen_di, body.ngay_thu, body.thu_tu, body.xong)


@app.delete("/api/chuyen-di/{chuyen_di}")
def xoa_chuyen(chuyen_di: str, nguoi_dung: str, x_access_code: str = Header(default="")):
    _kiem_ma(x_access_code)
    return _goi(luu_tru.xoa_chuyen, nguoi_dung, chuyen_di)


# Cài sau route P0: /api/chuyen-di của luu_tru (main) thắng crud.py cùng đường dẫn.
crud.install(app)

_static = os.path.join(ROOT, "server", "static")
if os.path.isdir(_static):  # bản build Flutter Web (Q16); mount sau cùng để không đè /api
    app.mount("/", StaticFiles(directory=_static, html=True), name="web")
