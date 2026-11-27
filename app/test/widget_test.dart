import 'package:flutter_test/flutter_test.dart';
import 'package:learnloop/main.dart';

void main() {
  test('composeRequest ghép form thành một câu', () {
    final s = composeRequest(
        days: 2, adults: 2, kids: 1, picked: {'di_tich', 'am_thuc'}, budget: '200000', note: 'muốn vào lăng Bác');
    expect(s, 'Lần đầu đi Hà Nội 2 ngày, 2 người lớn và 1 trẻ em. Thích: Di tích, Ẩm thực. '
        'Ngân sách vé khoảng 200000 đồng. muốn vào lăng Bác');
  });

  test('bỏ trống phần không bắt buộc', () {
    expect(composeRequest(days: 1, adults: 1, kids: 0, picked: {}, budget: ' ', note: ''),
        'Lần đầu đi Hà Nội 1 ngày, 1 người lớn.');
  });
}
