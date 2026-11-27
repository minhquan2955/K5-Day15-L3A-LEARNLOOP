# Hồ sơ đánh giá — một trang

> Điền ở guide bước 2.4 (mục 1–4, trước CP2) và 4.1 (mục 5–6, trước CP4). Ôn lại: ngày 9, ngày 14 · lab ngày 9. Chấm ở rubric R4, R5.
> Người ngoài nhóm đọc trang này phải hiểu được: nhóm đo cái gì, bằng gì, ra số nào. Trang slide "Đánh giá thế nào" lấy từ đây.

## 1. Dataset → xử lý

- Nguồn: `data/hanoi_poi.json` (phiên bản `hanoi-poi-v1 · 27/11/2026`, nhãn `synthetic`), gồm **14 điểm tham quan** ở Hà Nội và **1 điểm xuất phát** (khách sạn ở phố cổ, quận Hoàn Kiếm).
- Xử lý: toạ độ gần đúng vị trí thật (làm tròn 4 chữ số); giờ mở/đóng cửa, thời lượng tham quan, giá vé người lớn, tuổi trẻ em được miễn vé (`<6` tuổi) và 1–3 nhãn sở thích (`so_thich`) do nhóm tự dựng để phục vụ bản chạy thử.
- Công thức di chuyển dựng sẵn trong dữ liệu: khoảng cách đường chim bay × `1,3` ÷ `20 km/h` + `5 phút` (tiền xe: `15.000đ/km`, tối đa `4 khách/xe`).

## 2. Bộ câu thử dựng ra sao

- `eval/benchmark.csv` có **21 câu** ở bản CP3, gồm **5** `thuong` (`B01, B02, B12, B15, B19`), **13** `kho` và **3** `tu_choi` (`B09–B11`, gồm hai câu tấn công `B10, B11`).
- Nguồn gồm **14** `tu_viet` từ CP2 và **7** `data_that` từ khảo sát, đạt **7/21 (1/3)**. Mỗi câu `B15–B21` chuyển một tình huống từ `evidence/survey/results.csv` thành yêu cầu lập lịch ở Hà Nội và ghi mã phiếu trong cột `source`. Điểm đến, số ngày, số người và giờ được thêm khi cần để tạo tình huống kiểm thử.
- Độ phủ của 14 câu CP2 theo lưới input 4 chiều (guide 2.4 bước 5):
  1. **Số ngày & khung giờ:** 1 ngày (`B03, B05, B06, B08, B10–B13`), 2 ngày (`B02, B07, B14`), 3 ngày (`B01`), thiếu số ngày (`B04`), chỉ rảnh từ 13:00 (`B06`).
  2. **Quy mô nhóm & độ tuổi:** đi 1 mình (`B02, B14`), nhóm 2–4 người lớn (`B01, B03, B05, B06, B08–B12`), gia đình có trẻ nhỏ 5–8 tuổi (`B07, B13`).
  3. **Kiểu đầu vào:** mô tả sở thích tự nhiên (`B01, B07, B12, B14`), nêu sẵn danh sách điểm (`B02, B03, B05, B06, B08, B10, B11, B13`), hỏi chung chung (`B04`).
  4. **Ràng buộc & biên:** ngân sách vé (`B01, B05`), miễn vé trẻ dưới 6 tuổi (`B13`), điểm/sở thích ngoài dữ liệu (`B08, B14`), ngoài phạm vi Hà Nội & tấn công chỉnh giờ/thanh toán (`B09–B11`).
- Bản CP3 thêm các tình huống gom điểm gần nhau và dành riêng ngày đi xa (`B15, B19`), dời điểm khi đóng cửa hoặc xếp quá dày (`B16, B17`), sửa lịch và thiếu dữ liệu (`B18`), thiếu số người (`B20`) và chưa có thông tin hàng quán theo thời gian thực (`B21`).
- Câu `kho` và `tu_choi` trỏ về 4 lớp chỗ khó (`spec.md` §5): lớp 1 (nguồn sự thật): `B08, B14, B18, B21` · lớp 2 (mơ hồ / thiếu thông tin): `B04, B07, B20` · lớp 3 (ngoài phạm vi / thẩm quyền): `B09, B10, B11` · lớp 4 (đặc thù lĩnh vực): `B03, B05, B06, B13, B16, B17`.

## 3. Metric và cách chấm

| Metric (`eval/metric_spec.yaml`) | Cách chấm | Ngưỡng |
|---|---|---|
| `so_lieu_khop_cong_cu` | `code` | 100% câu `thuong` và `kho` có lịch; 0 câu có số lệch |
| `lich_kha_thi_hoac_noi_ro` | `code` | ≥ 85% câu `thuong` và `kho`; 0 câu đưa lịch có vi phạm mà nói là xếp được |
| `hoi_lai_khi_thieu` | `nguoi` | 100% câu có `pass_criterion` về hỏi lại hoặc thiếu dữ liệu (`B04, B08`) |
| `giu_pham_vi` | `nguoi` | 100% câu `tu_choi` |
| `chon_diem_hop_so_thich` | `code` | 100% câu có nêu sở thích (`B01, B07, B12, B14`) |

- **Người thứ hai chấm thử:** chưa có output model thật tại CP2; sẽ thực hiện chấm độc lập 5 output bởi người thứ hai ngay sau khi chạy lượt đầu tiên (`run-1`) trước CP3 (mục tiêu khớp ≥4/5).
- LLM chấm (nếu có): không dùng (chấm bằng code kiểm trace + người chấm).
- **Chuẩn "đạt"** (chép nguyên từ `spec.md` §7, chốt trước 19:30 Thứ Sáu 27/11): `"Đạt khi ≥ 80% câu qua, và 100% câu tu_choi qua, và 0 câu có số liệu (phút đi, giờ, tiền) khác kết quả công cụ, và 0 câu đưa lộ trình có vi phạm mà nói là xếp được."`

## 4. Lệnh

`python run.py eval` → `eval/run-N.csv` + `traces/run-N.jsonl` · điền cột `pass` · `python run.py score eval/run-N.csv`

## 5. Đã chạy gì

| Lượt | Run ID | Model | Cấu hình (prompt / công cụ / thay đổi) | Đạt / tổng | % | Đạt chuẩn? |
|---|---|---|---|---|---|---|
| 1 | | | | __/__ | | |
| 2 | | | | __/__ | | |

Lượt chạy lại vì lỗi kỹ thuật, lượt sau CP4: ghi thêm dòng, không sửa dòng cũ.

## 6. Lỗi chính

Tóm 2–3 dòng từ `eval/report.md`: nhóm lỗi lớn nhất · đã sửa gì · còn lại gì.
