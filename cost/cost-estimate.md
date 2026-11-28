# Chi phí khi dùng thật

> Điền ở guide bước 4.2, nộp ở CP4 14:30 Thứ Bảy 28/11. Ôn lại: ngày 13, ngày 1, ngày 14 · lab ngày 13, lab ngày 14. Chấm ở rubric R6.
> Số **không điền tay**: điền `cost/personas.yaml` → `python run.py simulate` → chép bảng trong `cost/simulate-N-summary.md` vào đây.
> Lúc build dùng gói miễn phí vẫn tính theo **giá gói trả phí** — đây là chi phí cho lúc đưa vào dùng thật.

## 1. Đầu vào

- **Persona** (`cost/personas.yaml`): 3 kiểu (`dung_it` 50% · 1 phiên/tháng · 1 lượt; `dung_vua` 35% · 2 phiên/tháng · 2 lượt; `dung_nhieu` 15% · 4 phiên/tháng · 3 lượt). Nguồn: khảo sát `n=26` (`evidence/summary.md`: 20/26 gặp trục trặc phải đổi lịch, 11/26 mất ≥1 giờ chuẩn bị) kết hợp *(tự ước tính)*.
- **Số người dùng thật** 3 kịch bản: thấp `1.000` · cơ sở `5.000` · cao `15.000` người/tháng. Nguồn: Sở Du lịch Hà Nội / VietnamPlus ghi nhận trên 25,88 triệu lượt khách nội địa đến Hà Nội năm 2025 (~2,15 triệu lượt/tháng); 3 kịch bản tương ứng tỷ lệ tiếp cận 0,05%–0,7% *(tự ước tính)*.
- **Giá** 2 mức model (`https://ai.google.dev/gemini-api/docs/pricing`, xem 28/11/2026):
  - `gemini-3.1-flash-lite`: vào `$0,25` · ra `$1,50` / 1M token
  - `gemini-2.5-flash`: vào `$0,30` · ra `$2,50` / 1M token
- **Tỉ lệ đạt** dùng để tính: `22/24 (92%)` — lượt `run-2@20261128-022833` (`--rate-from eval/run-2.csv`, chạy trên `gemini-2.5-flash`)
- Đo token trên model `gemini-2.5-flash`, tính giá trên cả `gemini-2.5-flash` và `gemini-3.1-flash-lite` (đo trên `gemini-2.5-flash`, quy đổi giá `gemini-3.1-flash-lite`).

## 2. Kết quả mô phỏng

Lượt mô phỏng: `cost/simulate-1.csv` · run ID `simulate-1@20261128-111040` · `50` phiên (`0/50` lỗi) · seed `42`

| Persona | Số phiên mô phỏng | Lượt hỏi / phiên | Token vào / phiên | Token ra / phiên | Gọi model / phiên | Gọi công cụ / phiên |
|---|---:|---:|---:|---:|---:|---:|
| dung_it | 21 | 1 | 5403 | 1324 | 2.2 | 4.8 |
| dung_vua | 21 | 2 | 9579 | 2366 | 4.0 | 8.2 |
| dung_nhieu | 8 | 3 | 11894 | 3140 | 5.6 | 11.0 |

| Model (giá) | Chi phí / phiên | Chi phí / task thành công | Chi phí / câu hỏi đạt | Chi phí / tháng — thấp (1.000 người) | Chi phí / tháng — cơ sở (5.000 người) | Chi phí / tháng — cao (15.000 người) | Chi phí / người / tháng (cơ sở) |
|---|---:|---:|---:|---:|---:|---:|---:|
| gemini-3.1-flash-lite (vào 0.25 · ra 1.5 $/1M) *(đo trên gemini-2.5-flash, tính giá model này)* | $0.0051 (≈ 131 ₫) | $0.0056 (≈ 143 ₫) | $0.0032 (≈ 82 ₫) | $10.44 (≈ 266.229 ₫) | $52.20 (≈ 1.331.147 ₫) | $156.61 (≈ 3.993.440 ₫) | $0.0104 (≈ 266 ₫) |
| gemini-2.5-flash (vào 0.3 · ra 2.5 $/1M) | $0.0076 (≈ 194 ₫) | $0.0083 (≈ 211 ₫) | $0.0048 (≈ 121 ₫) | $15.47 (≈ 394.498 ₫) | $77.35 (≈ 1.972.488 ₫) | $232.06 (≈ 5.917.464 ₫) | $0.0155 (≈ 394 ₫) |

Chi phí / task thành công = chi phí trung bình mỗi phiên ÷ tỉ lệ đạt (`92%`) — **không coi như đạt 100%**. Tỷ giá tham khảo: `1 USD = 25.500 ₫` *(tự ước tính làm tròn)*.

## 3. So với impact

- Impact / người / tháng (`spec.md` §2): ít nhất **12,5 phút chuẩn bị/người/tháng** (từ mẫu Hà Nội `S02` 1–2 giờ và `S14` >4 giờ).
- Chi phí / người / tháng (cơ sở, model `gemini-2.5-flash`): **`$0.0155` (≈ 394 ₫)** (hoặc **`$0.0104` ≈ 266 ₫** ở mức giá `gemini-3.1-flash-lite`).
- **Kết luận một dòng — đáng làm không:** **Đáng làm** — chỉ tốn khoảng **394 ₫/người/tháng** (`211 ₫/task thành công`) để tiết kiệm ít nhất 12,5 phút chuẩn bị và giảm lỗi sai giờ/giá; ngay cả ở quy mô cơ sở 5.000 người/tháng tổng tiền model chỉ dưới 2 triệu đồng.

## 4. *(Muốn sâu hơn, không bắt buộc)*

- Lưu ý kỹ thuật: lượt mô phỏng `simulate-1` chạy trên nhánh đã tích hợp 24 điểm POI + RAG `tra_cuu_rag`, nên trung bình `tokens_in` (~5.400–11.900/phiên) cao hơn lượt `run-2`; rút gọn bớt mô tả ứng viên gửi model hoặc dùng `gemini-3.1-flash-lite` giúp giảm ngay ~32% chi phí model.
- API bổ trợ (`Open-Meteo`, `Nominatim`) đang miễn phí phi thương mại; đưa ra quy mô thương mại thật cần thêm chi phí máy chủ FastAPI/PostgreSQL và dịch vụ bản đồ/geocoding riêng.
