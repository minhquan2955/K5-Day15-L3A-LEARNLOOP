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

## Dataset 3 · Toạ độ chỗ ở (Nominatim / OpenStreetMap, gọi lúc chạy)

| | |
|---|---|
| Dùng để làm gì | Công cụ `tim_noi_o`: điểm xuất phát / về mỗi ngày khi người dùng nêu chỗ ở (chế độ "đi lại ít nhất") |
| Từ đâu | Khớp tên 14 điểm trong Dataset 1 trước (vd "gần Hồ Tây" → toạ độ Chùa Trấn Quốc); không khớp thì gọi Nominatim `/search` (OpenStreetMap, dữ liệu ODbL, tối đa 1 request / giây, phải có User-Agent; chỉ dùng phi thương mại ở quy mô nhỏ — sản phẩm thật cần máy chủ riêng hoặc nhà cung cấp trả phí) |
| Xử lý | Giới hạn khung Hà Nội (lat 20,55–21,40, lon 105,30–106,05); ngoài khung → báo lỗi, dùng khách sạn mặc định. Toạ độ làm tròn 5 chữ số |
| Giới hạn | Độ chính xác phụ thuộc OSM; tên khách sạn nhỏ có thể không có. Thời gian đi vẫn theo công thức chim bay × 1,3 của Dataset 1 |

## Dataset 2 · Dự báo thời tiết (Open-Meteo, gọi lúc chạy)

| | |
|---|---|
| Dùng để làm gì | Công cụ `thoi_tiet`: dự báo từng ngày của chuyến đi, cho ghi chú và để AI dời điểm ngoài trời khỏi ngày mưa |
| Từ đâu | API Open-Meteo `/v1/forecast` (gói miễn phí phi thương mại, không cần key, ≤10.000 lượt / ngày). Dữ liệu CC BY 4.0 — phải ghi "Weather data by Open-Meteo.com" kèm link ở chỗ hiện dữ liệu |
| Xử lý | Toạ độ trung tâm Hà Nội (điểm khách sạn), biến `weather_code`, `temperature_2m_min/max`, `precipitation_probability_max`, `precipitation_sum`. Mã WMO → mô tả tiếng Việt; nhiệt độ làm tròn độ, mưa làm tròn 0,1 mm. Ngưỡng "ngày mưa" ≥ 60% *(tự ước tính)* |
| Giới hạn | Chỉ 16 ngày tới; dự báo đổi theo giờ lấy nên **không chạy lại ra cùng số**. Một toạ độ cho cả Hà Nội (Chùa Hương, Bát Tràng có thể khác). Chỉ gọi khi người dùng nói ngày đi |

**Cách sinh:** viết tay, không dùng seed ngẫu nhiên. Người kiểm: ____ · đã kiểm tay 14/14 dòng: ☐

**Data `synthetic` không phải bằng chứng pain.** Bằng chứng pain lấy từ phỏng vấn trực tiếp, ghi ở `evidence/interviews/`.
