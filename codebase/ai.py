"""Nối model — chỗ DUY NHẤT trong bản chạy thử gọi model AI. NHÓM VIẾT phần gọi model thật.

Hợp đồng (giữ nguyên để khung đo được token):
    call_model(system: str, user: str) -> dict với 4 khoá
        "text":       str   chữ model trả về
        "model":      str   tên model đã gọi (để tra giá ở bảng giá model)
        "tokens_in":  int   số token vào, lấy từ trường usage trong phản hồi API — KHÔNG ước lượng
        "tokens_out": int   số token ra, gồm cả token suy luận / suy nghĩ nếu API tính riêng
    @model_call (từ tracing.py) tự ghi mỗi lần gọi vào trace; agent.py gọi call_model bao nhiêu lần
    cũng được, khung tự cộng token.
    Lỗi gọi model (hết lượt, sai key, mất mạng): cứ để exception bay ra — khung ghi lỗi vào cột error.

Chế độ giả (mặc định khi .env chưa có MODEL_PROVIDER, hoặc MODEL_PROVIDER=fake):
    trả một câu giả cố định, model "fake", token 0 — để luồng chạy hết từ trước CP2 (guide bước 3.2).
    Lượt `run.py eval` / `run.py simulate` chạy bằng model giả KHÔNG được tính.

Nối model thật: điền .env (chép từ .env.example), rồi viết nhánh gọi API ở dưới theo docs/connect-model.md
(có ví dụ OpenAI, Claude, model chạy trên máy, và cách nối nhà cung cấp khác). Không dán API key vào file này.
"""
import json
import os
import time
import urllib.error
import urllib.request

from tracing import model_call

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_env(path=os.path.join(ROOT, ".env")):
    """Đọc file .env (KEY=VALUE mỗi dòng) vào biến môi trường, không ghi đè biến đã có. Khung — không cần sửa."""
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


load_env()
MODEL_PROVIDER = (os.environ.get("MODEL_PROVIDER") or "fake").strip().lower()
MODEL_NAME = (os.environ.get("MODEL_NAME") or "").strip()
API_KEY = (os.environ.get("API_KEY") or "").strip()


@model_call
def call_model(system: str, user: str) -> dict:
    if MODEL_PROVIDER == "fake":
        last = (user.strip().splitlines() or [""])[-1]
        return {"text": "[câu trả lời giả — chưa nối model] " + last[:60], "model": "fake", "tokens_in": 0, "tokens_out": 0}

    if MODEL_PROVIDER == "gemini":
        return _gemini(system, user)
    if MODEL_PROVIDER == "openai":
        return _openai(system, user)
    raise NotImplementedError(
        "chưa viết phần gọi model thật cho MODEL_PROVIDER=%s trong codebase/ai.py — xem docs/connect-model.md"
        % MODEL_PROVIDER)


def _openai(system, user):
    api_key = (os.environ.get("OPENAI_API_KEY") or "").strip()
    if not api_key and API_KEY.startswith("sk-"):
        api_key = API_KEY
    if not api_key:
        raise RuntimeError("Thiếu key OpenAI trong OPENAI_API_KEY hoặc API_KEY.")
    body = {
        "model": MODEL_NAME,
        "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}],
        "response_format": {"type": "json_object"},
        "store": False,
    }
    req = urllib.request.Request("https://api.openai.com/v1/chat/completions",
                                 data=json.dumps(body).encode("utf-8"),
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer " + api_key})
    try:
        with urllib.request.urlopen(req, timeout=90) as response:
            data = json.load(response)
    except urllib.error.HTTPError as e:
        raise RuntimeError("OpenAI HTTP %d khi gọi %s" % (e.code, MODEL_NAME)) from None
    usage = data["usage"]
    return {
        "text": data["choices"][0]["message"]["content"] or "",
        "model": MODEL_NAME,
        "tokens_in": usage["prompt_tokens"],
        "tokens_out": usage["completion_tokens"],
    }


def _gemini(system, user):
    """Gemini generateContent qua urllib (không cần SDK). Luôn bật JSON mode: mọi bước trong agent.py đọc JSON."""
    url = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent" % MODEL_NAME
    body = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": [{"role": "user", "parts": [{"text": user}]}],
        # thinkingBudget: giảm thinking để tránh tự suy diễn/đoán bừa khi thiếu dữ kiện (AbstentionBench) và tiết kiệm tokens_out
        "generationConfig": {"temperature": 0.2, "responseMimeType": "application/json",
                             "thinkingConfig": {"thinkingBudget": 256}},
    }
    req = urllib.request.Request(url, data=json.dumps(body).encode("utf-8"),
                                 headers={"Content-Type": "application/json", "x-goog-api-key": API_KEY})
    for lan in range(3):  # 429 / 5xx / hết thời gian chờ thường chỉ tạm thời: thử lại 2 lần, nghỉ 5 s rồi 10 s
        try:
            with urllib.request.urlopen(req, timeout=90) as r:
                data = json.loads(r.read().decode("utf-8"))
            break
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504) and lan < 2:
                time.sleep(5 * (lan + 1))
                continue
            raise RuntimeError("Gemini HTTP %d: %s" % (e.code, e.read().decode("utf-8", "replace")[:300])) from None
        except (TimeoutError, urllib.error.URLError) as e:
            if lan < 2:
                time.sleep(5 * (lan + 1))
                continue
            raise RuntimeError("Gemini không phản hồi sau 3 lần: %s" % e) from None
    if not data.get("candidates"):
        raise RuntimeError("Gemini không trả câu trả lời: %s" % json.dumps(data.get("promptFeedback", data))[:300])
    parts = data["candidates"][0].get("content", {}).get("parts", [])
    u = data.get("usageMetadata", {})
    return {
        "text": "".join(p.get("text", "") for p in parts if not p.get("thought")),
        "model": MODEL_NAME,
        "tokens_in": u.get("promptTokenCount", 0),
        "tokens_out": u.get("candidatesTokenCount", 0) + u.get("thoughtsTokenCount", 0),
    }
