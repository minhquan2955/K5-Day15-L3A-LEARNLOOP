import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnloop/chat.dart';
import 'package:learnloop/sync.dart';
import 'package:learnloop/travel_data.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const tripServerId = 'c0ffee00-0000-4000-8000-000000000001';

http.Response json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

Map<String, Object?> planJson() => {
  'days': [
    {
      'day': 1,
      'date': '2026-11-29',
      'stops': [
        {
          'id': 'van_mieu',
          'name': 'Văn Miếu – Quốc Tử Giám',
          'arrive': '08:00',
          'visit_min': 75,
          'travel_min_from_prev': 11,
          'ticket_vnd': 70000,
          'reason': '',
        },
      ],
    },
  ],
  'feasible': true,
  'total_vnd': 70000,
  'per_person_vnd': 70000,
  'taxi_vnd': 62000,
  'notes': <String>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<http.Request> calls;
  var status = 200;

  MockClient server() => MockClient((request) async {
    calls.add(request);
    if (status != 200) return json({'detail': 'Chưa bật lưu trữ'}, status);
    final path = request.url.path;
    if (path == '/api/chuyen-di' && request.method == 'POST') {
      return json({'chuyen_di': tripServerId, 'diem': []});
    }
    if (path == '/api/chuyen-di' && request.method == 'GET') {
      final saved = planJson();
      ((saved['days'] as List).first as Map)['stops'] = [
        {
          ...(((planJson()['days'] as List).first as Map)['stops'] as List)
                  .first
              as Map,
          'xong_luc': '2026-11-29T09:20:00+07:00',
        },
      ];
      return json({
        'chuyen_di': [
          {
            'chuyen_di': tripServerId,
            'ten': 'Hà Nội 1 ngày',
            'itinerary': saved,
          },
        ],
      });
    }
    return json({'ok': true});
  });

  List<Map<String, Object?>> bodies(String path) => [
    for (final call in calls)
      if (call.url.path == path)
        (jsonDecode(call.body) as Map).cast<String, Object?>(),
  ];

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    calls = [];
    status = 200;
    SharedPreferences.setMockInitialValues({});
  });

  test('UUID v4 đúng dạng, mỗi lần một mã', () {
    final a = newUuid(), b = newUuid();
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(a),
      isTrue,
    );
    expect(a, isNot(b));
  });

  test('mã ẩn danh tạo một lần rồi giữ lại trong trình duyệt', () async {
    final first = Sync(base: '', client: server());
    await first.init();
    final again = Sync(base: '', client: server());
    await again.init();
    expect(first.userId, isNotNull);
    expect(again.userId, first.userId);
    expect(again.consent, isNull);
  });

  test('chế độ mock: tắt hết, không gọi máy chủ', () async {
    final sync = Sync(base: 'mock', client: server());
    await sync.init();
    sync.log('mo_man_hinh', {'man': 'chat'});
    await sync.flush();
    expect(sync.enabled, isFalse);
    expect(calls, isEmpty);
  });

  test('chưa đồng ý thì không ghi, không gửi sự kiện', () async {
    final sync = Sync(base: '', client: server());
    await sync.init();
    sync.log('mo_man_hinh', {'man': 'chat'});
    await sync.flush();
    expect(sync.pending, 0);
    expect(bodies('/api/su-kien'), isEmpty);
  });

  test('đồng ý: đăng ký người dùng, gửi sự kiện theo lô', () async {
    final sync = Sync(base: '', client: server());
    await sync.init();
    await sync.setConsent(true);
    expect(bodies('/api/nguoi-dung').single, {
      'nguoi_dung': sync.userId,
      'dong_y': true,
    });
    for (var i = 0; i < Sync.batch - 1; i++) {
      sync.log('bam_chi_duong', {'cap': 'ngay'});
    }
    await settle();
    final batch = bodies('/api/su-kien').single['su_kien'] as List;
    expect(batch, hasLength(Sync.batch));
    expect((batch.first as Map)['loai'], 'doi_dong_y');
    expect((batch.last as Map)['du_lieu'], {'cap': 'ngay'});
    expect(sync.pending, 0);
  });

  test(
    'máy chủ chưa bật lưu trữ (503): không lỗi, giữ sự kiện để gửi lại',
    () async {
      final sync = Sync(base: '', client: server());
      await sync.init();
      status = 503;
      await sync.setConsent(true);
      sync.log('xem_chi_tiet');
      await sync.flush();
      expect(sync.pending, 2);
      expect(await sync.saveTrip('x', planJson()), isNull);
    },
  );

  testWidgets(
    'mở chat (gọi máy chủ) lần đầu thì hỏi đồng ý; nút Đã xong đổi trạng thái',
    (tester) async {
      final travel = TravelState()..sync = Sync(base: '', client: server());
      await tester.runAsync(travel.sync.init);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            travel: travel,
            repository: const ApiChatRepository(''),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Giúp cải thiện gợi ý?'), findsOneWidget);
      await tester.tap(find.text('Đồng ý'));
      await tester.runAsync(settle);
      await tester.pumpAndSettle();
      expect(travel.sync.consent, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayPlan(
              index: 1,
              day: itineraryFromJson(planJson())!.days.single,
              tripId: 'chat-9',
              travel: travel,
            ),
          ),
        ),
      );
      final button = find.byTooltip('Đánh dấu đã xong Văn Miếu – Quốc Tử Giám');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(travel.isDone('chat-9', 1, 1), isTrue);
      expect(
        find.byTooltip('Bỏ đánh dấu đã xong Văn Miếu – Quốc Tử Giám'),
        findsOneWidget,
      );
      await tester.runAsync(
        travel.sync.flush,
      ); // gửi lô sự kiện còn chờ (huỷ hẹn giờ 15 giây)
      expect(
        bodies('/api/su-kien')
            .expand((b) => b['su_kien'] as List)
            .map((e) => (e as Map)['loai']),
        // mở chat xảy ra TRƯỚC khi đồng ý → không được ghi
        ['doi_dong_y', 'xong_diem'],
      );
    },
  );
}
