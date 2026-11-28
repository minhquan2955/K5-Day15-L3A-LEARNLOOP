import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:learnloop/travel_data.dart';

/// Backend giả trong bộ nhớ, cùng hình dạng JSON với server/crud.py.
/// [loggedIn] = false: phải đăng nhập bằng khach@example.com / mat-khau-1.
TravelState fakeTravel({bool loggedIn = true}) {
  final places = [
    {
      'id': 'ho_guom',
      'ten': 'Hồ Gươm – Đền Ngọc Sơn',
      'ten_khac': ['hồ gươm', 'hồ hoàn kiếm'],
      'quan': 'Hoàn Kiếm',
      'mo_ta': null,
      'anh': 'lake.jpg',
      'gio_mo': '07:00:00',
      'gio_dong': '18:00:00',
      'vi_do': 21.0307,
      'kinh_do': 105.8524,
      'phut_tham_quan': 60,
      'gia_ve_vnd': 50000,
      'so_thich': ['dao_pho', 'van_hoa'],
    },
    {
      'id': 'van_mieu',
      'ten': 'Văn Miếu – Quốc Tử Giám',
      'ten_khac': ['văn miếu'],
      'quan': 'Đống Đa',
      'mo_ta': null,
      'anh': 'temple.jpg',
      'gio_mo': '08:00:00',
      'gio_dong': '17:00:00',
      'vi_do': 21.0287,
      'kinh_do': 105.8355,
      'phut_tham_quan': 75,
      'gia_ve_vnd': 70000,
      'so_thich': ['di_tich', 'van_hoa'],
    },
  ];
  final saved = <String>[];
  final trips = <String, Map<String, dynamic>>{};
  var me = <String, dynamic>{
    'ten_hien_thi': 'Khách',
    'email': null,
    'so_dien_thoai': null,
  };
  var nextId = 0;

  Map<String, dynamic> summary(Map<String, dynamic> t) {
    final days = t['ngay'] as List;
    final start = DateTime.parse(t['ngay_bat_dau'] as String);
    return {
      ...t,
      'so_ngay': days.length,
      'ngay_ket_thuc': isoDate(start.add(Duration(days: days.length - 1))),
      'so_diem_dung': days.fold<int>(
        0,
        (n, d) => n + ((d as Map)['diem_dung'] as List).length,
      ),
      'yeu_thich': t['yeu_thich'] ?? false,
      'anh': null,
    };
  }

  final client = MockClient((request) async {
    if (!request.url.path.contains('/dang-') &&
        request.headers['Authorization'] != 'Bearer test-token') {
      return http.Response('{"detail": "Chưa đăng nhập"}', 401);
    }
    final path = request.url.path.replaceFirst('/api', '');
    final body = request.body.isEmpty
        ? null
        : jsonDecode(request.body) as Map<String, dynamic>;
    final parts = path.split('/');
    Object? out;
    switch ((request.method, parts.length > 2 ? '/${parts[1]}/' : path)) {
      case ('GET', '/dia-diem'):
        out = places;
      case ('GET', '/da-luu'):
        out = [
          for (final p in places)
            if (saved.contains(p['id'])) p,
        ];
      case ('PUT', '/da-luu/'):
        saved.add(parts[2]);
      case ('DELETE', '/da-luu/'):
        saved.remove(parts[2]);
      case ('POST', '/dang-nhap'):
        if (body!['email'] != 'khach@example.com' ||
            body['mat_khau'] != 'mat-khau-1') {
          return http.Response.bytes(
            utf8.encode('{"detail": "Sai email hoặc mật khẩu"}'),
            401,
          );
        }
        out = {'token': 'test-token', 'nguoi_dung': me};
      case ('POST', '/dang-xuat'):
        break;
      case ('GET', '/toi'):
        out = me;
      case ('PUT', '/toi'):
        out = me = body!;
      case ('GET', '/chuyen-di'):
        out = [for (final t in trips.values) summary(t)];
      case ('POST', '/chuyen-di'):
        final id = 'trip-${nextId++}';
        trips[id] = {...body!, 'id': id};
        out = summary(trips[id]!);
      case ('GET', '/chuyen-di/'):
        out = summary(trips[parts[2]]!);
      case ('PATCH', '/chuyen-di/'):
        trips[parts[2]]!.addAll(body!);
        out = summary(trips[parts[2]]!);
      case ('DELETE', '/chuyen-di/'):
        trips.remove(parts[2]);
      default:
        return http.Response('{"detail": "not found"}', 404);
    }
    return http.Response.bytes(
      out == null ? [] : utf8.encode(jsonEncode(out)),
      out == null ? 204 : 200,
    );
  });
  return TravelState(
    client: client,
    base: 'http://test',
    token: loggedIn ? 'test-token' : null,
  );
}
