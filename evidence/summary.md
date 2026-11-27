# Tổng hợp bằng chứng pain

> Điền ở guide bước 1.2, xong trước **CP3 10:00 Thứ Bảy 28/11**. Chấm ở rubric R1.
> Ba nguồn ngang nhau — tối thiểu **≥1 nguồn đạt ngưỡng**. Mạnh nhất: đào data ra insight → hỏi người dùng để kiểm lại (hoặc ngược lại).

## 1. Nguồn đã dùng

| Nguồn | Đạt ngưỡng? | File |
|---|---|---|
| Đào data (x/N, %, cách đếm chạy lại được, ≥5 ví dụ) | Không thu thập cho phần bằng chứng này | `evidence/data-mining.md` |
| Phỏng vấn (≥3 người ngoài nhóm, đúng người dùng) | Không thực hiện cho phần bằng chứng này | — |
| Khảo sát (≥20 người ngoài nhóm, đúng người dùng) | **Đạt ngưỡng CP3.** Trong 35 phản hồi, 26 qua bộ lọc tuổi, thời gian đi và rà soát thông tin chuyến đi. Nhóm xác nhận người trả lời trong mẫu 26 phiếu là người ngoài nhóm | [`questions.md`](survey/questions.md), [`results.csv`](survey/results.csv) |

## 2. Số chính

- Trong **35 phản hồi**, **32/35** báo đã đi tự túc 2–3 ngày đến một thành phố mới lần đầu trong 12 tháng qua. Trong nhóm này, **26/32** báo có trục trặc lộ trình, **20/32** chưa chốt được lịch từng ngày và **14/32** mất ít nhất 1 giờ chuẩn bị.
- Trong **26 phản hồi qua bộ lọc** (20–30 tuổi, đã đi trong 12 tháng qua, tạm gác `S04` và `S13`), **20/26 (76,9%)** báo có trục trặc lộ trình, **15/26** chưa chốt được lịch từng ngày, **11/26 (42,3%)** mất ít nhất 1 giờ chuẩn bị và **3/26** đã dùng app lên lịch.
- Trong mẫu 26 phản hồi, có **2** chuyến gần nhất tại Hà Nội (`S02`, `S14`). Cả hai đều báo có trục trặc và mất ít nhất 1 giờ chuẩn bị. Thời gian tự báo cáo lần lượt là **1–2 giờ** và **trên 4 giờ**.

## 3. ≥5 trích dẫn hoặc ví dụ nguyên văn (có nguồn, bỏ tên)

1. `"tốn thời gian đi lòng vòng giữa các điểm"` — phiếu khảo sát `S02` (đi Hà Nội, chuẩn bị 1–2 giờ)
2. `"Mấy quán ăn đóng cửa khiến lịch trình thay đổi (đi ăn quán khác, khoảng cách xa hơn)"` — phiếu khảo sát `S07` (chuẩn bị 1–2 giờ)
3. `"các thông tin quán ăn và cửa hàng không khớp với trên web và review"` — phiếu khảo sát `S14` (đi Hà Nội 1 mình, chuẩn bị >4 giờ)
4. `"Một điểm tham quan đóng cửa lúc đến nên phải đổi kế hoạch buổi chiều."` — phiếu khảo sát `S22` (đi Hội An)
5. `"Mất khoảng 20 phút tìm điểm tiếp theo phù hợp với thời gian còn lại."` — phiếu khảo sát `S34` (đi Bắc Ninh)
6. `"Lịch AI gợi ý khá tiện nhưng có hai điểm cách xa nhau, phải tự đổi thứ tự để tiết kiệm thời gian."` — phiếu khảo sát `S18` (đi Đà Lạt)

## 4. Kiểm tra dữ liệu

- **Dòng trùng.** Kiểm tra mã phiếu và so sánh nội dung từng dòng, bỏ qua cột `ma_phieu`. CSV hiện có 35 mã phiếu riêng và không có dòng trùng nguyên nội dung.
- **Bộ lọc.** Trong 32 người báo đã đi trong 12 tháng qua, 28 người thuộc nhóm tuổi 20–30. Tạm gác `S04` và `S13` để xác minh thông tin chuyến đi, còn **26 phản hồi**. Tuổi của `S16` (dưới 20) và `S17` (trên 30) trong CSV hiện đã khớp bản chép trước đó. Hai phiếu này nằm ngoài mẫu 20–30 tuổi.
- **Điều kiện ngoài nhóm.** Nhóm xác nhận người trả lời trong mẫu 26 phiếu là người ngoài nhóm. CSV đã ẩn danh và không ghi thông tin thành viên.

## 5. Kết luận

Khảo sát bước đầu ủng hộ giả thuyết về khó khăn khi sắp lộ trình. Trong mẫu qua bộ lọc, **20/26** báo gặp trục trặc và **11/26** mất ít nhất một giờ chuẩn bị. Mẫu chỉ có **2 phản hồi về chuyến Hà Nội** trong độ tuổi mục tiêu, nên kết quả cho lát cắt Hà Nội còn sơ bộ. [Giả thuyết ban đầu](hypothesis.md)
