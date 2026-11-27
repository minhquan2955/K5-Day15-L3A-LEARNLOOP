# Báo cáo đánh giá — lượt 1 → một cải tiến → lượt 2

> Điền ở guide bước 4.1. Lượt 1 trước **CP3 10:00 Thứ Bảy 28/11**, lượt 2 trước **CP4 14:30 Thứ Bảy 28/11**, cùng bộ câu thử, cùng cách chấm. Chấm ở rubric R5.
> Số lấy từ `python run.py score eval/run-1.csv` (và `run-2.csv`) sau khi điền cột `pass`. **Kết quả thấp ghi thật vẫn đủ điểm.**
> Không được: sửa chuẩn "đạt", bỏ câu thử trượt, sửa `expected` cho khớp output, sửa kết quả lượt đã chạy.

## 1. Kết quả

| Lượt | Run ID | Đạt / tổng | % | thuong | kho | tu_choi | So với chuẩn "đạt" |
|---|---|---|---|---|---|---|---|
| 1 | `run-1@20261128-014438` | 17/24 | 71% | 5/6 (83%) | 9/14 (64%) | 3/4 (75%) | chưa |
| 2 | `run-2@20261128-022833` | 22/24 | 92% | 5/6 (83%) | 13/14 (93%) | 4/4 (100%) | đạt |
| 3 | `run-3@20261128-052811` | lỗi kỹ thuật 5/24 (429, timeout) — không chấm | | | | | |
| 4 | `run-4@20261128-053502` | 21/24 | 88% | 5/6 (83%) | 12/14 (86%) | 4/4 (100%) | đạt |

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

- Nhắm vào nhóm lỗi: 3 nhóm lỗi ở Lượt 1 (`SYSTEM_DOC` đọc sai số người / dừng sớm / thiếu từ chối kép `B15, B20, B24`; `SYSTEM_XEP` thiếu hoặc rỗng ngày và chưa cắt điểm vượt ngân sách `B05, B18, B23`; tự ước số phút bỏ điểm `B03`) — vì sao là nhóm **đau nhất với người dùng**: tính sai tiền vé cả nhóm, không đưa ra được phương án vừa ngân sách/đủ ngày, tự ước phút đi, hoặc bỏ sót từ chối ngoài phạm vi (đặt phòng).
- Đã sửa gì (nâng cấp **LEARNLOOP v2** ở `codebase/agent.py` và `codebase/ai.py`, tham khảo bộ 26 paper):
  1. Đảo thứ tự key JSON (*Reason-before-Answer/Plan*): đưa các trường bóc tách/phân tích lên trước `"trang_thai"` và `"ngay"`.
  2. Tách thuần *Distillation* ở bước 1 + 3 ví dụ *mini-TTS* (`1 + N` người, ngoài phạm vi + đặt phòng, tránh chỗ đông) và liệt kê rõ danh mục `thieu_du_lieu` (*AbstentionBench* Appendix D.5).
  3. Đặt `VI_PHAM_CAN_SUA_NGAY` ở **ĐẦU** prompt vòng sửa (*Theorem R.1* của *ReActXen*) kèm hướng cắt điểm `gia_ve > 0` khi vượt ngân sách.
  4. Bổ sung **Code Policy Gates** trong `answer()`: cấm dừng `hoi_lai` khi đã có `so_ngay` + `diem_muon_di`, vẫn in đủ `tu_choi_them` ở nhánh `ngoai_pham_vi`, kiểm đủ `so_ngay` không để ngày trống, cảnh báo khi `tranh` lọc hết 1 sở thích, lọc delimiter giả kiểu *StruQ*, và gắn số phút/giờ thật từ `thoi_gian_di` cho điểm bị bỏ trong `_dung_output`.
  5. Hạ `thinkingBudget` từ `1024 → 256` trong `codebase/ai.py` (giảm `tokens_out` TB từ `2.067 → 876`, `-57,6%`, giảm suy diễn thừa khi thiếu dữ kiện).
- Kết quả: 6/7 câu trượt Lượt 1 đã qua (`B03, B05, B18, B20, B23, B24`: `0/6 → 6/6`; riêng `B15` đã sửa đúng `3` người nhưng lộ bug khớp chuỗi con ở `tim_diem`) · tổng **`71% (17/24) → 92% (22/24)`**, `kho` `64% → 93%`, `tu_choi` `75% → 100% (4/4)` → **đạt chuẩn §7**.
- Câu nào **tệ đi** sau khi sửa: **`B22`** (`1 → 0`) — khi tắt việc tự sinh sở thích thừa ở bước 1 lúc người dùng nêu sẵn tên điểm, `tim_diem` trong `codebase/tools.py` bị khớp chuỗi con (`"hồ gươm"` nằm trong `"phố đi bộ hồ gươm"` nên khớp nhầm `ho_guom` trước `pho_di_bo`), làm cả `B15` và `B22` thiếu `Phố đi bộ Hồ Gươm` sau `19:00`.

### Lượt 3 → 4 (sau lượt 2, trước CP4)

- Thay đổi so với lượt 2: thêm thời tiết + link Google Maps, kiểm lý do bằng code, gợi ý lấp khoảng trống, làm tròn taxi (`spec.md` §10). **Đổi cả model** từ `gemini-2.5-flash` sang `gemini-3.1-flash-lite` vì key mới không còn được dùng model cũ, nên **không tách được** phần chênh do code hay do model.
- Lượt 3 bị lỗi kỹ thuật 5/24 (4 câu HTTP 429 vượt hạn mức gói miễn phí, 1 câu timeout) → giữ nguyên file, chạy lại thành lượt 4 với `--wait 5`.
- Lượt 4: `21/24 (88%)`, vẫn đạt chuẩn §7. So với lượt 2 (`22/24`): `B05` **tệ đi** (`1 → 0`) — báo đúng vượt `20.000đ/người` nhưng không đưa phương án vừa ngân sách; `B15, B22` vẫn trượt vì lỗi khớp tên trong `tim_diem`. Các câu còn lại giữ nguyên đạt.
- Chấm lượt 4: Claude (coding agent) chấm theo `pass_criterion` + `metric_spec.yaml`, ghi lý do câu trượt trong `ghi_chu`; **cần người trong nhóm duyệt lại** (xem `docs/ai-usage.md`).

## 4. Còn lại

- Lỗi chưa sửa + nguy hiểm thế nào: bug khớp chuỗi con tên điểm lồng nhau trong `tim_diem` (`B15, B22`, mức độ vừa — người dùng đọc thấy ngay điểm bị đổi tên và có thể sửa lại, không có số liệu bịa); ở `B21`, lưu ý báo chung thiếu dữ liệu quán ăn cụ thể thay vì lặp lại tên riêng hai quán.
- Nếu có thêm 1 tuần: sửa `tim_diem` ưu tiên khớp chính xác hoặc chuỗi dài nhất để dứt điểm `B15, B22`; mở rộng dữ liệu điểm Hà Nội và lịch nghỉ theo thứ; đo độ ổn định nhiều lượt (`pass^k`) và nối lưu lịch trình vào PostgreSQL (`db/`).
