"""Nạp dữ liệu tri thức cục bộ (data/hanoi_rag.json) vào bảng learnloop.rag_doan (pgvector 768 chiều).

Chạy từ thư mục gốc (khi PostgreSQL `--profile database` đã chạy và .env có DATABASE_URL + API_KEY):
    python3 db/nap_rag.py
"""
import json
import os
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "codebase"))

from ai import load_env  # noqa: E402
import tools  # noqa: E402


def main():
    load_env()
    db_url = (os.environ.get("DATABASE_URL") or "").strip()
    if not db_url:
        raise SystemExit("Thiếu DATABASE_URL trong môi trường hoặc .env")
    try:
        import pg8000.native as pg
    except ImportError:
        raise SystemExit("Chưa cài pg8000 (chạy: pip install pg8000)")

    rag_path = os.path.join(ROOT, "data", "hanoi_rag.json")
    with open(rag_path, encoding="utf-8") as f:
        data = json.load(f)
    doan = data.get("doan") or []
    if not doan:
        raise SystemExit("data/hanoi_rag.json không có đoạn nào để nạp")

    model_name = (os.environ.get("EMBEDDING_MODEL") or tools._EMBED_MODEL_DEFAULT).strip()
    u = urllib.parse.urlparse(db_url)
    con = pg.Connection(
        user=urllib.parse.unquote(u.username or ""),
        password=urllib.parse.unquote(u.password or ""),
        host=u.hostname or "localhost",
        port=u.port or 5432,
        database=(u.path or "/").lstrip("/"),
        timeout=10,
    )
    sql = """
        INSERT INTO learnloop.rag_doan (nguon, tieu_de, thu_tu, noi_dung, dia_diem_id, embedding_model, embedding)
        VALUES (:nguon, :tieu_de, :thu_tu, :noi_dung, :dia_diem_id, :model, CAST(:embedding AS public.vector))
        ON CONFLICT (embedding_model, nguon, thu_tu) DO UPDATE SET
            tieu_de = EXCLUDED.tieu_de,
            noi_dung = EXCLUDED.noi_dung,
            dia_diem_id = EXCLUDED.dia_diem_id,
            embedding = EXCLUDED.embedding
    """
    try:
        for d in doan:
            van_ban = "%s. %s" % (d["tieu_de"], d["noi_dung"])
            vec = tools._nhung_van_ban(van_ban)
            vec_str = "[" + ",".join(str(float(x)) for x in vec) + "]"
            con.run(
                sql,
                nguon=d["nguon"],
                tieu_de=d["tieu_de"],
                thu_tu=int(d["thu_tu"]),
                noi_dung=d["noi_dung"],
                dia_diem_id=d.get("dia_diem_id"),
                model=model_name,
                embedding=vec_str,
            )
            print("Đã nạp [%d] %s (%s)" % (d["thu_tu"], d["tieu_de"], d.get("dia_diem_id") or "chung"))
    finally:
        con.close()
    print("Hoàn tất nạp %d đoạn vào learnloop.rag_doan (%s)" % (len(doan), model_name))


if __name__ == "__main__":
    main()
