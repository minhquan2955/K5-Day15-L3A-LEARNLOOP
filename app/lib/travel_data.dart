import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'sync.dart';

/// Gốc API: `--dart-define=API=` (rỗng) là cùng origin; `mock` (mặc định) chỉ áp dụng cho chat.
const apiBase = String.fromEnvironment('API', defaultValue: 'mock');
const maxTripDays = 14; // khớp MAX_TRIP_DAYS ở server/crud.py
const fallbackImage = ''; // Art vẽ khung trống

String hhmm(String? time) =>
    time == null || time.length < 5 ? '' : time.substring(0, 5);

String categoryOf(List<String> tags) => tags.contains('am_thuc')
    ? 'Ẩm thực'
    : tags.any(const {'lich_su', 'di_tich', 'bao_tang'}.contains)
    ? 'Lịch sử'
    : tags.contains('thien_nhien')
    ? 'Thiên nhiên'
    : 'Văn hoá';

/// 50000 → "50.000đ"
String vnd(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';

/// 28/11/2026
String dmy(DateTime d, {bool year = true}) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}'
    '${year ? '/${d.year}' : ''}';

String minutesText(int minutes) => minutes < 60
    ? '~ $minutes phút'
    : '~ ${minutes ~/ 60} giờ${minutes % 60 == 0 ? '' : ' ${minutes % 60} phút'}';

/// Giờ mở cửa dạng OpenStreetMap ("Mo-Su 08:00-17:00") → tiếng Việt ("T2-CN 08:00-17:00").
String osmHoursVi(String hours) => hours.replaceAllMapped(
  RegExp(r'\b(Mo|Tu|We|Th|Fr|Sa|Su|PH|off)\b'),
  (m) => const {
    'Mo': 'T2',
    'Tu': 'T3',
    'We': 'T4',
    'Th': 'T5',
    'Fr': 'T6',
    'Sa': 'T7',
    'Su': 'CN',
    'PH': 'ngày lễ',
    'off': 'nghỉ',
  }[m[0]]!,
);

/// Khung giờ ước lượng cho mỗi buổi (phút trong ngày).
const _buoiRange = {
  'sang': (6 * 60, 11 * 60),
  'trua': (11 * 60, 13 * 60),
  'chieu': (13 * 60, 18 * 60),
  'toi': (18 * 60, 23 * 60),
};

int? minutesOf(String? hhmmText) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmmText ?? '');
  return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
}

/// Cảnh báo khi giờ đến (hoặc buổi) của điểm dừng nằm ngoài giờ mở cửa; null nếu ổn hoặc chưa đủ dữ liệu.
String? hoursWarning(Place place, Map<String, dynamic> stop) {
  final open = minutesOf(place.opens), close = minutesOf(place.closes);
  if (open == null || close == null) return null;
  final at = minutesOf(stop['gio_den'] as String?);
  final inHours = at != null
      ? at >= open && at < close
      : switch (_buoiRange[stop['buoi']]) {
          (final from, final to) => from < close && to > open,
          null => true,
        };
  return inHours ? null : 'Ngoài giờ mở cửa (${place.opens}–${place.closes})';
}

class Place {
  const Place({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.district = 'Hà Nội',
    this.category = 'Văn hoá',
    this.image = fallbackImage,
    this.duration = '',
    this.description = '',
    this.about,
    this.address,
    this.website,
    this.openingHours,
    this.wikipediaUrl,
    this.imageCredit,
    this.opens = '',
    this.closes = '',
    this.priceVnd = 0,
    this.lat,
    this.lng,
  });

  factory Place.fromJson(Map<String, dynamic> j) {
    final tags = List<String>.from(j['so_thich'] as List);
    final minutes = j['phut_tham_quan'] as int;
    final price = j['gia_ve_vnd'] as int;
    return Place(
      id: j['id'] as String,
      name: j['ten'] as String,
      aliases: List<String>.from(j['ten_khac'] as List),
      district: j['quan'] as String? ?? 'Hà Nội',
      category: categoryOf(tags),
      image: j['anh'] as String? ?? fallbackImage,
      duration: minutesText(minutes),
      description:
          'Mở ${hhmm(j['gio_mo'] as String)}–${hhmm(j['gio_dong'] as String)} · '
          '${price == 0 ? 'Miễn phí' : 'Vé ${vnd(price)}'}',
      opens: hhmm(j['gio_mo'] as String),
      closes: hhmm(j['gio_dong'] as String),
      priceVnd: price,
      lat: (j['vi_do'] as num?)?.toDouble(),
      lng: (j['kinh_do'] as num?)?.toDouble(),
      about: j['mo_ta'] as String?,
      address: j['dia_chi'] as String?,
      website: j['website'] as String?,
      openingHours: j['gio_mo_cua_osm'] as String?,
      wikipediaUrl: j['wikipedia_url'] as String?,
      imageCredit: j['anh_ghi_cong'] as String?,
    );
  }

  final String id, name, district, category, image, duration, description;
  final String opens, closes;
  final int priceVnd;
  final double? lat, lng;
  bool get hasCoords => lat != null && lng != null;
  final List<String> aliases;
  final String? about,
      address,
      website,
      openingHours,
      wikipediaUrl,
      imageCredit;
  String get localName => aliases.join(' ');
  String get tag => category;
}

typedef Stop = (String time, Place place);

/// Khoảng cách đường chim bay giữa hai điểm (km), công thức haversine.
double haversineKm(Place a, Place b) {
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.lat! - a.lat!), dLng = rad(b.lng! - a.lng!);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.lat!)) *
          math.cos(rad(b.lat!)) *
          math.pow(math.sin(dLng / 2), 2);
  return 12742 * math.asin(math.sqrt(h));
}

/// Ước tính đi xe giữa hai điểm, cùng công thức với agent AI (codebase/tools.py):
/// đường vòng ×1,3, tốc độ 20 km/h, cộng 5 phút gửi xe/đi bộ. Không phải dữ liệu giao thông thật.
({double km, int minutes}) travelBetween(Place a, Place b) {
  final km = haversineKm(a, b) * 1.3;
  return (km: km, minutes: (km / 20 * 60).round() + 5);
}

String travelText(Place a, Place b) {
  final t = travelBetween(a, b);
  return '~${t.km.toStringAsFixed(1).replaceAll('.', ',')} km · ~${t.minutes} phút';
}

String _latLng(Place p) => '${p.lat},${p.lng}';

/// Mở một địa điểm trên Google Maps (Maps URLs chính thức, không cần API key).
Uri mapsPlaceUrl(Place p) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': _latLng(p),
});

/// Google Maps cho phép tối đa 9 điểm trung gian: điểm đầu + 9 + điểm cuối.
const maxMapsPoints = 11;

/// Lộ trình qua [stops] theo thứ tự. Chỉ một điểm thì chỉ đường từ vị trí hiện tại của người dùng.
Uri mapsDirectionsUrl(List<Place> stops, {String mode = 'driving'}) {
  final pts = stops.where((p) => p.hasCoords).take(maxMapsPoints).toList();
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    if (pts.length > 1) 'origin': _latLng(pts.first),
    'destination': _latLng(pts.last),
    if (pts.length > 2)
      'waypoints': pts.sublist(1, pts.length - 1).map(_latLng).join('|'),
    'travelmode': mode,
  });
}

String searchable(String value) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  var text = value.toLowerCase().replaceAll(RegExp(r'[̀-ͯ]'), '');
  for (final group in groups.entries) {
    text = text.replaceAll(RegExp('[${group.value}]'), group.key);
  }
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.stops,
    required this.image,
    this.favorite = false,
  });

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
    id: j['id'] as String,
    name: j['ten'] as String,
    start: DateTime.parse(j['ngay_bat_dau'] as String),
    end: DateTime.parse(j['ngay_ket_thuc'] as String),
    stops: j['so_diem_dung'] as int,
    image: j['anh'] as String? ?? fallbackImage,
    favorite: j['yeu_thich'] as bool,
  );

  final String id, name, image;
  final DateTime start, end;
  final int stops;
  final bool favorite;

  int get days =>
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;

  bool completed(DateTime now) => DateTime(
    end.year,
    end.month,
    end.day,
  ).isBefore(DateTime(now.year, now.month, now.day));

  String get dates =>
      days == 1 ? dmy(start) : '${dmy(start, year: false)} – ${dmy(end)}';
}

/// Chuyến đi kèm lịch trình đầy đủ (GET /api/chuyen-di/{id}); `days` giữ điểm dừng dạng JSON để gửi lại khi sửa.
class TripDetail {
  TripDetail(this.trip, this.days);
  factory TripDetail.fromJson(Map<String, dynamic> j) =>
      TripDetail(Trip.fromJson(j), [
        for (final day in j['ngay'] as List)
          [
            for (final stop in (day as Map)['diem_dung'] as List)
              Map<String, dynamic>.from(stop as Map),
          ],
      ]);
  final Trip trip;
  final List<List<Map<String, dynamic>>> days;
}

class Profile {
  const Profile(this.name, this.email, this.phone, {this.admin = false});
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    j['ten_hien_thi'] as String,
    j['email'] as String? ?? '',
    j['so_dien_thoai'] as String? ?? '',
    admin: j['quan_tri'] as bool? ?? false,
  );
  final String name, email, phone;
  final bool admin;
}

class ApiError implements Exception {
  const ApiError(this.message);
  final String message;
  @override
  String toString() => message;
}

const _buoi = {'Sáng': 'sang', 'Trưa': 'trua', 'Chiều': 'chieu', 'Tối': 'toi'};
const buoiLabel = {
  'sang': 'Sáng',
  'trua': 'Trưa',
  'chieu': 'Chiều',
  'toi': 'Tối',
};

/// Dữ liệu người dùng, đọc/ghi qua CRUD API ở server/crud.py.
class TravelState extends ChangeNotifier {
  TravelState({http.Client? client, String? base, this.token})
    : client = client ?? http.Client(),
      base = (base ?? (apiBase == 'mock' ? '' : apiBase)).replaceFirst(
        RegExp(r'/$'),
        '',
      );

  final http.Client client;
  final String base;
  String? token;
  bool restoring = false;
  bool get loggedIn => token != null;
  List<Place> places = [];
  final savedPlaces = <String>{};
  List<Trip> trips = [];
  Profile? profile;
  TripDetail? current; // chuyến hiện trên Home
  String? _openId; // chuyến người dùng chọn mở trên Home
  bool loading = false;
  String? loadError;
  /// P0: đồng bộ ẩn danh với máy chủ (tắt ở chế độ mock). main.dart gắn bản thật.
  Sync sync = Sync(base: 'mock');

  /// Chuyến trong app → mã chuyến P0 trên máy chủ (rỗng khi chuyến lưu qua API có đăng nhập).
  final serverTrips = <String, String>{};

  /// Điểm đã check-in "Đã xong": '$tripId|$ngày|$thứ tự'.
  final done = <String>{};
  String _accessCode = '';
  String get accessCode => _accessCode;
  set accessCode(String value) {
    _accessCode = value;
    sync.accessCode = value;
  }

  void changed() => notifyListeners();

  bool isDone(String tripId, int day, int order) =>
      done.contains('$tripId|$day|$order');

  /// Check-in / bỏ check-in một điểm; đồng bộ nếu chuyến có mã P0, ghi sự kiện nếu người dùng đồng ý.
  void toggleDone(String tripId, int day, int order, {String? placeId}) {
    final key = '$tripId|$day|$order';
    final now = done.add(key);
    if (!now) done.remove(key);
    notifyListeners();
    final serverId = serverTrips[tripId];
    if (serverId != null) unawaited(sync.checkIn(serverId, day, order, now));
    sync.log('xong_diem', {
      'dia_diem_id': ?placeId,
      'ngay_thu': day,
      'thu_tu': order,
      'xong': now,
    }, serverId);
  }

  /// Quên dữ liệu P0 ở máy (sau khi "Xoá dữ liệu của tôi").
  void forgetServerTrips() {
    for (final id in serverTrips.keys) {
      done.removeWhere((key) => key.startsWith('$id|'));
    }
    serverTrips.clear();
    notifyListeners();
  }
  final _chatTrips =
      <String, String>{}; // id tin nhắn chat → id chuyến đi đã lưu
  final _errors = StreamController<String>.broadcast();
  Stream<String> get errors => _errors.stream;

  Future<dynamic> call(String method, String path, [Object? body]) async {
    final request = http.Request(method, Uri.parse('$base/api$path'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(
      await client.send(request).timeout(const Duration(seconds: 20)),
    );
    final text = utf8.decode(response.bodyBytes);
    final data = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode == 401 && token != null) {
      await _endSession();
      throw const ApiError('Phiên đăng nhập đã hết hạn, hãy đăng nhập lại.');
    }
    if (response.statusCode >= 300) {
      final detail = data is Map ? data['detail'] : null;
      throw ApiError(
        detail is String
            ? detail
            : 'Máy chủ trả về lỗi ${response.statusCode}.',
      );
    }
    return data;
  }

  /// Chạy một thao tác ghi; lỗi thì báo qua [errors] và trả false.
  Future<bool> _write(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      _errors.add(e is ApiError ? e.message : 'Không kết nối được máy chủ.');
      return false;
    } finally {
      notifyListeners();
    }
  }

  Place? placeById(String? id) =>
      places.where((place) => place.id == id).firstOrNull;

  Future<void> load() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final [placeList, saved, tripList, me] = await Future.wait([
        call('GET', '/dia-diem'),
        call('GET', '/da-luu'),
        call('GET', '/chuyen-di'),
        call('GET', '/toi'),
      ]);
      places = [
        for (final p in placeList as List)
          Place.fromJson(p as Map<String, dynamic>),
      ];
      savedPlaces
        ..clear()
        ..addAll([for (final p in saved as List) (p as Map)['id'] as String]);
      trips = [
        for (final t in tripList as List)
          Trip.fromJson(t as Map<String, dynamic>),
      ];
      profile = Profile.fromJson(me as Map<String, dynamic>);
      await _loadCurrent();
    } catch (e) {
      loadError = e is ApiError ? e.message : 'Không kết nối được máy chủ.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> _reloadTrips() async {
    trips = [
      for (final t in await call('GET', '/chuyen-di') as List)
        Trip.fromJson(t as Map<String, dynamic>),
    ];
    await _loadCurrent();
  }

  /// Home hiện chuyến đang mở; chưa mở chuyến nào thì chuyến sắp tới gần nhất, rồi đến chuyến mới nhất.
  Future<void> _loadCurrent() async {
    final now = DateTime.now();
    final upcoming = trips.where((t) => !t.completed(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final pick =
        trips.where((t) => t.id == _openId).firstOrNull ??
        upcoming.firstOrNull ??
        trips.firstOrNull;
    current = pick == null
        ? null
        : TripDetail.fromJson(
            await call('GET', '/chuyen-di/${pick.id}') as Map<String, dynamic>,
          );
  }

  bool isPlaceSaved(Place place) => savedPlaces.contains(place.id);

  Future<bool> togglePlace(Place place) {
    final save = !savedPlaces.contains(place.id);
    return _write(() async {
      await call(save ? 'PUT' : 'DELETE', '/da-luu/${place.id}');
      save ? savedPlaces.add(place.id) : savedPlaces.remove(place.id);
    });
  }

  Future<bool> updateTrip(String id, Map<String, dynamic> changes) =>
      _write(() async {
        await call('PATCH', '/chuyen-di/$id', changes);
        await _reloadTrips();
      });

  Future<bool> toggleFavorite(Trip trip) =>
      updateTrip(trip.id, {'yeu_thich': !trip.favorite});

  Future<bool> deleteTrip(String id) => _write(() async {
    await call('DELETE', '/chuyen-di/$id');
    _chatTrips.removeWhere((_, tripId) => tripId == id);
    await _reloadTrips();
  });

  Future<bool> openTrip(String id) => _write(() async {
    _openId = id;
    await _loadCurrent();
  });

  /// Tạo chuyến trống [days] ngày; điểm dừng thêm sau trên Home.
  Future<bool> createTrip(String name, DateTime start, int days) =>
      _write(() async {
        final trip = await call('POST', '/chuyen-di', {
          'ten': name,
          'ngay_bat_dau': isoDate(start),
          'ngay': [
            for (var i = 0; i < days; i++) {'diem_dung': <Object>[]},
          ],
        });
        _openId = (trip as Map)['id'] as String;
        await _reloadTrips();
      });

  /// Thay toàn bộ điểm dừng của một ngày trong chuyến [current].
  Future<bool> setDayStops(int day, List<Map<String, dynamic>> stops) =>
      setDays([
        for (var i = 0; i < current!.days.length; i++)
          i == day ? stops : current!.days[i],
      ]);

  /// Đổi số ngày của chuyến [current]; bớt ngày thì bỏ điểm dừng của các ngày cuối.
  Future<bool> setDayCount(int count) => setDays([
    for (var i = 0; i < count; i++)
      i < current!.days.length ? current!.days[i] : const [],
  ]);

  /// Thêm [place] vào cuối ngày [day] của chuyến [current].
  Future<bool> addPlace(int day, Place place) => setDayStops(day, [
    ...current!.days[day],
    {'ten_luc_luu': place.name, 'dia_diem_id': place.id},
  ]);

  /// Ghi lại toàn bộ lịch trình của chuyến [current] (mỗi phần tử là điểm dừng của một ngày).
  Future<bool> setDays(List<List<Map<String, dynamic>>> stopsByDay) {
    const keep = {
      'ten_luc_luu',
      'dia_diem_id',
      'gio_den',
      'buoi',
      'phut_di_chuyen',
      'phut_tham_quan',
      'tien_ve_nhom_vnd',
      'ly_do',
    };
    final days = [
      for (final stops in stopsByDay)
        {
          'diem_dung': [
            for (final stop in stops)
              {
                for (final e in stop.entries)
                  if (keep.contains(e.key)) e.key: e.value,
              },
          ],
        },
    ];
    return updateTrip(current!.trip.id, {'ngay': days});
  }

  Future<bool> updateProfile(String name, String email, String phone) =>
      _write(() async {
        profile = Profile.fromJson(
          await call('PUT', '/toi', {
            'ten_hien_thi': name.trim(),
            'email': email.trim(),
            'so_dien_thoai': phone.trim().isEmpty ? null : phone.trim(),
          }) as Map<String, dynamic>,
        );
      });

  bool isSaved(String chatId) => _chatTrips.containsKey(chatId);

  Future<bool> toggleTrip(String chatId, Itinerary itinerary) {
    final saved = _chatTrips[chatId];
    if (saved != null) return deleteTrip(saved);
    final now = DateTime.now();
    final start = itinerary.start ?? DateTime(now.year, now.month, now.day);
    return _write(() async {
      final trip = await call('POST', '/chuyen-di', {
        'ten': itinerary.title,
        'ngay_bat_dau': isoDate(start),
        'ngay': [
          for (final day in itinerary.days)
            {
              'diem_dung': [
                for (final (label, name) in day.stops) _stopJson(label, name),
              ],
            },
        ],
      });
      _chatTrips[chatId] = (trip as Map)['id'] as String;
      await _reloadTrips();
    });
  }

  Map<String, dynamic> _stopJson(String label, String name) {
    final time = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(label);
    final key = ' ${searchable(name)} ';
    final place = places
        .where(
          (p) => [
            p.name,
            ...p.aliases,
          ].any((alias) => key.contains(' ${searchable(alias)} ')),
        )
        .firstOrNull;
    return {
      'ten_luc_luu': name,
      'dia_diem_id': place?.id,
      if (time != null)
        'gio_den': '${time[1]!.padLeft(2, '0')}:${time[2]}'
      else if (_buoi[label] != null)
        'buoi': _buoi[label],
    };
  }

  static const _tokenKey = 'learnloop_token';

  /// Đọc token đã lưu (nếu có) rồi tải dữ liệu.
  Future<void> restore() async {
    if (token == null) {
      restoring = true;
      notifyListeners();
      token = (await SharedPreferences.getInstance()).getString(_tokenKey);
      restoring = false;
    }
    if (token != null) await load();
    notifyListeners();
  }

  /// Trả thông báo lỗi, hoặc null khi đăng nhập/đăng ký thành công.
  Future<String?> signIn(String email, String password, {String? name}) async {
    try {
      final data = await call(
        'POST',
        name == null ? '/dang-nhap' : '/dang-ky',
        {
          'email': email.trim(),
          'mat_khau': password,
          'ten_hien_thi': ?name?.trim(),
        },
      ) as Map<String, dynamic>;
      token = data['token'] as String;
      await (await SharedPreferences.getInstance()).setString(
        _tokenKey,
        token!,
      );
      await load();
      return null;
    } on ApiError catch (e) {
      return e.message;
    } catch (_) {
      return 'Không kết nối được máy chủ.';
    }
  }

  Future<void> signOut() async {
    try {
      await call('POST', '/dang-xuat');
    } catch (_) {} // vẫn xoá phiên ở máy dù server không phản hồi
    await _endSession();
  }

  Future<void> _endSession() async {
    token = null;
    accessCode = '';
    serverTrips.clear();
    done.clear();
    places = [];
    savedPlaces.clear();
    trips = [];
    profile = null;
    current = null;
    _chatTrips.clear();
    await (await SharedPreferences.getInstance()).remove(_tokenKey);
    notifyListeners();
  }

  @override
  void dispose() {
    _errors.close();
    client.close();
    super.dispose();
  }
}

typedef ItineraryStop = (String label, String name);

/// Một điểm trong lịch do API trả về. Mọi số do công cụ phía máy chủ tính.
class StopDetail {
  const StopDetail({
    required this.name,
    required this.arrive,
    this.travelMin,
    this.visitMin,
    this.ticketVnd,
    this.open,
    this.close,
    this.reason = '',
    this.mapsUrl,
    this.placeId,
  });
  final String name, arrive, reason;
  final String? placeId;
  final int? travelMin, visitMin, ticketVnd;
  final String? open, close, mapsUrl;

  String get facts => [
    if (travelMin != null) 'đi $travelMin phút',
    if (visitMin != null) 'tham quan $visitMin phút',
    if (ticketVnd != null) 'vé ${vnd(ticketVnd!)}',
    if (open != null && close != null) 'mở $open–$close',
  ].join(' · ');
}

/// Dự báo một ngày (Open-Meteo), có khi máy chủ biết ngày đi.
class DayWeather {
  const DayWeather(this.summary, this.low, this.high, this.rainChance);
  final String summary;
  final int low, high;
  final int? rainChance;

  String get label =>
      '$summary, $low–$high°C${rainChance == null ? '' : ' · mưa $rainChance%'}';
}

class ItineraryDay {
  const ItineraryDay(
    this.stops,
    this.image, {
    this.details = const [],
    this.routeUrls = const [],
    this.weather,
    this.date,
  });
  final List<ItineraryStop> stops;
  final String image;
  final List<StopDetail> details;
  final List<String> routeUrls;
  final DayWeather? weather;
  final DateTime? date;
}

class Itinerary {
  const Itinerary(
    this.title,
    this.tags,
    this.days, {
    this.start,
    this.feasible = true,
    this.notes = const [],
    this.totalVnd,
    this.perPersonVnd,
    this.taxiVnd,
    this.source,
  });

  /// JSON `itinerary` gốc từ máy chủ (để lưu chuyến lên máy chủ đúng như đã nhận).
  final Map<String, Object?>? source;
  final String title, tags;
  final List<ItineraryDay> days;
  final DateTime? start;
  final bool feasible;
  final List<String> notes;
  final int? totalVnd, perPersonVnd, taxiVnd;
  String get duration => days.length == 1
      ? '1 ngày'
      : '${days.length} ngày ${days.length - 1} đêm';
  bool get detailed => days.any((day) => day.details.isNotEmpty);

  /// Lưu ý đáng hiện thẳng trên thẻ: bỏ 2 câu luôn có (giới hạn dữ liệu mẫu, nguồn thời tiết — đã có link riêng).
  List<String> get keyNotes => [
    for (final note in notes)
      if (!note.startsWith('Dữ liệu chỉ có') &&
          !note.startsWith('Dự báo thời tiết từ'))
        note,
  ];
}

/// Tên điểm để Google Maps tìm: bỏ phần sau " – " ("Văn Miếu – Quốc Tử Giám" → "Văn Miếu"), thêm ", Hà Nội".
String mapsPlace(String name) => '${name.split(' – ').first.trim()}, Hà Nội';

/// Link chỉ đường Google Maps (Maps URLs, không cần API key). Không có [origin] thì đi từ vị trí của máy.
String mapsDirections(List<String> places, {String? origin}) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': ?origin,
      'destination': places.last,
      if (places.length > 1)
        'waypoints': places.sublist(0, places.length - 1).join('|'),
      'travelmode': 'driving',
    }).toString();

/// Trình duyệt di động chỉ nhận 3 điểm dừng giữa đường: mỗi link tối đa 4 điểm, link sau nối tiếp link trước.
List<String> dayRoutes(List<String> places) => [
  for (var i = 0; i < places.length; i += 4)
    mapsDirections(
      places.sublist(i, i + 4 > places.length ? places.length : i + 4),
      origin: i == 0 ? null : places[i - 1],
    ),
];

int? _int(Object? value) => value is num ? value.round() : null;
String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Đọc `itinerary` từ `/api/plan`. Trường nào thiếu thì bỏ qua; ưu tiên link do máy chủ tạo.
Itinerary? itineraryFromJson(
  Object? data, {
  List<String> images = const ['temple.jpg', 'quarter.jpg', 'lake.jpg'],
}) {
  if (data is! Map || data['days'] is! List) return null;
  final days = <ItineraryDay>[];
  for (final day in data['days'] as List) {
    if (day is! Map || day['stops'] is! List) continue;
    final details = <StopDetail>[];
    String? previous;
    for (final stop in day['stops'] as List) {
      if (stop is! Map) continue;
      final name = '${stop['name'] ?? ''}';
      final place = mapsPlace(name);
      details.add(
        StopDetail(
          name: name,
          placeId: _text(stop['id']),
          arrive: '${stop['arrive'] ?? ''}',
          travelMin: _int(stop['travel_min_from_prev']),
          visitMin: _int(stop['visit_min']),
          ticketVnd: _int(stop['ticket_vnd']),
          open: _text(stop['mo']),
          close: _text(stop['dong']),
          reason: _text(stop['reason']) ?? '',
          mapsUrl:
              _text(stop['maps_url']) ??
              mapsDirections([place], origin: previous),
        ),
      );
      previous = place;
    }
    if (details.isEmpty) continue;
    final weather = day['weather'];
    final serverRoutes = day['maps_urls'];
    days.add(
      ItineraryDay(
        [for (final stop in details) (stop.arrive, stop.name)],
        images[days.length % images.length],
        details: details,
        routeUrls: serverRoutes is List && serverRoutes.isNotEmpty
            ? [for (final url in serverRoutes) '$url']
            : dayRoutes([for (final stop in details) mapsPlace(stop.name)]),
        weather: weather is Map && weather['mo_ta'] is String
            ? DayWeather(
                weather['mo_ta'] as String,
                _int(weather['nhiet_do_thap']) ?? 0,
                _int(weather['nhiet_do_cao']) ?? 0,
                _int(weather['kha_nang_mua']),
              )
            : null,
        date: DateTime.tryParse('${day['date'] ?? ''}'),
      ),
    );
  }
  if (days.isEmpty) return null;
  final notes = data['notes'];
  return Itinerary(
    'Hà Nội ${days.length} ngày${days.length > 1 ? ' ${days.length - 1} đêm' : ''}',
    '',
    days,
    start: days.first.date,
    feasible: data['feasible'] != false,
    notes: notes is List ? [for (final note in notes) '$note'] : const [],
    totalVnd: _int(data['total_vnd']),
    perPersonVnd: _int(data['per_person_vnd']),
    taxiVnd: _int(data['taxi_vnd']),
    source: Map<String, Object?>.from(data),
  );
}

const sampleItinerary = Itinerary(
  'Hà Nội 2 ngày 1 đêm',
  'Văn hóa · Ẩm thực · Check-in',
  [
    ItineraryDay([
      ('Sáng', 'Hồ Hoàn Kiếm – Đền Ngọc Sơn'),
      ('Trưa', 'Thưởng thức bún chả & nem rán'),
      ('Chiều', 'Văn Miếu – Quốc Tử Giám'),
      ('Tối', 'Phố cổ Hà Nội – Ăn vặt & dạo đêm'),
    ], 'temple.jpg'),
    ItineraryDay([
      ('Sáng', 'Lăng Chủ tịch Hồ Chí Minh – Quảng trường Ba Đình'),
      ('Trưa', 'Phở Hà Nội'),
      ('Chiều', 'Bảo tàng Dân tộc học Việt Nam'),
      ('Tối', 'Trở về'),
    ], 'quarter.jpg'),
  ],
);
