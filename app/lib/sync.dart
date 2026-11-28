import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// UUID v4 ngẫu nhiên — mã ẩn danh theo máy (không gắn email, tên thật).
String newUuid([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// P0 — người dùng ẩn danh, đồng ý thu thập, sự kiện thao tác, lưu chuyến, check-in (API lưu trữ của máy chủ).
///
/// - `base == 'mock'` (chạy không máy chủ) → tắt hết.
/// - Sự kiện chỉ gửi khi người dùng đã đồng ý; không gửi nội dung câu hỏi, không gửi toạ độ.
/// - Lỗi mạng / máy chủ chưa bật lưu trữ (503) → bỏ qua, app vẫn chạy như cũ.
class Sync {
  Sync({required this.base, http.Client? client})
    : _client = client ?? http.Client();

  final String base;
  final http.Client _client;
  String accessCode = '';
  String? userId;

  /// null = chưa hỏi; true / false = lựa chọn của người dùng.
  bool? consent;
  final _queue = <Map<String, Object?>>[];
  Timer? _timer;

  static const maxQueue = 100, batch = 10;
  static const flushAfter = Duration(seconds: 15);
  static const _keyUser = 'll_user', _keyConsent = 'll_consent';

  bool get enabled => base != 'mock';
  bool get collecting => enabled && consent == true && userId != null;
  int get pending => _queue.length;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${base.replaceFirst(RegExp(r'/$'), '')}$path')
          .replace(queryParameters: query);

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    if (!enabled || userId == null) return null;
    try {
      final request = http.Request(method, _uri(path, query))
        ..headers.addAll({
          'Content-Type': 'application/json',
          if (accessCode.isNotEmpty) 'X-Access-Code': accessCode,
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on Exception {
      return null;
    }
  }

  /// Đọc (hoặc tạo) mã ẩn danh và lựa chọn đồng ý đã lưu trong trình duyệt.
  Future<void> init() async {
    if (!enabled) return;
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString(_keyUser);
    if (userId == null) {
      userId = newUuid();
      await prefs.setString(_keyUser, userId!);
    }
    consent = prefs.getBool(_keyConsent);
  }

  Future<void> setConsent(bool value) async {
    consent = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConsent, value);
    if (!value) _queue.clear();
    await _send(
      'POST',
      '/api/nguoi-dung',
      body: {'nguoi_dung': userId, 'dong_y': value},
    );
    if (value) log('doi_dong_y', {'dong_y': true});
  }

  /// Ghi một sự kiện (chỉ khi đã đồng ý). Gửi theo lô: đủ [batch] sự kiện hoặc sau [flushAfter].
  void log(
    String type, [
    Map<String, Object?> data = const {},
    String? tripId,
  ]) {
    if (!collecting) return;
    if (_queue.length >= maxQueue) _queue.removeAt(0);
    _queue.add({
      'loai': type,
      'luc': DateTime.now().toUtc().toIso8601String(),
      'chuyen_di': ?tripId,
      'du_lieu': data,
    });
    if (_queue.length >= batch) {
      unawaited(flush());
    } else {
      _timer ??= Timer(flushAfter, () => unawaited(flush()));
    }
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (!collecting || _queue.isEmpty) return;
    final events = List.of(_queue);
    _queue.clear();
    final ok = await _send(
      'POST',
      '/api/su-kien',
      body: {'nguoi_dung': userId, 'su_kien': events},
    );
    if (ok == null) {
      _queue.insertAll(0, events.take(maxQueue - _queue.length));
    }
  }

  /// Lưu chuyến lên máy chủ; trả mã chuyến (null nếu lưu trữ chưa bật).
  Future<String?> saveTrip(String title, Map<String, Object?> itinerary) async {
    final res = await _send(
      'POST',
      '/api/chuyen-di',
      body: {'nguoi_dung': userId, 'ten': title, 'itinerary': itinerary},
    );
    return res is Map ? res['chuyen_di'] as String? : null;
  }

  Future<void> deleteTrip(String tripId) => _send(
    'DELETE',
    '/api/chuyen-di/$tripId',
    query: {'nguoi_dung': '$userId'},
  );

  Future<bool> checkIn(String tripId, int day, int order, bool done) async =>
      await _send(
        'POST',
        '/api/chuyen-di/$tripId/xong',
        body: {
          'nguoi_dung': userId,
          'ngay_thu': day,
          'thu_tu': order,
          'xong': done,
        },
      ) !=
      null;

  Future<List<Map<String, Object?>>> loadTrips() async {
    final res = await _send(
      'GET',
      '/api/chuyen-di',
      query: {'nguoi_dung': '$userId'},
    );
    final list = res is Map ? res['chuyen_di'] : null;
    return list is List
        ? [
            for (final trip in list)
              if (trip is Map) trip.cast<String, Object?>(),
          ]
        : const [];
  }

  /// Danh sách điểm thật (dữ liệu mẫu của nhóm) cho Explore / "Thêm điểm".
  Future<List<Map<String, Object?>>> loadPlaces() async {
    final res = await _send('GET', '/api/diem');
    final list = res is Map ? res['diem'] : null;
    return list is List
        ? [
            for (final place in list)
              if (place is Map) place.cast<String, Object?>(),
          ]
        : const [];
  }

  /// Xoá mọi dữ liệu của người dùng trên máy chủ, rồi tạo mã ẩn danh mới và hỏi lại đồng ý.
  Future<bool> deleteMyData() async {
    final ok = await _send('DELETE', '/api/nguoi-dung/$userId') != null;
    _queue.clear();
    _timer?.cancel();
    _timer = null;
    final prefs = await SharedPreferences.getInstance();
    userId = newUuid();
    consent = null;
    await prefs.setString(_keyUser, userId!);
    await prefs.remove(_keyConsent);
    return ok;
  }
}
