"""Kết nối PostgreSQL cho mỗi request và đổi lỗi ràng buộc DB thành HTTP 400/409."""
import os

import psycopg
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from psycopg import errors
from psycopg.rows import dict_row

DATABASE_URL = os.environ.get("DATABASE_URL", "")


def db():
    if not DATABASE_URL:
        raise HTTPException(503, "Chưa cấu hình DATABASE_URL")
    # shortcut: mở một kết nối mỗi request, đủ cho demo; dùng psycopg_pool nếu tải cao
    try:
        conn = psycopg.connect(DATABASE_URL, row_factory=dict_row)
    except psycopg.OperationalError as e:
        raise HTTPException(503, "Không kết nối được PostgreSQL: %s" % e)
    with conn:  # commit khi xong, rollback khi lỗi
        yield conn


def install_errors(app: FastAPI):
    @app.exception_handler(errors.UniqueViolation)
    def _dup(_: Request, e: Exception):
        return JSONResponse({"detail": "Đã tồn tại: %s" % e.diag.message_detail}, status_code=409)

    @app.exception_handler(errors.IntegrityError)
    def _bad(_: Request, e: Exception):
        return JSONResponse({"detail": "Dữ liệu không hợp lệ: %s" % e.diag.message_primary}, status_code=400)
