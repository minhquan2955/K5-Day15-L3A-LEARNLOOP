# Data card — dữ liệu bản chạy thử dùng

> Bản đầu ở CP2 (27/11/2026), bổ sung đủ ở CP3.

## Dataset 1 · Điểm tham quan Hà Nội (`data/hanoi_poi.json`)

| | |
|---|---|
| Dùng để làm gì | Nguồn cho các công cụ `tim_diem`, `thoi_gian_di`, `kiem_lich_trinh` (thiết kế ở `spec.md` §4, code ở CP3) · căn cứ để chấm bộ câu thử |
| Từ đâu | Nhóm tự dựng. Tên điểm có thật. Toạ độ gần đúng vị trí thật, lấy từ bản đồ công khai, làm tròn 4 chữ số |
| Xử lý những bước gì | Chọn 14 điểm hay có trong lịch trình Hà Nội. Đặt **số dựng** cho giờ mở / đóng, thời lượng tham quan, giá vé người lớn và tuổi trẻ em được miễn vé. Thời gian đi = khoảng cách đường chim bay × 1,3 ÷ 20 km/h + 5 phút. Mỗi điểm gắn 1–3 nhãn sở thích (`so_thich`: di_tich, lich_su, am_thuc, buoi_toi, chup_anh, tre_em…) do nhóm tự gắn. Các hệ số trên cũng là số dựng, ghi sẵn trong file |
| Số dòng / số đoạn | 14 điểm + 1 điểm xuất phát (khách sạn ở phố cổ) |
| Phiên bản / ngày lấy | `hanoi-poi-v1` · 27/11/2026 |
| Nhãn | `synthetic` |
| Giới hạn | Giá và giờ **không phải** số chính thức, không dùng để đi thật. Thời gian đi ước theo công thức, chưa tính giờ cao điểm hay đường một chiều. Chỉ có Hà Nội. Nhãn sở thích là chủ quan của nhóm. Không có độ đông, quán ăn cụ thể. Chưa có ngày đóng cửa theo thứ (vd bảo tàng nghỉ thứ Hai), ngày lễ, thời tiết |

**Cách sinh:** viết tay, không dùng seed ngẫu nhiên. Người kiểm: ____ · đã kiểm tay 14/14 dòng: ☐

**Data `synthetic` không phải bằng chứng pain.** Bằng chứng pain lấy từ phỏng vấn trực tiếp, ghi ở `evidence/interviews/`.
