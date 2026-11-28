FROM python:3.14-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt

COPY codebase/agent.py codebase/ai.py codebase/tools.py codebase/tracing.py ./codebase/
COPY data/hanoi_poi.json ./data/
COPY server/main.py server/crud.py server/auth.py server/database.py server/luu_tru.py ./server/
COPY server/static/ ./server/static/

USER 10001:10001
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s \
    CMD ["python", "-c", "from urllib.request import urlopen; urlopen('http://127.0.0.1:8000/api/health', timeout=2).close()"]

CMD ["python", "-m", "uvicorn", "server.main:app", "--host", "0.0.0.0", "--port", "8000"]
