# PostgreSQL cho LEARNLOOP

[Migration đầu tiên](migrations/001_initial.sql) tạo schema `learnloop` với tám bảng và một view.

| Dữ liệu | Bảng |
|---|---|
| Hồ sơ dùng trong Profile | `nguoi_dung` |
| Danh mục Explore và bộ lọc | `dia_diem`, `so_thich`, `dia_diem_so_thich` |
| Danh sách Saved Places | `dia_diem_da_luu` |
| My Trip và lịch trình đã lưu từ AI | `chuyen_di`, `ngay_lich_trinh`, `diem_dung` |

Chuyến đi có tối đa 14 ngày (migration 005 nâng từ 3) và tính ngày kết thúc từ ngày bắt đầu. View `chuyen_di_theo_trang_thai` phân loại theo ngày hiện tại ở Hà Nội. Điểm dừng giữ tên và chi phí tại thời điểm lưu, kể cả khi địa điểm bị xóa khỏi danh mục. Giá vé trong danh mục là giá theo người. Giá vé tại điểm dừng là tổng của cả nhóm.

## Khởi động PostgreSQL local

Từ thư mục gốc, chạy:

```sh
docker compose up -d --wait
docker compose exec db psql -U learnloop -d learnloop
```

Compose dùng PostgreSQL 18 với [image pgvector](https://github.com/pgvector/pgvector#docker), lưu dữ liệu vào volume `postgres_data` và chỉ cho truy cập DB từ mạng Docker. Có thể đặt `POSTGRES_PASSWORD` trong `.env` trước lần khởi tạo đầu tiên. Khi tạo volume, một script SQL nhập danh mục và nhãn sở thích từ [JSON mẫu](../data/hanoi_poi.json). Giờ và giá trong danh mục này là dữ liệu dựng.

Docker chỉ chạy script khởi tạo trên volume rỗng. Với PostgreSQL đã có sẵn, áp dụng migration một lần trên database đích bằng `psql -v ON_ERROR_STOP=1 -d <database> -f db/migrations/001_initial.sql`. Khi thêm migration, chạy tệp mới trên database đã khởi tạo.

## Kiểm tra schema

Với container đang chạy và đã nhập dữ liệu mẫu, thử khóa ngoại, thứ tự ngày, trạng thái chuyến đi và xóa dữ liệu liên quan:

```powershell
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Get-Content -Raw -Encoding UTF8 db/check.sql | docker compose exec -T db psql -v ON_ERROR_STOP=1 -U learnloop -d learnloop
```

Các thao tác kiểm thử nằm trong một giao dịch rollback.

## Đăng nhập và CRUD API

[server/auth.py](../server/auth.py) và [server/crud.py](../server/crud.py) đọc/ghi schema này qua `DATABASE_URL` (compose tự đặt). Agent AI vẫn đọc `data/hanoi_poi.json`.

Người dùng đăng ký bằng email + mật khẩu (băm scrypt). Đăng nhập trả token; gửi kèm `Authorization: Bearer <token>`. Bảng `phien` chỉ lưu SHA-256 của token, phiên hết hạn sau 30 ngày. Dữ liệu cá nhân (hồ sơ, đã lưu, chuyến đi) chỉ chủ tài khoản xem và sửa được.

| Dữ liệu | Endpoint | Quyền |
|---|---|---|
| Tài khoản | `POST /api/dang-ky`, `POST /api/dang-nhap`, `POST /api/dang-xuat` | công khai |
| Danh mục | `GET /api/dia-diem`, `GET /api/dia-diem/{id}`, `GET /api/so-thich` | công khai |
| Danh mục | `POST /api/dia-diem`, `PUT/DELETE /api/dia-diem/{id}` | quản trị |
| Hồ sơ | `GET/PUT /api/toi` | đăng nhập |
| Đã lưu | `GET /api/da-luu`, `PUT/DELETE /api/da-luu/{dia_diem_id}` | đăng nhập |
| Chuyến đi | `GET/POST /api/chuyen-di`, `GET/PATCH/DELETE /api/chuyen-di/{id}` (PATCH có `ngay` thì thay cả lịch trình) | đăng nhập |

Cấp quyền quản trị cho một tài khoản đã đăng ký:

```sh
docker compose exec db psql -U learnloop -d learnloop -c "UPDATE learnloop.nguoi_dung SET quan_tri = true WHERE email = 'ban@example.com'"
```

Kiểm thử trên stack đang chạy: `python server/smoke_crud.py` (tạo hai tài khoản thử rồi tự xoá).

## Thông tin địa điểm tra sẵn

[db/fetch_sources.py](fetch_sources.py) tra một lần từ Wikidata, Wikipedia tiếng Việt, Wikimedia Commons và OpenStreetMap rồi ghi [data/dia_diem_nguon.json](../data/dia_diem_nguon.json). [Seed 002](seed/002_dia_diem_nguon.sql) nạp tệp này vào các cột `mo_ta`, `anh`, `anh_ghi_cong`, `website`, `dia_chi`, `gio_mo_cua_osm`, `wikipedia_url`. App chỉ đọc DB, không gọi các nguồn này lúc chạy. Không có rating hay review: các nguồn mở không cung cấp.

Mỗi địa điểm được nối với nguồn qua mã Wikidata đã đối chiếu (`WIKIDATA` trong script). Điểm chưa có mã thì giữ dữ liệu cũ. Thêm mã rồi chạy lại để tra:

```sh
python db/fetch_sources.py        # Wikimedia trả 429 thì đặt WIKIMEDIA_UA="TenApp/1.0 (email liên hệ)"
```

Giấy phép phải ghi khi hiển thị: OSM theo ODbL (© OpenStreetMap contributors), đoạn trích Wikipedia theo CC BY-SA 4.0 (kèm link bài), ảnh Commons theo giấy phép từng ảnh (cột `anh_ghi_cong`). App hiện các dòng này trong trang chi tiết địa điểm.

## Nâng cấp volume đã có

Docker chỉ chạy script khởi tạo trên volume rỗng. Với DB đang chạy, áp dụng một lần theo thứ tự (cần `docker compose up -d` trước để container có tệp JSON):

```powershell
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
foreach ($f in 'db/migrations/003_anh_quan.sql', 'db/migrations/004_auth_nguon.sql', 'db/migrations/005_so_ngay_toi_da.sql', 'db/seed/002_dia_diem_nguon.sql') {
  Get-Content -Raw -Encoding UTF8 $f | docker compose exec -T db psql -v ON_ERROR_STOP=1 -U learnloop -d learnloop
}
```

## Truy xuất ngữ cảnh cho RAG

[Migration pgvector](migrations/002_pgvector.sql) bật extension `vector`, tạo bảng `learnloop.rag_doan`, chỉ mục HNSW theo khoảng cách cosine và hàm `learnloop.tim_doan_rag`.

Compose tự áp dụng migration trên volume mới. Khi nâng cấp volume đã chạy migration 001, cập nhật container rồi áp dụng migration 002 một lần:

```sh
docker compose up -d --wait
docker compose exec -T db psql -v ON_ERROR_STOP=1 -U learnloop -d learnloop -f /docker-entrypoint-initdb.d/002_pgvector.sql
```

Chọn model embedding phù hợp với văn bản tiếng Việt và cấu hình đầu ra **768 chiều**. Khi nhập liệu, chia tài liệu thành các đoạn rồi lưu nội dung, tiêu đề, nguồn, thứ tự và embedding vào `rag_doan`. Đặt `dia_diem_id` nếu đoạn mô tả một địa điểm trong danh mục. Dùng một mã `embedding_model` nhất quán cho cùng model, phiên bản và cấu hình.

Mẫu SQL sau dùng các tham số của database driver, truyền vector dưới dạng chuỗi `[...]` gồm 768 giá trị. Cập nhật nội dung và embedding trong cùng câu lệnh khi đoạn nguồn thay đổi.

```sql
INSERT INTO learnloop.rag_doan (nguon, tieu_de, thu_tu, noi_dung, dia_diem_id, embedding_model, embedding)
VALUES ($1, $2, $3, $4, $5, $6, $7::vector)
ON CONFLICT (embedding_model, nguon, thu_tu) DO UPDATE SET
    tieu_de = EXCLUDED.tieu_de,
    noi_dung = EXCLUDED.noi_dung,
    dia_diem_id = EXCLUDED.dia_diem_id,
    embedding = EXCLUDED.embedding;
```

Để truy xuất, nhúng câu hỏi bằng cùng model và cấu hình 768 chiều. Hàm dưới đây trả nội dung và nguồn cho tối đa 5 đoạn gần nhất của model được chọn. Khoảng cách nhỏ hơn nghĩa là gần hơn. Ứng dụng có thể đưa các đoạn này vào ngữ cảnh cho model trả lời và giữ `nguon` để trích dẫn.

```sql
SELECT * FROM learnloop.tim_doan_rag($1::vector, $2, 5);
```

Kiểm thử truy xuất bằng vector tổng hợp trong một giao dịch rollback:

```powershell
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Get-Content -Raw -Encoding UTF8 db/check_rag.sql | docker compose exec -T db psql -v ON_ERROR_STOP=1 -U learnloop -d learnloop
```

Kho RAG bắt đầu trống. Luồng chat hiện tại chưa tạo embedding hoặc gọi truy xuất.
