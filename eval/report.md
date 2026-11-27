# Báo cáo đánh giá — lượt 1 → một cải tiến → lượt 2

> Điền ở guide bước 4.1. Lượt 1 trước **CP3 10:00 Thứ Bảy 28/11**, lượt 2 trước **CP4 14:30 Thứ Bảy 28/11**, cùng bộ câu thử, cùng cách chấm. Chấm ở rubric R5.
> Số lấy từ `python run.py score eval/run-1.csv` (và `run-2.csv`) sau khi điền cột `pass`. **Kết quả thấp ghi thật vẫn đủ điểm.**
> Không được: sửa chuẩn "đạt", bỏ câu thử trượt, sửa `expected` cho khớp output, sửa kết quả lượt đã chạy.

## 1. Kết quả

| Lượt | Run ID | Đạt / tổng | % | thuong | kho | tu_choi | So với chuẩn "đạt" |
|---|---|---|---|---|---|---|---|
| 1 | `run-1@20261128-014438` | 17/24 | 71% | 5/6 (83%) | 9/14 (64%) | 3/4 (75%) | chưa |
| 2 | | __/__ | | __/__ | __/__ | __/__ | đạt / chưa |

Kết quả từng câu: `eval/run-1.csv`, `eval/run-2.csv`. Trace: `traces/run-1.jsonl`, `traces/run-2.jsonl`.

## 2. Lỗi lượt 1 — gom thành nhóm có tên

| Nhóm lỗi | Số câu | Câu |
|---|---|---|
| Bước 1 (`SYSTEM_DOC`) đọc sai số người / dừng sớm không gọi công cụ / thiếu phân tách yêu cầu ngoài phạm vi | 3 | `B15, B20, B24` |
| Bước 2 (`SYSTEM_XEP`) xếp thiếu ngày / bỏ qua ràng buộc đặc thù (ngân sách, ngoại thành) | 3 | `B05, B18, B23` |
| Tự ước số liệu thời gian trong lý do bỏ điểm, chưa nêu gợi ý nới | 1 | `B03` |

**≥3 lỗi cụ thể:**

| Câu | Input | Output | Vì sao sai |
|---|---|---|---|
| `B05` | "1 ngày ở Hà Nội, 4 người, muốn đi Hoàng thành, Văn Miếu, Hồ Gươm, Hỏa Lò, Bảo tàng Dân tộc học. Ngân sách vé 150k/người." | Báo `KHÔNG XẾP ĐƯỢC: vượt ngân sách 150000đ/người 20000đ` (tổng vé `170.000đ/người`), lý do Hồ Gươm viết `"miễn phí vé vào hồ"` | Sau 2 vòng sửa vẫn không cắt bớt điểm có vé để đưa ra phương án vừa `150k/người`, và câu lý do tự ghi nhầm vé Hồ Gươm |
| `B15` | "Mình có sẵn danh sách muốn đi ở Hà Nội trong 2 ngày với 2 bạn..." | Tính vé Hoàng thành `140,000đ` (`2` người lớn × `70k`) | Hiểu nhầm `"Mình ... với 2 bạn"` thành `2` người thay vì `3` người |
| `B18` | "Nhóm mình 4 bạn đi Hà Nội 3 ngày 2 đêm đúng dịp nghỉ lễ..." | Chỉ xuất `Ngày 1` và `Ngày 2`, không nói dữ liệu thiếu thông tin độ đông | Xếp thiếu 1 ngày so với input 3 ngày, chưa cảnh báo thiếu dữ liệu độ đông |
| `B20` | "Nhóm 3 bạn chỉ có 1 ngày ở Hà Nội từ 8h sáng, muốn đi hết Bát Tràng, Bảo tàng Dân tộc học, Chùa Hương và Văn Miếu..." | Dừng ngay ở bước 1 (`tool_calls = 0`) với câu hỏi chung | Không gọi `thoi_gian_di` / `kiem_lich_trinh` nên không có số liệu vi phạm cụ thể từ công cụ |

## 3. Một lần cải tiến

- Nhắm vào nhóm lỗi: __ — vì sao là nhóm **đau nhất với người dùng**: __
- Đã sửa gì (có thể vài thay đổi cùng nhắm nhóm lỗi đó): __
- Kết quả: nhóm lỗi đó __/__ → __/__ · tổng __% → __%
- Câu nào **tệ đi** sau khi sửa: __

## 4. Còn lại

- Lỗi chưa sửa + nguy hiểm thế nào: __
- Nếu có thêm 1 tuần: __
