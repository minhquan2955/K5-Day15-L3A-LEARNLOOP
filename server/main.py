"""HTTP API bọc answer() cho app Flutter — xem docs/plan-app.md.

Chạy local: uvicorn server.main:app --reload   (đứng ở gốc repo)
"""
import os
import sys
import threading

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "codebase"))

import tracing  # noqa: E402
from agent import answer  # noqa: E402

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


_static = os.path.join(ROOT, "server", "static")
if os.path.isdir(_static):  # bản build Flutter Web (Q16); mount sau cùng để không đè /api
    app.mount("/", StaticFiles(directory=_static, html=True), name="web")
