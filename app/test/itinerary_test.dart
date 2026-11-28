import 'package:flutter_test/flutter_test.dart';
import 'package:learnloop/chat.dart';
import 'package:learnloop/travel_data.dart';
import 'package:material_ui/material_ui.dart';

/// JSON giống `/api/plan` của lõi v2 (không có maps_url / weather) và bản có thời tiết.
Map<String, Object?> apiItinerary({bool weather = false}) => {
  'days': [
    {
      'day': 1,
      if (weather) 'date': '2026-12-01',
      if (weather)
        'weather': {
          'ngay': '2026-12-01',
          'mo_ta': 'Mưa vừa',
          'nhiet_do_thap': 20,
          'nhiet_do_cao': 25,
          'kha_nang_mua': 80,
          'luong_mua_mm': 12.3,
        },
      'stops': [
        {
          'id': 'lang_bac',
          'name': 'Lăng Chủ tịch Hồ Chí Minh',
          'arrive': '07:41',
          'visit_min': 60,
          'travel_min_from_prev': 11,
          'ticket_vnd': 0,
          'mo': '07:30',
          'dong': '10:30',
          'reason': 'Chỉ mở buổi sáng nên đi đầu ngày.',
        },
        {
          'id': 'van_mieu',
          'name': 'Văn Miếu – Quốc Tử Giám',
          'arrive': '08:50',
          'visit_min': 75,
          'travel_min_from_prev': 9,
          'ticket_vnd': 140000,
          'mo': '08:00',
          'dong': '17:00',
          'reason': '',
        },
      ],
    },
  ],
  'total_vnd': 140000,
  'per_person_vnd': 70000,
  'taxi_vnd': 78000,
  'feasible': true,
  'notes': [
    'Dữ liệu chỉ có 14 điểm ở Hà Nội.',
    'Dự báo thời tiết từ Open-Meteo.com (CC BY 4.0).',
    'Ngày 1 trống từ 12:08 đến 18:54. Có thể thêm: Nhà tù Hỏa Lò.',
    'Xuất phát và về: Hàng Bạc, Hoàn Kiếm.',
  ],
};

void main() {
  test('vnd định dạng tiền Việt', () {
    expect(vnd(0), '0đ');
    expect(vnd(70000), '70.000đ');
    expect(vnd(1234567), '1.234.567đ');
  });

  test('link Google Maps theo Maps URLs, không cần key', () {
    final url = Uri.parse(
      mapsDirections(['Lăng Chủ tịch Hồ Chí Minh, Hà Nội', 'Văn Miếu, Hà Nội']),
    );
    expect(url.host, 'www.google.com');
    expect(url.path, '/maps/dir/');
    expect(url.queryParameters['api'], '1');
    expect(url.queryParameters.containsKey('origin'), isFalse);
    expect(url.queryParameters['destination'], 'Văn Miếu, Hà Nội');
    expect(
      url.queryParameters['waypoints'],
      'Lăng Chủ tịch Hồ Chí Minh, Hà Nội',
    );
    expect(url.queryParameters['travelmode'], 'driving');
    expect(mapsPlace('Hồ Gươm – Đền Ngọc Sơn'), 'Hồ Gươm, Hà Nội');
  });

  test('ngày nhiều điểm chia link, mỗi link tối đa 4 điểm và nối tiếp', () {
    final routes = dayRoutes(['A', 'B', 'C', 'D', 'E']);
    expect(routes, hasLength(2));
    expect(Uri.parse(routes[1]).queryParameters['origin'], 'D');
    expect(Uri.parse(routes[1]).queryParameters['destination'], 'E');
  });

  test('đọc itinerary của lõi v2: tự tạo link từ tên điểm', () {
    final itinerary = itineraryFromJson(apiItinerary())!;
    final stops = itinerary.days.single.details;
    expect(itinerary.detailed, isTrue);
    expect(itinerary.perPersonVnd, 70000);
    expect(
      stops[1].facts,
      'đi 9 phút · tham quan 75 phút · vé 140.000đ · mở 08:00–17:00',
    );
    expect(
      Uri.parse(stops[0].mapsUrl!).queryParameters.containsKey('origin'),
      isFalse,
    );
    expect(
      Uri.parse(stops[1].mapsUrl!).queryParameters['origin'],
      'Lăng Chủ tịch Hồ Chí Minh, Hà Nội',
    );
    expect(itinerary.days.single.routeUrls, hasLength(1));
    expect(itinerary.days.single.weather, isNull);
  });

  test('ưu tiên link của máy chủ và đọc thời tiết khi có', () {
    final data = apiItinerary(weather: true);
    final day = ((data['days'] as List).single as Map<String, Object?>);
    day['maps_urls'] = ['https://www.google.com/maps/dir/?api=1&destination=x'];
    final itinerary = itineraryFromJson(data)!;
    expect(itinerary.days.single.routeUrls.single, endsWith('destination=x'));
    expect(itinerary.days.single.weather!.label, 'Mưa vừa, 20–25°C · mưa 80%');
    expect(itinerary.start, DateTime(2026, 12, 1));
    expect(itineraryFromJson(null), isNull);
    expect(itineraryFromJson({'days': []}), isNull);
    expect(itinerary.keyNotes, hasLength(2));
    expect(KeyNotes(notes: List.filled(6, 'x')).max, 4);
  });

  testWidgets(
    'thẻ lịch trình hiện giờ, số phút, vé, nút chỉ đường và nguồn thời tiết',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ItineraryCard(
                itinerary: itineraryFromJson(apiItinerary(weather: true))!,
                id: 'test',
                travel: TravelState(),
                detail: 'Lộ trình gợi ý',
              ),
            ),
          ),
        ),
      );
      expect(find.text('07:41'), findsOneWidget);
      expect(find.text('Ngày 1 · thứ Ba 01/12'), findsOneWidget);
      expect(find.textContaining('Mưa vừa, 20–25°C'), findsOneWidget);
      expect(find.byIcon(Icons.umbrella_outlined), findsOneWidget);
      expect(
        find.byTooltip('Chỉ đường đến Văn Miếu – Quốc Tử Giám'),
        findsOneWidget,
      );
      expect(find.text('Chỉ đường cả ngày'), findsOneWidget);
      expect(
        find.textContaining('Tổng vé 140.000đ (70.000đ/người)'),
        findsOneWidget,
      );
      expect(find.text('Weather data by Open-Meteo.com'), findsOneWidget);
      // Lưu ý quan trọng hiện thẳng trên thẻ, bỏ 2 câu luôn có; taxi ghi rõ chỉ tham khảo
      expect(find.text('Lưu ý'), findsOneWidget);
      expect(find.textContaining('Ngày 1 trống từ 12:08'), findsOneWidget);
      expect(find.textContaining('Xuất phát và về: Hàng Bạc'), findsOneWidget);
      expect(find.textContaining('Dữ liệu chỉ có 14 điểm'), findsNothing);
      expect(find.textContaining('(chỉ tham khảo)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
