import 'package:flutter/foundation.dart';

class Place {
  const Place(
    this.name,
    this.localName,
    this.district,
    this.category,
    this.tag,
    this.image,
    this.rating,
    this.reviews,
    this.duration,
    this.description,
  );

  final String name,
      localName,
      district,
      category,
      tag,
      image,
      rating,
      reviews,
      duration,
      description;
}

const lake = Place(
  'Hoan Kiem Lake',
  'Hồ Hoàn Kiếm Hồ Gươm',
  'Hoan Kiem Dist.',
  'Nature',
  'Lake',
  'lake.jpg',
  '4.8',
  '12.4k',
  '~ 1 hr',
  'Walk around the iconic lake, visit Ngoc Son Temple, and enjoy the morning vibe.',
);
const temple = Place(
  'Temple of Literature',
  'Văn Miếu Quốc Tử Giám',
  'Dong Da Dist.',
  'Culture',
  'Culture',
  'temple.jpg',
  '4.7',
  '8.9k',
  '~ 1.5 hrs',
  "Visit Vietnam's first university, a historic and cultural landmark.",
);
const quarter = Place(
  'Old Quarter',
  'Phố cổ Hà Nội',
  'Hoan Kiem Dist.',
  'Culture',
  'Culture',
  'quarter.jpg',
  '4.6',
  '15.2k',
  '~ 2 hrs',
  "Explore Hanoi's 36 streets, shop for local crafts, and try street food.",
);
const mausoleum = Place(
  'Ho Chi Minh Mausoleum',
  'Lăng Chủ tịch Hồ Chí Minh Lăng Bác',
  'Ba Dinh Dist.',
  'Historical',
  'Historical',
  'mausoleum.jpg',
  '4.8',
  '9.1k',
  '~ 1 hr',
  "Visit the mausoleum and walk across Ba Dinh Square.",
);
const food = Place(
  'Hanoi Street Food',
  'Ẩm thực Hà Nội Phở Bún Chả',
  'Hoan Kiem Dist.',
  'Food',
  'Food',
  'food.jpg',
  '',
  '',
  '~ 1 hr',
  'Try a bowl of pho in the Old Quarter.',
);
const pagoda = Place(
  'One Pillar Pagoda',
  'Chùa Một Cột',
  'Ba Dinh Dist.',
  'Historical',
  'Historical',
  'pavilion.jpg',
  '',
  '',
  '~ 30 min',
  'See the lotus-shaped pagoda near Ba Dinh Square.',
);
const places = [lake, temple, quarter, mausoleum];
const extraPlaces = [food, pagoda];

typedef Stop = (String time, Place place);
const homeDays = <List<Stop>>[
  [('08:00', lake), ('10:00', quarter), ('13:30', temple)],
  [('08:30', mausoleum), ('10:30', pagoda), ('12:00', food)],
  [('09:00', lake), ('11:00', food), ('14:00', quarter)],
];

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
  var text = value.toLowerCase().replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  for (final group in groups.entries) {
    text = text.replaceAll(RegExp('[${group.value}]'), group.key);
  }
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.stops,
    required this.image,
    this.preview,
  });

  final String id, name, image;
  final DateTime start, end;
  final int stops;
  final Itinerary? preview;

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

  String get dates {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    String format(DateTime date) => '${months[date.month - 1]} ${date.day}';
    return '${format(start)} – ${format(end)}, ${end.year}';
  }
}

final demoTrips = [
  Trip(
    id: 'culture',
    name: 'Hanoi 3 Days Cultural Trip',
    start: DateTime(2026, 12, 20),
    end: DateTime(2026, 12, 22),
    stops: 12,
    image: 'quarter.jpg',
  ),
  Trip(
    id: 'weekend',
    name: 'Hanoi Weekend Getaway',
    start: DateTime(2026, 11, 28),
    end: DateTime(2026, 11, 29),
    stops: 7,
    image: 'lake.jpg',
  ),
  Trip(
    id: 'food',
    name: 'Hanoi Food Tour',
    start: DateTime(2026, 11, 15),
    end: DateTime(2026, 11, 15),
    stops: 6,
    image: 'food.jpg',
  ),
  Trip(
    id: 'history',
    name: 'Historical Hanoi Tour',
    start: DateTime(2026, 10, 10),
    end: DateTime(2026, 10, 12),
    stops: 10,
    image: 'avenue.jpg',
  ),
];

class TravelState extends ChangeNotifier {
  final savedPlaces = <Place>{};
  final favorites = <String>{'weekend'};
  final trips = [...demoTrips];
  String accessCode = '';

  bool togglePlace(Place place) {
    final saved = savedPlaces.add(place);
    if (!saved) savedPlaces.remove(place);
    notifyListeners();
    return saved;
  }

  void toggleFavorite(String id) {
    if (!favorites.add(id)) favorites.remove(id);
    notifyListeners();
  }

  bool isSaved(String id) => trips.any((trip) => trip.id == id);

  void toggleTrip(String id, Itinerary itinerary) {
    if (isSaved(id)) {
      trips.removeWhere((trip) => trip.id == id);
      favorites.remove(id);
    } else {
      final now = DateTime.now();
      final start = itinerary.start ?? DateTime(now.year, now.month, now.day);
      final end = DateTime(
        start.year,
        start.month,
        start.day + itinerary.days.length - 1,
      );
      trips.insert(
        0,
        Trip(
          id: id,
          name: itinerary.title,
          start: start,
          end: end,
          stops: itinerary.days.fold(
            0,
            (count, day) => count + day.stops.length,
          ),
          image: 'lake.jpg',
          preview: itinerary,
        ),
      );
    }
    notifyListeners();
  }

  void reset() {
    savedPlaces.clear();
    favorites
      ..clear()
      ..add('weekend');
    trips
      ..clear()
      ..addAll(demoTrips);
    accessCode = '';
    notifyListeners();
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
  });
  final String name, arrive, reason;
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
  });
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
}

/// 120000 → "120.000đ".
String vnd(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return '$outđ';
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
