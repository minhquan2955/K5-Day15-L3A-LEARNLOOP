import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnloop/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Playfair Display')
          ..addFont(rootBundle.load('assets/fonts/PlayfairDisplay.ttf'))
          ..addFont(rootBundle.load('assets/fonts/PlayfairDisplay-Italic.ttf')))
        .load();
    await (FontLoader(
      'Nunito Sans',
    )..addFont(rootBundle.load('assets/fonts/NunitoSans.ttf'))).load();
  });
  testWidgets(
    'Nút AI giữa thanh điều hướng gửi câu hỏi từ Home và lưu lịch trình',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const HanoiApp());
      await tester.pumpAndSettle();
      expect(find.text('Hanoi\nTravel Planner'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'Tạo lịch trình Hà Nội',
      );
      await tester.tap(find.widgetWithText(TextButton, 'AI').last);
      await tester.pumpAndSettle();
      expect(find.text('Tạo lịch trình Hà Nội'), findsOneWidget);
      expect(find.text('AI Travel Planner'), findsOneWidget);
      expect(find.text('My Trip'), findsNothing);
      expect(find.text('Hà Nội 2 ngày 1 đêm'), findsOneWidget);
      final save = find.text('Lưu trip');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Đã lưu'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Thêm bảo tàng');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Thêm bảo tàng'), findsOneWidget);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Trip'));
      await tester.pumpAndSettle();
      expect(find.text('Hà Nội 2 ngày 1 đêm'), findsOneWidget);
    },
  );

  testWidgets('Tìm địa điểm có dấu ở màn hình 360px và chia sẻ yêu thích', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const HanoiApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'hồ hoàn kiếm');
    await tester.pumpAndSettle();
    expect(find.text('Hoan Kiem Lake'), findsOneWidget);
    expect(find.text('Temple of Literature'), findsNothing);
    await tester.tap(find.byTooltip('Save Hoan Kiem Lake'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Saved Places'));
    await tester.tap(find.text('Saved Places'));
    await tester.pumpAndSettle();
    expect(find.text('Hoan Kiem Lake'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('composeRequest ghép form thành một câu', () {
    final s = composeRequest(
      days: 2,
      adults: 2,
      kids: 1,
      picked: {'di_tich', 'am_thuc'},
      budget: '200000',
      note: 'muốn vào lăng Bác',
    );
    expect(
      s,
      'Lần đầu đi Hà Nội 2 ngày, 2 người lớn và 1 trẻ em. Thích: Di tích, Ẩm thực. '
      'Ngân sách vé khoảng 200000 đồng. muốn vào lăng Bác',
    );
  });

  test('bỏ trống phần không bắt buộc', () {
    expect(
      composeRequest(
        days: 1,
        adults: 1,
        kids: 0,
        picked: {},
        budget: ' ',
        note: '',
      ),
      'Lần đầu đi Hà Nội 1 ngày, 1 người lớn.',
    );
  });
}
