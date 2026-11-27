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

## Ứng viên mở rộng (chưa dùng) · `data/ung_vien_poi.csv`

| | |
|---|---|
| Dùng để làm gì | Danh sách **ứng viên** để nhóm duyệt khi mở rộng `hanoi_poi.json` từ 14 điểm. **Bản chạy thử không đọc file này** |
| Từ đâu | `python data/lay_ung_vien_poi.py` gộp 3 nguồn, mỗi nguồn 1 request: **Wikidata** (SPARQL, CC0) · **OpenStreetMap** qua Overpass (© OpenStreetMap contributors, ODbL) · **Wikivoyage** tiếng Anh trang "Hanoi", các mục `{{see}}` / `{{do}}` lấy qua MediaWiki `action=raw` (Wikivoyage contributors, CC BY-SA 4.0). Không cào Google Maps / TripAdvisor / Foody (điều khoản cấm) |
| Xử lý | Khung nội thành (lat 20,95–21,12, lon 105,70–105,95; `--rong` = cả Hà Nội). Gộp theo mã Wikidata hoặc tên + khoảng cách < 150–300 m. Đánh dấu cột `da_co_trong_du_lieu` nếu trùng 14 điểm đang có. Ưu tiên lên đầu: có trên Wikivoyage (có giờ / giá) > có xếp hạng di tích > có bài Wikipedia tiếng Việt |
| Số dòng | 269 ứng viên (lấy 28/11/2026): 15 trùng điểm đã có, 43 có từ 2 nguồn, 17 có giờ hoặc giá Wikivoyage |
| Giới hạn | Giờ / giá Wikivoyage do cộng đồng viết, có thể cũ; OSM hay thiếu giờ mở cửa. **Trước khi thêm điểm nào vào `hanoi_poi.json`:** người duyệt kiểm giờ, giá, ngày nghỉ trên trang chính thức của điểm đó, điền các cột `mo, dong, gia_ve, phut_tham_quan, so_thich, nguon_kiem, ngay_kiem, nguoi_kiem`. Thêm điểm làm đổi kết quả câu thử (vd **B08** đang cần "không có dữ liệu Bảo tàng Mỹ thuật Việt Nam") → chạy lại eval thành lượt mới, ghi `spec.md` §10 |

**Cách sinh:** viết tay, không dùng seed ngẫu nhiên. Người kiểm: ____ · đã kiểm tay 14/14 dòng: ☐

**Data `synthetic` không phải bằng chứng pain.** Bằng chứng pain lấy từ phỏng vấn trực tiếp, ghi ở `evidence/interviews/`.
