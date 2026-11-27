# Hanoi Travel Planner

Giao diện Flutter Web ưu tiên màn hình điện thoại. Bố cục và nội dung tham chiếu [UI-SPEC.md](../UI-SPEC.md).

## Chạy và kiểm tra

Trong thư mục `app/`, dùng Flutter 3.50 với Dart 3.14:

```sh
flutter pub get
flutter run -d chrome --no-web-resources-cdn
flutter analyze
flutter test
```

Chat mặc định dùng lịch trình mẫu. Ảnh đính kèm được xem trong chat, và dữ liệu đã lưu tồn tại trong phiên hiện tại.

Khi gọi API thật, thẻ lịch trình hiện từng điểm với giờ đến, số phút đi, thời gian tham quan, tiền vé, giờ mở cửa và lý do chọn; mọi số do công cụ phía máy chủ tính. Nút **Chỉ đường** mở Google Maps (Maps URLs, không cần key): từng điểm đi từ điểm trước, điểm đầu ngày đi từ vị trí của máy; nút cả ngày gộp tối đa 4 điểm mỗi link vì trình duyệt di động chỉ nhận 3 điểm dừng giữa đường. Máy chủ gửi `maps_url` / `maps_urls` thì app dùng link đó, không thì tự tạo từ tên điểm. Nếu máy chủ trả `weather` cho từng ngày, app hiện dự báo cạnh tiêu đề ngày kèm link "Weather data by Open-Meteo.com" theo giấy phép CC BY 4.0.

Để dùng FastAPI đang chạy local, khởi động Flutter với `--dart-define=API=http://127.0.0.1:8000`. Nếu máy chủ yêu cầu `ACCESS_CODE`, nhập mã qua menu ba chấm trong chat.

## Build cho FastAPI và Docker

```sh
flutter build web --no-web-resources-cdn
```

Thêm `--dart-define=API=` để chat gọi `/api/plan` cùng origin khi phục vụ từ FastAPI. Chép nội dung `build/web/` vào `../server/static/` rồi chạy lại `docker compose up --build -d --wait` từ thư mục gốc.

Font Playfair Display và Nunito Sans được đóng gói cục bộ cùng giấy phép OFL trong `assets/fonts/`. Ảnh giao diện được lấy từ bộ nhận diện do nhóm cung cấp trong `../assets/`.
