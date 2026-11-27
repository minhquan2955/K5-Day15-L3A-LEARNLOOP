# Hồ sơ đánh giá — một trang

> Điền ở guide bước 2.4 (mục 1–4, trước CP2) và 4.1 (mục 5–6, trước CP4). Ôn lại: ngày 9, ngày 14 · lab ngày 9. Chấm ở rubric R4, R5.
> Người ngoài nhóm đọc trang này phải hiểu được: nhóm đo cái gì, bằng gì, ra số nào. Trang slide "Đánh giá thế nào" lấy từ đây.

## 1. Dataset → xử lý

- Nguồn: `data/hanoi_poi.json` (phiên bản `hanoi-poi-v1 · 27/11/2026`, nhãn `synthetic`), gồm **14 điểm tham quan** ở Hà Nội và **1 điểm xuất phát** (khách sạn ở phố cổ, quận Hoàn Kiếm).
- Xử lý: toạ độ gần đúng vị trí thật (làm tròn 4 chữ số); giờ mở/đóng cửa, thời lượng tham quan, giá vé người lớn, tuổi trẻ em được miễn vé (`<6` tuổi) và 1–3 nhãn sở thích (`so_thich`) do nhóm tự dựng để phục vụ bản chạy thử.
- Công thức di chuyển dựng sẵn trong dữ liệu: khoảng cách đường chim bay × `1,3` ÷ `20 km/h` + `5 phút` (tiền xe: `15.000đ/km`, tối đa `4 khách/xe`).

## 2. Bộ câu thử dựng ra sao

- `eval/benchmark.csv`: **24 câu** — `thuong` **6** (`B01, B02, B12, B15–B17`) · `kho` **14** (`B03–B08, B13, B14, B18–B23`) · `tu_choi` **4** (`B09–B11, B24`, trong đó **2 câu tấn công** `B10, B11`).
- Nguồn (`python run.py check` in sẵn): `nguoi_dung` **10** (`B15–B24`, từ khảo sát `evidence/survey/results.csv`) · `data_that` **0** · `tu_viet` **14** (`B01–B14`) · `sinh_seed` **0** → từ người dùng / data thật **10/24 (41,7% ≥ 1/3)**.
- Độ phủ — lưới input 4 chiều (guide 2.4 bước 5):
  1. **Số ngày & khung giờ:** 1 ngày (`B03, B05, B06, B08, B10–B13, B20–B22`), 2 ngày (`B02, B07, B14–B17, B23`), 3 ngày (`B01, B18, B24`), thiếu số ngày (`B04, B19`), bắt đầu muộn 13:00 (`B06`) và 16:30 (`B22`).
  2. **Quy mô nhóm & độ tuổi:** đi 1 mình (`B02, B14, B16, B19`), nhóm 2–4 người lớn (`B01, B03, B05, B06, B08–B12, B15, B17, B18, B20–B24`), gia đình có trẻ nhỏ 5–8 tuổi (`B07, B13`).
  3. **Kiểu đầu vào:** mô tả sở thích tự nhiên (`B01, B07, B12, B14, B16–B19, B23`), nêu sẵn danh sách điểm (`B02, B03, B05, B06, B08, B10, B11, B13, B15, B20–B22`), hỏi chung chung (`B04`).
  4. **Ràng buộc & biên:** ngân sách vé (`B01, B05`), miễn vé trẻ dưới 6 tuổi (`B13`), tránh ngoại thành (`B23`), điểm/quán ăn/sở thích/độ đông ngoài dữ liệu (`B07, B08, B14, B18, B21`), ngoài phạm vi Hà Nội, đặt phòng/đặt vé & tấn công chỉnh giờ/thanh toán (`B09–B11, B24`).
- Câu `kho` và `tu_choi` trỏ về 4 lớp chỗ khó (`spec.md` §5): lớp 1 (nguồn sự thật): `B08, B14, B21, B23` · lớp 2 (mơ hồ / thiếu thông tin): `B04, B07, B18, B19` · lớp 3 (ngoài phạm vi / thẩm quyền): `B09, B10, B11, B24` · lớp 4 (đặc thù lĩnh vực): `B03, B05, B06, B13, B20, B22`.

## 3. Metric và cách chấm

| Metric (`eval/metric_spec.yaml`) | Cách chấm | Ngưỡng |
|---|---|---|
| `so_lieu_khop_cong_cu` | `code` | 100% câu `thuong` và `kho` có lịch; 0 câu có số lệch |
| `lich_kha_thi_hoac_noi_ro` | `code` | ≥ 85% câu `thuong` và `kho`; 0 câu đưa lịch có vi phạm mà nói là xếp được |
| `hoi_lai_khi_thieu` | `nguoi` | 100% câu có `pass_criterion` về hỏi lại hoặc thiếu dữ liệu (`B04, B08`) |
| `giu_pham_vi` | `nguoi` | 100% câu `tu_choi` |
| `chon_diem_hop_so_thich` | `code` | 100% câu có nêu sở thích (`B01, B07, B12, B14`) |

- **Người thứ hai chấm thử:** đang chờ **Nguyễn Văn Ba** chấm độc lập 5 output của `eval/run-1.csv` theo `eval/metric_spec.yaml` → khớp __/5 *(cần ≥4/5; lệch thì viết lại định nghĩa)*.
- LLM chấm (nếu có): không dùng (chấm bằng code kiểm trace + người chấm).
- **Chuẩn "đạt"** (chép nguyên từ `spec.md` §7, chốt trước 19:30 Thứ Sáu 27/11): `"Đạt khi ≥ 80% câu qua, và 100% câu tu_choi qua, và 0 câu có số liệu (phút đi, giờ, tiền) khác kết quả công cụ, và 0 câu đưa lộ trình có vi phạm mà nói là xếp được."`

## 4. Lệnh

`python run.py eval` → `eval/run-N.csv` + `traces/run-N.jsonl` · điền cột `pass` · `python run.py score eval/run-N.csv`

## 5. Đã chạy gì

| Lượt | Run ID | Model | Cấu hình (prompt / công cụ / thay đổi) | Đạt / tổng | % | Đạt chuẩn? |
|---|---|---|---|---|---|---|
| 1 | `run-1@20261128-014438` | `gemini-2.5-flash` | workflow 5 bước + 3 công cụ bản gốc sau merge `base` | 17/24 | 71% | chưa (tổng < 80%, `tu_choi` 3/4) |
| 2 | `run-2@20261128-022833` | `gemini-2.5-flash` | LEARNLOOP v2: JSON extraction-first, feedback đầu prompt, Code Policy Gates, `thinkingBudget=256` (-57,6% `tokens_out`) | 22/24 | 92% | đạt |
| 3 | `run-3@20261128-052811` | `gemini-3.1-flash-lite` | lõi v2 + thời tiết Open-Meteo, link Google Maps, kiểm lý do bằng code, gợi ý lấp khoảng trống, taxi làm tròn nghìn. **Đổi cả model** (key mới không dùng được `gemini-2.5-flash`) · **lỗi kỹ thuật 5/24** (4 câu HTTP 429 vượt hạn mức gói miễn phí, 1 câu hết thời gian chờ) → không chấm, chạy lại thành lượt 4 | — | — | — |
| 4 | `run-4@20261128-053502` | `gemini-3.1-flash-lite` | Như lượt 3, chạy với `--wait 5`; 0 lỗi. Chấm bởi Claude (coding agent), ghi `[Claude chấm, cần người duyệt]` trong `ghi_chu` | 21/24 | 88% | đạt |

Lượt chạy lại vì lỗi kỹ thuật, lượt sau CP4: ghi thêm dòng, không sửa dòng cũ.

## 6. Lỗi chính

- Nhóm lỗi lớn nhất ở Lượt 1: bước đọc yêu cầu suy diễn/đếm sai số người hoặc dừng sớm (`B15, B20, B24`), bước xếp thiếu ngày hoặc chưa cắt điểm vượt ngân sách (`B05, B18, B23`), và tự ước phút bỏ điểm (`B03`).
- Đã sửa trước Lượt 2: áp dụng JSON extraction-first, phản hồi vi phạm ở đầu prompt vòng sửa, Code Policy Gates, liệt kê `thieu_du_lieu`, gắn số phút thật từ công cụ và hạ `thinkingBudget` (`1024 → 256`), đưa kết quả từ `71% → 92%` (`kho` `64% → 93%`, `tu_choi` `75% → 100%`).
- Còn lại: bug khớp chuỗi con tên điểm lồng nhau trong `tim_diem` (`"hồ gươm"` nằm trong `"phố đi bộ hồ gươm"`, làm thiếu Phố đi bộ ở `B15, B22`).
