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

Để dùng FastAPI đang chạy local, khởi động Flutter với `--dart-define=API=http://127.0.0.1:8000`. Nếu máy chủ yêu cầu `ACCESS_CODE`, nhập mã qua menu ba chấm trong chat.

## Build cho FastAPI và Docker

```sh
flutter build web --no-web-resources-cdn
```

Thêm `--dart-define=API=` để chat gọi `/api/plan` cùng origin khi phục vụ từ FastAPI. Chép nội dung `build/web/` vào `../server/static/` rồi chạy lại `docker compose up --build -d --wait` từ thư mục gốc.

Font Playfair Display và Nunito Sans được đóng gói cục bộ cùng giấy phép OFL trong `assets/fonts/`. Ảnh giao diện được lấy từ bộ nhận diện do nhóm cung cấp trong `../assets/`.
