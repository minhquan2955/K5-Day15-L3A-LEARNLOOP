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

class ItineraryDay {
  const ItineraryDay(this.stops, this.image);
  final List<ItineraryStop> stops;
  final String image;
}

class Itinerary {
  const Itinerary(this.title, this.tags, this.days, {this.start});
  final String title, tags;
  final List<ItineraryDay> days;
  final DateTime? start;
  String get duration => days.length == 1
      ? '1 ngày'
      : '${days.length} ngày ${days.length - 1} đêm';
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
