# Tóm tắt mô phỏng simulate-1@20261128-111040

Do `python run.py simulate` sinh ra — không sửa tay. Chép bảng sang `cost/cost-estimate.md`.

| Persona | Số phiên mô phỏng | Lượt hỏi / phiên | Token vào / phiên | Token ra / phiên | Gọi model / phiên | Gọi công cụ / phiên |
|---|---:|---:|---:|---:|---:|---:|
| dung_it | 21 | 1 | 5403 | 1324 | 2.2 | 4.8 |
| dung_vua | 21 | 2 | 9579 | 2366 | 4.0 | 8.2 |
| dung_nhieu | 8 | 3 | 11894 | 3140 | 5.6 | 11.0 |

Tỉ lệ đạt dùng để tính: 22/24 (92%) — lượt run-2@20261128-022833

- Tỉ lệ đạt lấy từ lượt nhóm chọn: eval/run-2.csv (--rate-from).

| Model (giá) | Chi phí / phiên | Chi phí / task thành công | Chi phí / câu hỏi đạt | Chi phí / tháng — thấp (1.000 người) | Chi phí / tháng — cơ sở (5.000 người) | Chi phí / tháng — cao (15.000 người) | Chi phí / người / tháng (cơ sở) |
|---|---:|---:|---:|---:|---:|---:|---:|
| gemini-3.1-flash-lite (vào 0.25 · ra 1.5 $/1M) | $0.0051 (≈ 131 ₫) | $0.0056 (≈ 143 ₫) | $0.0032 (≈ 82 ₫) | $10.44 (≈ 266.229 ₫) | $52.20 (≈ 1.331.147 ₫) | $156.61 (≈ 3.993.440 ₫) | $0.0104 (≈ 266 ₫) |
| gemini-2.5-flash (vào 0.3 · ra 2.5 $/1M) | $0.0076 (≈ 194 ₫) | $0.0083 (≈ 211 ₫) | $0.0048 (≈ 121 ₫) | $15.47 (≈ 394.498 ₫) | $77.35 (≈ 1.972.488 ₫) | $232.06 (≈ 5.917.464 ₫) | $0.0155 (≈ 394 ₫) |

- Chi phí / task thành công = chi phí / phiên ÷ tỉ lệ đạt. Chi phí / câu hỏi đạt = chi phí / phiên ÷ số lượt hỏi trung bình mỗi phiên (1.7) ÷ tỉ lệ đạt — tỉ lệ đạt đo theo từng câu thử.
- Token đo trên model: gemini-2.5-flash. Giá tính theo từng model trong bảng — model khác bộ tách token thì số token thật có thể lệch; ghi rõ "đo trên model X, tính giá model Y" trong cost/cost-estimate.md.
- Phiên lỗi (không tính vào trung bình): 0/50.
- Tỷ giá: 1 USD = 25.500 ₫ (tỷ giá tham khảo USD/VND ngày 28/11/2026 (tự ước tính làm tròn)).
