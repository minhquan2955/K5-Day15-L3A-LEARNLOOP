# Plan — App Flutter + Backend Python (LEARNLOOP)

> Doc sống: mỗi quyết định chốt trong buổi grill được ghi vào bảng ở cuối. Người phụ trách: Đỗ Duy Bộ.

## Mục tiêu

Một giao diện demo cho lát cắt ở `spec.md` §4 (lộ trình Hà Nội 2–3 ngày), dùng cho demo trước giám khảo và người dùng thử (bonus `validation/`). Rubric chỉ chấm `python run.py` / `eval` / `simulate`, nên app **không chứa logic AI**.

## Kiến trúc

```
Flutter Web  --HTTP JSON-->  FastAPI (server/)  -->  codebase/agent.py: answer(text)
                                                       └─ tools.py, ai.py (Chinh, Ba)
```

- `run.py` giữ nguyên dòng lệnh; FastAPI chỉ bọc `answer()`.
- `answer()` trả `{"output": str, "itinerary": {...}?}`. Khung chỉ đọc `output`, nên `itinerary` không ảnh hưởng `eval`.
- App: có `itinerary` → vẽ thẻ theo ngày; không có → hiện `output` dạng markdown.

## Thư mục

- `app/` — project Flutter (web). Gói: `http`, `flutter_markdown`; state bằng `setState`, UI tiếng Việt.
- `server/main.py` — FastAPI, import `codebase/agent.py`. Không sửa file khung.

## API

| Method | Path | Body | Trả |
|---|---|---|---|
| POST | `/api/plan` | `{"text": str}` + header `X-Access-Code` | `{"output": str, "itinerary": obj \| null, "tokens": int}` |
| GET | `/api/health` | — | `{"ok": true}` |

- Không lưu session. Sửa lộ trình: app ghép "yêu cầu gốc + lộ trình trước + yêu cầu sửa" thành một `text`.
- Sai / thiếu `X-Access-Code` (so với env `ACCESS_CODE`) → 401.

### Schema `itinerary` (Chinh, Ba trả từ `answer()`)

```json
{"days":[{"day":1,"date":"2026-12-01","weather":{"mo_ta":"Mưa nhẹ","nhiet_do_thap":20,"nhiet_do_cao":24,"kha_nang_mua":70,"luong_mua_mm":3.1},
           "maps_urls":["https://www.google.com/maps/dir/?api=1&..."],
           "stops":[{"id":"lang_bac","name":"Lăng Bác","arrive":"07:30","visit_min":60,"travel_min_from_prev":0,"ticket_vnd":0,"reason":"...",
                     "maps_url":"https://www.google.com/maps/dir/?api=1&destination=..."}]}],
 "total_vnd":0,"per_person_vnd":0,"feasible":true,"notes":["..."]}
```

Mọi số lấy từ kết quả `kiem_lich_trinh`, model không ghi số.

- `date`, `weather`: chỉ có khi người dùng nói ngày đi (dự báo Open-Meteo, trong 16 ngày tới), không thì `null`. App hiện cạnh tiêu đề ngày và **bắt buộc** có link "Weather data by Open-Meteo.com" (https://open-meteo.com/) ngay cạnh, theo giấy phép CC BY 4.0.
- `stop.maps_url`: chỉ đường Google Maps từ điểm trước đến điểm này; điểm đầu ngày đi từ vị trí hiện tại của máy. `day.maps_urls`: cả ngày theo thứ tự, mỗi link tối đa 4 điểm (trình duyệt di động chỉ nhận 3 điểm dừng giữa đường), link sau nối tiếp link trước. Maps URLs không cần API key.

## Màn hình

Form: số ngày · người lớn / trẻ em · chip sở thích · ngân sách · ô ghi chú tự do → ghép thành 1 câu tiếng Việt → `/api/plan`. Kết quả: thẻ theo ngày (nếu có `itinerary`) hoặc markdown `output`. Ô "sửa lộ trình" gửi lại theo cách ghép ở trên.

## Deploy

Một service Render (free): FastAPI phục vụ `/api/*` + bản build Flutter Web tĩnh → một URL, không CORS. Env: `MODEL_PROVIDER`, `MODEL_NAME`, `API_KEY`, `ACCESS_CODE`. Build: `flutter build web` ở máy → copy `app/build/web` vào `server/static/` → commit → Render chỉ `pip install -r requirements.txt` + `uvicorn server.main:app`. Free tier ngủ (~50 s cold start) → mở app trước demo. Dự phòng: chạy local + video.

## Lệnh

```
python -m pip install -r requirements.txt
uvicorn server.main:app --reload --port 8000                      # API (+ web tĩnh nếu có server/static)
cd app && flutter run -d chrome --dart-define=API=http://localhost:8000   # dev, hot reload
cd app && flutter test                                             # test composeRequest
cd app && flutter build web && rm -rf ../server/static && cp -r build/web ../server/static   # trước khi deploy
```

Render: Build `pip install -r requirements.txt` · Start `uvicorn server.main:app --host 0.0.0.0 --port $PORT`.

## Mốc

| Hạn | Xong gì |
|---|---|
| Tối 27/11 | `server/` + `app/` chạy end-to-end với model giả |
| CP3 10:00 28/11 | App vẽ `itinerary` thật |
| CP4 14:30 28/11 | Deploy xong + video dự phòng |

## Phân việc

| Người | Phần |
|---|---|
| Đỗ Duy Bộ | App Flutter, API FastAPI, deploy |
| Phạm Trường Chinh, Nguyễn Văn Ba | `answer()`, `tools.py`, `ai.py`, khoá `itinerary` |
| Nguyễn Minh Quân | BA, góp ý giao diện |

## Môi trường

- Flutter SDK stable, chỉ bật target web (không cần Android Studio). Chạy: `flutter run -d chrome`.

## Nhật ký quyết định

| # | Quyết định | Lý do |
|---|---|---|
| Q1 | Ghi plan vào một file `docs/plan-app.md` | Hackathon 2 ngày, tách ADR là thừa |
| Q2 | Flutter chỉ là UI; logic ở Python `answer()`; `run.py` giữ CLI | Rubric chấm CLI/eval; app hỏng vẫn demo được bằng CLI/video |
| Q3 | Backend FastAPI + uvicorn | ~20 dòng, có `/docs` để test; ghi vào `requirements.txt` |
| Q4 | Flutter Web | Giám khảo mở link là dùng; build APK sau nếu cần |
| Q5 | `answer()` trả thêm `itinerary` JSON; app fallback markdown | `kiem_lich_trinh` đã có số có cấu trúc |
| Q6 | Bộ làm cả Flutter lẫn backend; Chinh + Ba giữ lõi AI | Bộ dựng base dự án |
| Q7 | Cài Flutter SDK trên máy (web only) | Cần hot reload; CI build để sau cho deploy |
| Q8 | `app/` + `server/` ở gốc repo | Không đụng khung |
| Q9 | Stateless, app ghép text khi sửa | Giữ hợp đồng `answer(text)` |
| Q10 | Form có cấu trúc + ô ghi chú tự do | Ít thiếu thông tin; vẫn demo được câu lạ |
| Q11 | 2 endpoint: `POST /api/plan`, `GET /api/health` | Đủ cho lát cắt |
| Q12 | Schema `itinerary` như trên | Số chỉ từ `kiem_lich_trinh` |
| Q13 | Một service Render, FastAPI phục vụ cả web tĩnh | Một URL, không CORS |
| Q14 | Mã truy cập qua env `ACCESS_CODE` + header | URL công khai, chặn đốt tiền API |
| Q15 | Mốc: tối nay giả → CP3 itinerary thật → CP4 deploy + video | Khớp checkpoint |
| Q17 | Bộ viết luôn lõi AI theo spec §4 (`tools.py`, `agent.py`), Gemini qua urllib; Chinh + Ba kế thừa, chỉnh prompt / eval | Cần bản chạy thử ngay; lõi còn trống. `thoi_gian_di` nhận danh sách id, trả mọi cặp (một lần gọi thay vì N²) |
| Q16 | `flutter build web` trên máy → commit vào `server/static/`; Render chỉ cài Python | Nhanh, chắc; Docker Flutter dễ timeout gói free |
