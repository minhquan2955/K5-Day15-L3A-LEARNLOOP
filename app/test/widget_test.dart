import 'package:flutter/services.dart';
import 'package:learnloop/travel_data.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnloop/main.dart';
import 'package:learnloop/pages.dart';
import 'package:learnloop/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
      await tester.pumpWidget(HanoiApp(travel: fakeTravel()));
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
      expect(find.text('Chuyến đi'), findsNothing);
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
      await tester.tap(find.text('Chuyến đi').last);
      await tester.pumpAndSettle();
      expect(find.text('Hà Nội 2 ngày 1 đêm'), findsOneWidget);
    },
  );

  testWidgets('Tìm địa điểm có dấu ở màn hình 360px và chia sẻ yêu thích', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(HanoiApp(travel: fakeTravel()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'hồ hoàn kiếm');
    await tester.pumpAndSettle();
    expect(find.text('Hồ Gươm – Đền Ngọc Sơn'), findsOneWidget);
    expect(find.text('Văn Miếu – Quốc Tử Giám'), findsNothing);
    await tester.tap(find.byTooltip('Lưu Hồ Gươm – Đền Ngọc Sơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cá nhân').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Địa điểm đã lưu'));
    await tester.tap(find.text('Địa điểm đã lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ Gươm – Đền Ngọc Sơn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Đổi tên, đặt yêu thích rồi xoá chuyến đi qua API', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final travel = fakeTravel();
    await tester.pumpWidget(HanoiApp(travel: travel));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có chuyến đi'), findsOneWidget);
    await travel.toggleTrip('chat-1', sampleItinerary);
    await tester.pumpAndSettle();
    // Home hiện chuyến vừa lưu; điểm dừng khớp danh mục lấy tên từ DB
    expect(find.text('Hà Nội 2 ngày 1 đêm'), findsOneWidget);
    expect(find.text('Hồ Gươm – Đền Ngọc Sơn'), findsOneWidget);
    await tester.tap(find.text('Chuyến đi').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thêm vào yêu thích'));
    await tester.pumpAndSettle();
    expect(travel.trips.single.favorite, isTrue);
    await tester.tap(find.byTooltip('Tuỳ chọn chuyến đi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đổi tên'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Chuyến mới');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Chuyến mới'), findsOneWidget);
    await tester.tap(find.byTooltip('Tuỳ chọn chuyến đi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá chuyến đi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xoá'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có chuyến đi'), findsOneWidget);
    expect(travel.isSaved('chat-1'), isFalse);
  });

  testWidgets('Phải đăng nhập mới vào app; đăng xuất quay lại màn đăng nhập', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final travel = fakeTravel(loggedIn: false);
    await tester.pumpWidget(HanoiApp(travel: travel));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập'), findsWidgets);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'khach@example.com');
    await tester.enterText(fields.at(1), 'sai-mat-khau');
    await tester.tap(find.widgetWithText(Pill, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Sai email hoặc mật khẩu'), findsOneWidget);
    await tester.enterText(fields.at(1), 'mat-khau-1');
    await tester.tap(find.widgetWithText(Pill, 'Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Hanoi\nTravel Planner'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('learnloop_token'),
      'test-token',
    );
    await tester.tap(find.text('Cá nhân').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(Pill, 'Đăng xuất'));
    await tester.tap(find.widgetWithText(Pill, 'Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Pill, 'Đăng nhập'), findsOneWidget);
    expect(travel.loggedIn, isFalse);
  });

  test('định dạng tiền, giờ OSM và cảnh báo giờ mở cửa', () {
    expect(vnd(50000), '50.000đ');
    expect(vnd(1250000), '1.250.000đ');
    expect(vnd(0), '0đ');
    expect(minutesText(45), '~ 45 phút');
    expect(minutesText(90), '~ 1 giờ 30 phút');
    expect(
      osmHoursVi('Tu-Th 07:30-10:30; Sa,Su off'),
      'T3-T5 07:30-10:30; T7,CN nghỉ',
    );
    const lang = Place(
      id: 'lang_bac',
      name: 'Lăng',
      opens: '07:30',
      closes: '10:30',
    );
    expect(hoursWarning(lang, {'gio_den': '08:00'}), isNull);
    expect(
      hoursWarning(lang, {'gio_den': '14:00'}),
      contains('Ngoài giờ mở cửa'),
    );
    expect(hoursWarning(lang, {'buoi': 'sang'}), isNull);
    expect(hoursWarning(lang, {'buoi': 'chieu'}), isNotNull);
    expect(hoursWarning(lang, <String, dynamic>{}), isNull); // chưa đặt giờ
    expect(
      hoursWarning(const Place(id: '', name: 'x'), {'gio_den': '03:00'}),
      isNull,
    );
  });

  testWidgets('Tự tạo chuyến, thêm điểm từ trang chi tiết, chuyển ngày', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final travel = fakeTravel();
    await tester.pumpWidget(HanoiApp(travel: travel));
    await tester.pumpAndSettle();
    await travel.createTrip('Cuối tuần', DateTime(2030, 1, 5), 2);
    await tester.pumpAndSettle();
    expect(find.text('Cuối tuần'), findsOneWidget);
    await tester.tap(find.text('Khám phá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Văn Miếu – Quốc Tử Giám'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Pill, 'Ngày 1'));
    await tester.pumpAndSettle();
    expect(travel.current!.days[0].single['dia_diem_id'], 'van_mieu');
    Navigator.of(
      tester.element(find.text('Thêm vào:')),
      rootNavigator: true,
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Vé tham quan Ngày 1: 70.000đ'),
      findsOneWidget,
    );
    await tester.tap(find.text('Văn Miếu – Quốc Tử Giám'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển sang Ngày 2'));
    await tester.pumpAndSettle();
    expect(travel.current!.days[0], isEmpty);
    expect(travel.current!.days[1].single['dia_diem_id'], 'van_mieu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nút −/+ chọn số ngày trong khoảng 1..14', (tester) async {
    var days = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: DayStepper(
              value: days,
              onChanged: (n) => setState(() => days = n),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1 ngày'), findsOneWidget);
    await tester.tap(find.byTooltip('Bớt một ngày')); // đang ở 1: bị khoá
    await tester.pump();
    expect(days, 1);
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.byTooltip('Thêm một ngày'), warnIfMissed: false);
      await tester.pump();
    }
    expect(days, maxTripDays);
    expect(find.text('14 ngày'), findsOneWidget);
  });

  test('Google Maps: URL điểm, lộ trình và ước tính di chuyển', () {
    const guom = Place(id: 'g', name: 'Hồ Gươm', lat: 21.0307, lng: 105.8524);
    const mieu = Place(id: 'm', name: 'Văn Miếu', lat: 21.0287, lng: 105.8355);
    const lang = Place(id: 'l', name: 'Lăng Bác', lat: 21.0368, lng: 105.8346);
    const tuy = Place(id: '', name: 'Điểm tự nhập'); // không có toạ độ

    final one = mapsPlaceUrl(guom);
    expect(one.host, 'www.google.com');
    expect(one.path, '/maps/search/');
    expect(one.queryParameters, {'api': '1', 'query': '21.0307,105.8524'});

    // một điểm: chỉ có đích, Google tự lấy vị trí hiện tại làm điểm xuất phát
    final single = mapsDirectionsUrl([guom]).queryParameters;
    expect(single.containsKey('origin'), isFalse);
    expect(single['destination'], '21.0307,105.8524');

    final route = mapsDirectionsUrl([guom, tuy, mieu, lang]).queryParameters;
    expect(route['origin'], '21.0307,105.8524');
    expect(
      route['waypoints'],
      '21.0287,105.8355',
    ); // điểm không toạ độ bị bỏ qua
    expect(route['destination'], '21.0368,105.8346');

    final many = [for (var i = 0; i < 20; i++) guom];
    final limited = mapsDirectionsUrl(many).queryParameters;
    expect(limited['waypoints']!.split('|'), hasLength(maxMapsPoints - 2));

    expect(travelText(guom, mieu), '~2,3 km · ~12 phút');
    expect(haversineKm(guom, guom), 0);
  });

  testWidgets('Tab Bản đồ hiện thứ tự, khoảng cách và nút Google Maps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final travel = fakeTravel();
    await tester.pumpWidget(HanoiApp(travel: travel));
    await tester.pumpAndSettle();
    await travel.createTrip('Thử bản đồ', DateTime(2030, 1, 5), 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bản đồ').first); // tab Bản đồ
    await tester.pumpAndSettle();
    expect(find.text('Ngày 1 chưa có điểm dừng'), findsOneWidget);
    await travel.addPlace(0, travel.placeById('ho_guom')!);
    await travel.addPlace(0, travel.placeById('van_mieu')!);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Từ điểm trước: ~2,3 km · ~12 phút'),
      findsOneWidget,
    );
    expect(find.textContaining('Tổng ~2,3 km'), findsOneWidget);
    expect(find.text('Mở lộ trình Ngày 1 trên Google Maps'), findsOneWidget);
    expect(
      find.byTooltip('Chỉ đường đến Hồ Gươm – Đền Ngọc Sơn'),
      findsOneWidget,
    );
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
