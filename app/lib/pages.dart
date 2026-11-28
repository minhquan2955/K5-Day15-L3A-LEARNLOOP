import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';
import 'travel_data.dart';

Future<void> openMaps(BuildContext context, Uri url) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Không mở được Google Maps.')),
    );
  }
}

/// Trạng thái tải chung: đang tải / lỗi kèm nút thử lại; null khi đã có dữ liệu.
Widget? loadStatus(TravelState travel) => travel.loading
    ? const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      )
    : travel.loadError == null
    ? null
    : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(travel.loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Pill('Thử lại', icon: Icons.refresh, onTap: travel.load),
          ],
        ),
      );

Future<String?> askText(
  BuildContext context,
  String title,
  String initial,
) async {
  var value = initial;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: initial,
        autofocus: true,
        onChanged: (text) => value = text,
        onFieldSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(value),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  return result == null || result.trim().isEmpty ? null : result.trim();
}

/// Nút −/+ chọn số ngày (1..[maxTripDays]).
class DayStepper extends StatelessWidget {
  const DayStepper({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton.outlined(
        tooltip: 'Bớt một ngày',
        onPressed: value > 1 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove),
      ),
      SizedBox(
        width: 90,
        child: Text(
          '$value ngày',
          textAlign: TextAlign.center,
          style: display(18),
        ),
      ),
      IconButton.outlined(
        tooltip: 'Thêm một ngày',
        onPressed: value < maxTripDays ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add),
      ),
    ],
  );
}

/// Hộp thoại chọn số ngày; trả null nếu huỷ. Bớt ngày thì cảnh báo mất điểm dừng.
Future<int?> askDayCount(BuildContext context, int current) {
  var count = current;
  return showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Số ngày'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DayStepper(
              value: count,
              onChanged: (n) => setState(() => count = n),
            ),
            if (count < current)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Các điểm dừng của những ngày cuối sẽ bị xoá.',
                  style: TextStyle(color: Color(0xffa3321b)),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(count),
            child: const Text('Xong'),
          ),
        ],
      ),
    ),
  );
}

Future<void> tripOptions(
  BuildContext context,
  TravelState travel,
  Trip trip,
) => sheet<void>(
  context,
  trip.name,
  body: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        leading: const Icon(Icons.edit_outlined, color: brown),
        title: const Text('Đổi tên'),
        onTap: () async {
          final name = await askText(context, 'Đổi tên chuyến đi', trip.name);
          if (name != null) await travel.updateTrip(trip.id, {'ten': name});
          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        },
      ),
      ListTile(
        leading: const Icon(Icons.calendar_month_outlined, color: brown),
        title: const Text('Đổi ngày bắt đầu'),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: trip.start,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            await travel.updateTrip(trip.id, {'ngay_bat_dau': isoDate(date)});
          }
          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        },
      ),
      ListTile(
        leading: const Icon(Icons.view_day_outlined, color: brown),
        title: const Text('Số ngày'),
        subtitle: Text('${trip.days} ngày'),
        onTap: () async {
          final count = await askDayCount(context, trip.days);
          if (count != null && count != trip.days) {
            await travel.openTrip(trip.id);
            await travel.setDayCount(count);
          }
          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        },
      ),
      ListTile(
        leading: const Icon(Icons.delete_outline, color: brown),
        title: const Text('Xoá chuyến đi'),
        onTap: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Xoá chuyến đi'),
              content: Text('Xoá "${trip.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Huỷ'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Xoá'),
                ),
              ],
            ),
          );
          if (ok == true) await travel.deleteTrip(trip.id);
          if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    ],
  ),
);

/// Tạo trip thủ công: tên, ngày bắt đầu, số ngày (1–3). Xong thì mở trip trên Home.
Future<void> createTripDialog(BuildContext context, TravelState travel) async {
  var name = '';
  final today = DateTime.now();
  var start = DateTime(today.year, today.month, today.day);
  var days = 1;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Chuyến đi mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Tên chuyến đi'),
              onChanged: (text) => name = text,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Bắt đầu: ${dmy(start)}'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  helpText: 'Chọn ngày bắt đầu',
                  cancelText: 'Huỷ',
                  confirmText: 'Xong',
                  initialDate: start,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => start = picked);
              },
            ),
            const SizedBox(height: 12),
            DayStepper(value: days, onChanged: (n) => setState(() => days = n)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tạo'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  if (name.trim().isEmpty) name = 'Hà Nội $days ngày';
  if (await travel.createTrip(name.trim(), start, days) && context.mounted) {
    context.go('/');
  }
}

/// Hỏi tạo trip thủ công hay nhờ AI.
Future<void> newTripSheet(BuildContext context, TravelState travel) =>
    sheet<void>(
      context,
      'Tạo chuyến đi',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined, color: brown),
            title: const Text('Tự tạo'),
            subtitle: const Text('Chọn ngày rồi tự thêm điểm dừng'),
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              createTripDialog(context, travel);
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome, color: brown),
            title: const Text('Nhờ AI lên lịch'),
            onTap: () {
              Navigator.of(context, rootNavigator: true).pop();
              context.push('/ai');
            },
          ),
        ],
      ),
    );

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.search, required this.travel});
  final TextEditingController search;
  final TravelState travel;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int day = 0;
  int tab = 0;
  String? shownTrip; // đổi chuyến thì về Ngày 1

  void openChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    context.push('/ai', extra: widget.search.text.trim());
  }

  Place placeOf(Map<String, dynamic> stop) =>
      widget.travel.placeById(stop['dia_diem_id'] as String?) ??
      Place(id: '', name: stop['ten_luc_luu'] as String);

  Stop stopOf(Map<String, dynamic> stop) {
    final time = stop['gio_den'] as String?;
    return (
      time != null ? hhmm(time) : buoiLabel[stop['buoi']] ?? 'Chưa đặt giờ',
      placeOf(stop),
    );
  }

  /// Ngày đã có địa điểm này trong chuyến (1-based), để cảnh báo thêm trùng.
  List<int> daysWith(String placeId) => [
    for (var i = 0; i < widget.travel.current!.days.length; i++)
      if (widget.travel.current!.days[i].any(
        (s) => s['dia_diem_id'] == placeId,
      ))
        i + 1,
  ];

  Future<void> addStop(int index, List<Map<String, dynamic>> stops) {
    var query = '';
    return sheet<void>(
      context,
      'Thêm điểm dừng',
      body: StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm địa điểm',
              ),
              onChanged: (text) => setState(() => query = searchable(text)),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .5,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final place in widget.travel.places.where(
                    (p) =>
                        searchable(p.name).contains(query) ||
                        searchable(p.localName).contains(query),
                  ))
                    ListTile(
                      leading: Art(place.image, width: 48, height: 42),
                      title: Text(place.name),
                      subtitle: Text(
                        [
                          place.district,
                          place.description,
                          if (daysWith(place.id).isNotEmpty)
                            'Đã có ở Ngày ${daysWith(place.id).join(', ')}',
                        ].join(' · '),
                        style: caption,
                      ),
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        widget.travel.setDayStops(index, [
                          ...stops,
                          {'ten_luc_luu': place.name, 'dia_diem_id': place.id},
                        ]);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> stopOptions(
    int index,
    List<Map<String, dynamic>> stops,
    int position,
  ) {
    final travel = widget.travel;
    final days = travel.current!.days;
    final stop = stops[position];
    final place = placeOf(stop);
    void close() => Navigator.of(context, rootNavigator: true).pop();
    Future<void> setTime() async {
      final now = minutesOf(stop['gio_den'] as String?) ?? 8 * 60;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: now ~/ 60, minute: now % 60),
        initialEntryMode: TimePickerEntryMode.inputOnly,
        helpText: 'Chọn giờ đến',
        cancelText: 'Huỷ',
        confirmText: 'Xong',
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );
      if (picked == null) return;
      final time =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      // điểm có giờ xếp theo giờ, điểm chưa có giờ giữ thứ tự và nằm sau
      final updated = [...stops]
        ..[position] = {...stop, 'gio_den': time, 'buoi': null};
      final timed = updated.where((s) => s['gio_den'] != null).toList()
        ..sort(
          (a, b) => (a['gio_den'] as String).compareTo(b['gio_den'] as String),
        );
      await travel.setDayStops(index, [
        ...timed,
        ...updated.where((s) => s['gio_den'] == null),
      ]);
    }

    return sheet<void>(
      context,
      place.name,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (place.id.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.info_outline, color: brown),
              title: const Text('Xem chi tiết'),
              onTap: () {
                close();
                placeDetails(context, travel, place);
              },
            ),
          ListTile(
            leading: const Icon(Icons.schedule, color: brown),
            title: const Text('Đặt giờ đến'),
            subtitle: place.opens.isEmpty
                ? null
                : Text('Mở cửa ${place.opens}–${place.closes}'),
            onTap: () {
              close();
              setTime();
            },
          ),
          if (position > 0)
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: brown),
              title: const Text('Lên trên'),
              onTap: () {
                close();
                travel.setDayStops(
                  index,
                  [...stops]
                    ..removeAt(position)
                    ..insert(position - 1, stop),
                );
              },
            ),
          if (position < stops.length - 1)
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: brown),
              title: const Text('Xuống dưới'),
              onTap: () {
                close();
                travel.setDayStops(
                  index,
                  [...stops]
                    ..removeAt(position)
                    ..insert(position + 1, stop),
                );
              },
            ),
          for (var other = 0; other < days.length; other++)
            if (other != index)
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: brown),
                title: Text('Chuyển sang Ngày ${other + 1}'),
                onTap: () {
                  close();
                  travel.setDays([
                    for (var i = 0; i < days.length; i++)
                      i == index
                          ? ([...stops]..removeAt(position))
                          : i == other
                          ? [...days[i], stop]
                          : days[i],
                  ]);
                },
              ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: brown),
            title: const Text('Xoá khỏi ngày này'),
            onTap: () {
              close();
              travel.setDayStops(index, [...stops]..removeAt(position));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.travel,
    builder: (context, _) => buildPage(context),
  );

  /// Tab Bản đồ: thứ tự điểm dừng trong ngày, khoảng cách ước tính và nút mở Google Maps.
  List<Widget> mapTab(int dayIndex, List<Map<String, dynamic>> stops) {
    final places = [for (final s in stops) placeOf(s)];
    final mappable = places.where((p) => p.hasCoords).toList();
    var km = 0.0, minutes = 0;
    for (var i = 1; i < mappable.length; i++) {
      final t = travelBetween(mappable[i - 1], mappable[i]);
      km += t.km;
      minutes += t.minutes;
    }
    return [
      const SizedBox(height: 8),
      if (stops.isEmpty)
        Panel(
          child: ListTile(
            title: Text('Ngày ${dayIndex + 1} chưa có điểm dừng'),
            subtitle: const Text(
              'Thêm điểm dừng ở tab Lịch trình để xem lộ trình.',
            ),
          ),
        )
      else ...[
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < places.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: brown,
                    foregroundColor: Colors.white,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  title: Text(places[i].name),
                  subtitle: Text(
                    i > 0 && places[i].hasCoords && places[i - 1].hasCoords
                        ? 'Từ điểm trước: ${travelText(places[i - 1], places[i])}'
                        : places[i].district,
                    style: caption,
                  ),
                  trailing: places[i].hasCoords
                      ? IconButton(
                          tooltip: 'Chỉ đường đến ${places[i].name}',
                          icon: const Icon(Icons.directions, color: brown),
                          onPressed: () =>
                              openMaps(context, mapsDirectionsUrl([places[i]])),
                        )
                      : null,
                ),
              if (mappable.length > 1) ...[
                const Divider(height: 14, color: line),
                Meta(
                  Icons.route_outlined,
                  'Tổng ~${km.toStringAsFixed(1).replaceAll('.', ',')} km · ~$minutes phút đi xe (ước tính)',
                ),
              ],
              if (mappable.length > maxMapsPoints)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Google Maps chỉ nhận tối đa $maxMapsPoints điểm, lộ trình mở ra gồm $maxMapsPoints điểm đầu.',
                    style: caption.copyWith(fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
        if (mappable.isNotEmpty) ...[
          const SizedBox(height: 8),
          Pill(
            mappable.length == 1
                ? 'Chỉ đường trên Google Maps'
                : 'Mở lộ trình Ngày ${dayIndex + 1} trên Google Maps',
            icon: Icons.map_outlined,
            filled: true,
            onTap: () => openMaps(context, mapsDirectionsUrl(mappable)),
          ),
        ],
      ],
    ];
  }

  Widget buildPage(BuildContext context) {
    final travel = widget.travel;
    final current = travel.current;
    final days = current?.days ?? const <List<Map<String, dynamic>>>[];
    if (current?.trip.id != shownTrip) {
      shownTrip = current?.trip.id;
      day = 0;
    }
    final selected = days.isEmpty ? 0 : math.min(day, days.length - 1);
    int ticketsOf(List<Map<String, dynamic>> stops) =>
        stops.fold(0, (sum, s) => sum + placeOf(s).priceVnd);
    final tripTickets = days.fold(0, (sum, d) => sum + ticketsOf(d));
    return ListView(
      padding: const EdgeInsets.only(bottom: 10),
      children: [
        const PageHeader(
          title: 'Hanoi\nTravel Planner',
          subtitle: 'Lên kế hoạch · Khám phá · Đi cùng AI',
          home: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchPill(
                controller: widget.search,
                hint: 'Bạn muốn đi Hà Nội thế nào? (vd: 2 ngày, văn hoá)',
                onSubmitted: (_) => openChat(),
                action: Pill(
                  'AI',
                  icon: Icons.auto_awesome,
                  filled: true,
                  compact: true,
                  onTap: openChat,
                ),
              ),
              const SizedBox(height: 11),
              if (current == null) ...[
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Art(
                        'mascot.png',
                        width: 81,
                        height: 99,
                        radius: 23,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Expanded(
                      child: Panel(
                        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '👋 Chào bạn! Mình là trợ lý AI',
                              style: display(15),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Cho mình biết số ngày, sở thích và thời gian, mình sẽ lên lịch trình riêng cho bạn!',
                              style: caption,
                            ),
                            const SizedBox(height: 5),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Pill(
                                'Tạo lịch trình',
                                icon: Icons.auto_awesome,
                                trailing: Icons.arrow_forward,
                                filled: true,
                                compact: true,
                                onTap: openChat,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (loadStatus(travel) case final status?)
                status
              else if (current == null)
                Panel(
                  child: ListTile(
                    leading: const Icon(Icons.work_outline, color: brown),
                    title: const Text('Chưa có chuyến đi'),
                    subtitle: const Text(
                      'Tự tạo chuyến đi hoặc nhờ AI lên lịch trình.',
                    ),
                    trailing: const Icon(Icons.add, color: brown),
                    onTap: () => newTripSheet(context, travel),
                  ),
                )
              else ...[
                Panel(
                  padding: const EdgeInsets.fromLTRB(10, 8, 9, 8),
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: -.10,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: shadow,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(3, 3, 3, 6),
                            child: Art(
                              current.trip.image,
                              width: 48,
                              height: 47,
                              radius: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: brown,
                        size: 19,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              current.trip.name,
                              style: display(16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${current.trip.dates} · ${current.trip.stops} điểm'
                              '${tripTickets > 0 ? ' · vé ${vnd(tripTickets)}/người' : ''}',
                              style: caption,
                            ),
                          ],
                        ),
                      ),
                      Pill(
                        'Sửa',
                        icon: Icons.edit_outlined,
                        compact: true,
                        onTap: () => tripOptions(context, travel, current.trip),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                TabStrip(
                  items: const [
                    ('Lịch trình', null),
                    ('Bản đồ', Icons.map_outlined),
                    ('Chi tiết', Icons.info_outline),
                    ('Đã lưu', Icons.bookmark_outline),
                  ],
                  selected: tab,
                  onSelect: (index) => setState(() => tab = index),
                ),
                const Divider(height: 9, color: line),
                if (tab <= 1) ...[
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < days.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: SizedBox(
                                    width: days.length <= 3 ? 76 : 70,
                                    child: Pill(
                                      'Ngày ${i + 1}',
                                      filled: selected == i,
                                      compact: true,
                                      onTap: () => setState(() => day = i),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Pill(
                        tab == 0 ? 'Bản đồ' : 'Lịch trình',
                        icon: tab == 0 ? Icons.place_outlined : Icons.list_alt,
                        compact: true,
                        onTap: () => setState(() => tab = tab == 0 ? 1 : 0),
                      ),
                    ],
                  ),
                  if (tab == 1)
                    ...mapTab(selected, days[selected])
                  else ...[
                    if (ticketsOf(days[selected]) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Meta(
                          Icons.confirmation_number_outlined,
                          'Vé tham quan Ngày ${selected + 1}: ${vnd(ticketsOf(days[selected]))}/người',
                        ),
                      ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                        key: ValueKey(selected),
                        children: [
                          for (var i = 0; i < days[selected].length; i++)
                            TimelineStop(
                              stop: stopOf(days[selected][i]),
                              warning: hoursWarning(
                                placeOf(days[selected][i]),
                                days[selected][i],
                              ),
                              travel:
                                  i > 0 &&
                                      placeOf(days[selected][i - 1])
                                          .hasCoords &&
                                      placeOf(days[selected][i]).hasCoords
                                  ? travelText(
                                      placeOf(days[selected][i - 1]),
                                      placeOf(days[selected][i]),
                                    )
                                  : null,
                              isLast: i == days[selected].length - 1,
                              onTap: () =>
                                  stopOptions(selected, days[selected], i),
                            ),
                        ],
                      ),
                    ),
                    CustomPaint(
                      painter: const DashedOutline(),
                      child: TextButton.icon(
                        onPressed: () => addStop(selected, days[selected]),
                        icon: const Icon(Icons.add_circle_outline, size: 17),
                        label: const Text('Thêm điểm dừng'),
                      ),
                    ),
                  ],
                ] else
                  Panel(
                    child: ListTile(
                      title: Text(
                        ['Lịch trình', 'Bản đồ', 'Chi tiết', 'Đã lưu'][tab],
                      ),
                      subtitle: const Text('Sắp có'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class TabStrip extends StatelessWidget {
  const TabStrip({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });
  final List<(String, IconData?)> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: surface.withValues(alpha: .8),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Semantics(
                selected: i == selected,
                child: i == selected
                    ? Pill(
                        items[i].$1,
                        icon: items[i].$2,
                        filled: true,
                        compact: true,
                        onTap: () => onSelect(i),
                      )
                    : TextButton(
                        onPressed: () => onSelect(i),
                        style: TextButton.styleFrom(
                          foregroundColor: ink,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (items[i].$2 != null) ...[
                              Icon(items[i].$2, size: 13),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                items[i].$1,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
      ],
    ),
  );
}

class TimelineStop extends StatelessWidget {
  const TimelineStop({
    super.key,
    required this.stop,
    required this.isLast,
    this.onTap,
    this.warning,
    this.travel,
  });
  final Stop stop;
  final bool isLast;
  final VoidCallback? onTap;
  final String? warning;
  final String? travel; // "~2,3 km · ~15 phút" từ điểm trước

  @override
  Widget build(BuildContext context) {
    final (time, place) = stop;
    return Stack(
      children: [
        Positioned(
          top: 13,
          bottom: isLast ? 35 : 0,
          left: 6,
          width: 1,
          child: const CustomPaint(painter: DashedOutline(vertical: true)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 13, right: 5),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: cream,
                  shape: BoxShape.circle,
                  border: Border.all(color: brown, width: 1.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 5),
                child: BadgeText(time),
              ),
              Expanded(
                child: Panel(
                  onTap: onTap,
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      Art(place.image, width: 81, height: 67, radius: 11),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(place.name, style: display(14)),
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 7,
                              runSpacing: 2,
                              children: [
                                Meta(Icons.place_outlined, place.district),
                                Meta(Icons.schedule_outlined, place.duration),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              place.description,
                              style: caption.copyWith(fontSize: 10),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (travel != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Meta(
                                  Icons.directions_car_outlined,
                                  'Từ điểm trước: $travel',
                                ),
                              ),
                            if (warning != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 13,
                                      color: Color(0xffa3321b),
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        warning!,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xffa3321b),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: brown, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DashedOutline extends CustomPainter {
  const DashedOutline({this.vertical = false});
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke;
    final path = Path();
    if (vertical) {
      path.moveTo(.5, 0);
      path.lineTo(.5, size.height);
    } else {
      path.addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.7),
          const Radius.circular(12),
        ),
      );
    }
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 8) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 4, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutline oldDelegate) =>
      vertical != oldDelegate.vertical;
}

class BadgeText extends StatelessWidget {
  const BadgeText(
    this.label, {
    super.key,
    this.background = tint,
    this.foreground = brown,
  });
  final String label;
  final Color background, foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          height: 1.1,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.travel});
  final TravelState travel;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final search = TextEditingController();
  String category = 'Tất cả';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.travel,
    builder: (context, _) {
      final query = searchable(search.text);
      final showPopular = category == 'Tất cả' && query.isEmpty;
      final items = widget.travel.places
          .where(
            (place) =>
                (category == 'Tất cả' || place.category == category) &&
                (searchable(place.name).contains(query) ||
                    searchable(place.localName).contains(query)),
          )
          .toList();
      const categories = [
        ('Tất cả', Icons.grid_view_rounded),
        ('Lịch sử', Icons.account_balance_outlined),
        ('Thiên nhiên', Icons.eco_outlined),
        ('Văn hoá', Icons.theater_comedy_outlined),
        ('Ẩm thực', Icons.restaurant),
      ];
      return CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: PageHeader(
              title: 'Khám phá Hà Nội',
              subtitle: 'Những nơi nên đến ở Hà Nội',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SearchPill(
                          controller: search,
                          hint: 'Tìm địa điểm ở Hà Nội...',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RoundAction(
                        Icons.tune,
                        'Bộ lọc',
                        filled: true,
                        onTap: () => sheet<void>(context, 'Bộ lọc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final (label, icon) = categories[index];
                        final selected = category == label;
                        return Semantics(
                          selected: selected,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: surface,
                              gradient: selected ? brand : null,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: shadow,
                            ),
                            child: TextButton(
                              onPressed: () => setState(() => category = label),
                              style: TextButton.styleFrom(
                                fixedSize: const Size(64, 64),
                                padding: EdgeInsets.zero,
                                foregroundColor: selected
                                    ? Colors.white
                                    : brown,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(icon, size: 21),
                                  const SizedBox(height: 2),
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 24,
                        color: Color(0xffd56c29),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          showPopular ? 'Điểm nổi bật' : 'Địa điểm',
                          style: display(20, italic: true),
                        ),
                      ),
                      TextButton(
                        onPressed: () => sheet<void>(context, 'Xem tất cả'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: const Row(
                          children: [
                            Text('Xem tất cả'),
                            Icon(Icons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (loadStatus(widget.travel) case final status?)
            SliverToBoxAdapter(child: status)
          else if (items.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: Text('Không tìm thấy địa điểm')),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 205,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  PlaceCard(place: items[index], travel: widget.travel),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> placeDetails(
  BuildContext context,
  TravelState travel,
  Place place,
) {
  final credits = [
    if (place.imageCredit != null) 'Ảnh: ${place.imageCredit}',
    if (place.wikipediaUrl != null) 'Mô tả: Wikipedia (CC BY-SA 4.0)',
    if (place.openingHours != null || place.address != null)
      'Dữ liệu bản đồ © OpenStreetMap contributors',
  ];
  return sheet<void>(
    context,
    place.name,
    body: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Art(place.image, height: 170, radius: 14),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: travel,
            builder: (context, _) {
              final trip = travel.current;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Pill(
                    travel.isPlaceSaved(place) ? 'Đã lưu' : 'Lưu',
                    icon: travel.isPlaceSaved(place)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    compact: true,
                    onTap: () => travel.togglePlace(place),
                  ),
                  if (trip != null) ...[
                    Text('Thêm vào:', style: caption),
                    for (var i = 0; i < trip.days.length; i++)
                      Pill(
                        'Ngày ${i + 1}',
                        icon: Icons.add,
                        compact: true,
                        filled: true,
                        onTap: () async {
                          if (await travel.addPlace(i, place) &&
                              context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã thêm vào Ngày ${i + 1} của "${trip.trip.name}"',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ],
              );
            },
          ),
          if (place.hasCoords) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill(
                  'Xem trên Google Maps',
                  icon: Icons.map_outlined,
                  compact: true,
                  onTap: () => openMaps(context, mapsPlaceUrl(place)),
                ),
                Pill(
                  'Chỉ đường',
                  icon: Icons.directions,
                  compact: true,
                  onTap: () => openMaps(context, mapsDirectionsUrl([place])),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Meta(Icons.place_outlined, place.address ?? place.district),
          const SizedBox(height: 4),
          Meta(
            Icons.schedule_outlined,
            place.openingHours != null
                ? 'Giờ mở cửa: ${osmHoursVi(place.openingHours!)}'
                : place.description,
          ),
          const SizedBox(height: 4),
          Meta(
            Icons.confirmation_number_outlined,
            place.priceVnd == 0
                ? 'Miễn phí vào cửa'
                : 'Vé ${vnd(place.priceVnd)}/người',
          ),
          const SizedBox(height: 4),
          Meta(Icons.timelapse, 'Nên dành ${place.duration.substring(2)}'),
          if (place.about != null) ...[
            const SizedBox(height: 10),
            Text(place.about!),
          ],
          for (final link in [place.website, place.wikipediaUrl])
            if (link != null) ...[
              const SizedBox(height: 6),
              SelectableText(Uri.decodeFull(link), style: caption),
            ],
          if (credits.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(credits.join('\n'), style: caption.copyWith(fontSize: 10)),
          ],
        ],
      ),
    ),
  );
}

class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.place, required this.travel});
  final Place place;
  final TravelState travel;

  @override
  Widget build(BuildContext context) {
    final saved = travel.isPlaceSaved(place);
    return Stack(
      children: [
        Positioned.fill(
          child: Panel(
            padding: EdgeInsets.zero,
            onTap: () => placeDetails(context, travel, place),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Art(place.image, radius: 0)),
                SizedBox(
                  height: 100,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 5, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: display(15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Meta(Icons.place_outlined, place.district),
                        const Spacer(),
                        Row(
                          children: [
                            Flexible(child: BadgeText(place.tag)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                place.duration,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: caption.copyWith(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: RoundAction(
            saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            '${saved ? 'Bỏ lưu' : 'Lưu'} ${place.name}',
            onTap: () => travel.togglePlace(place),
          ),
        ),
      ],
    );
  }
}

class TripsPage extends StatefulWidget {
  const TripsPage({super.key, required this.travel});
  final TravelState travel;

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  int filter = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.travel,
    builder: (context, _) {
      final now = DateTime.now();
      final items = widget.travel.trips.where(
        (trip) => switch (filter) {
          1 => !trip.completed(now),
          2 => trip.completed(now),
          3 => trip.favorite,
          _ => true,
        },
      );
      return ListView(
        padding: const EdgeInsets.only(bottom: 10),
        children: [
          PageHeader(
            title: 'Chuyến đi',
            subtitle: 'Quản lý các chuyến đi Hà Nội',
            icon: Icons.calendar_month_outlined,
            action: Pill(
              'Tạo chuyến đi',
              icon: Icons.add,
              compact: true,
              filled: true,
              onTap: () => newTripSheet(context, widget.travel),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                TabStrip(
                  items: const [
                    ('Tất cả', null),
                    ('Sắp tới', null),
                    ('Đã đi', null),
                    ('Yêu thích', Icons.favorite_border),
                  ],
                  selected: filter,
                  onSelect: (index) => setState(() => filter = index),
                ),
                const SizedBox(height: 11),
                if (loadStatus(widget.travel) case final status?)
                  status
                else if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        Icon(Icons.work_outline, color: brown, size: 32),
                        SizedBox(height: 6),
                        Text('Chưa có chuyến đi'),
                      ],
                    ),
                  ),
                for (final trip in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TripCard(
                      trip: trip,
                      travel: widget.travel,
                      completed: trip.completed(now),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
    required this.trip,
    required this.travel,
    required this.completed,
  });
  final Trip trip;
  final TravelState travel;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final favorite = trip.favorite;
    return Panel(
      padding: const EdgeInsets.fromLTRB(8, 7, 5, 7),
      onTap: () async {
        if (await travel.openTrip(trip.id) && context.mounted) context.go('/');
      },
      child: Row(
        children: [
          Art(trip.image, width: 95, height: 91, radius: 13),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trip.name,
                        style: display(15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: favorite ? 'Bỏ yêu thích' : 'Thêm vào yêu thích',
                      onPressed: () => travel.toggleFavorite(trip),
                      icon: Icon(
                        favorite ? Icons.favorite : Icons.favorite_border,
                        color: brown,
                        size: 17,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tuỳ chọn chuyến đi',
                      onPressed: () => tripOptions(context, travel, trip),
                      icon: const Icon(Icons.more_vert, color: brown, size: 17),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 44,
                      ),
                    ),
                  ],
                ),
                Meta(Icons.calendar_month_outlined, trip.dates),
                const SizedBox(height: 3),
                const Meta(Icons.place_outlined, 'Hà Nội'),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Meta(
                      Icons.event_note_outlined,
                      '${trip.days} ngày · ${trip.stops} điểm',
                    ),
                    BadgeText(
                      completed ? 'Đã đi' : 'Sắp tới',
                      background: completed
                          ? const Color(0xffdce3bd)
                          : const Color(0xfffbe4a6),
                      foreground: completed
                          ? const Color(0xff4c6126)
                          : const Color(0xff80550a),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.travel, required this.onLogout});
  final TravelState travel;
  final VoidCallback onLogout;

  Future<void> logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    onLogout();
    await travel.signOut(); // router tự chuyển về /login
  }

  Future<void> openPrivacy(BuildContext context) => sheet<void>(
    context,
    'Dữ liệu & quyền riêng tư',
    body: ListenableBuilder(
      listenable: travel,
      builder: (context, _) {
        final sync = travel.sync;
        if (!sync.enabled) {
          return const Text(
            'Bản chạy thử (lịch mẫu) không lưu dữ liệu nào lên máy chủ.',
            style: caption,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: sync.consent == true,
              title: const Text('Cho phép ghi lại cách dùng app'),
              subtitle: const Text(
                'Ẩn danh. Không lưu nội dung câu hỏi, không lưu vị trí GPS.',
                style: caption,
              ),
              onChanged: (value) async {
                await sync.setConsent(value);
                travel.changed();
              },
            ),
            Text(
              'Chuyến đã lưu: ${travel.serverTrips.length} trên máy chủ. '
              'Mã ẩn danh của máy này: ${(sync.userId ?? '').split('-').first}…',
              style: caption,
            ),
            const SizedBox(height: 12),
            Pill(
              'Xoá dữ liệu của tôi',
              icon: Icons.delete_outline,
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Xoá dữ liệu của bạn?'),
                    content: const Text(
                      'Xoá mọi chuyến đã lưu, check-in và lịch sử thao tác trên '
                      'máy chủ. Không hoàn tác được.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Huỷ'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Xoá'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                final deleted = await sync.deleteMyData();
                travel.forgetServerTrips();
                if (context.mounted) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      content: Text(
                        deleted ? 'Đã xoá dữ liệu của bạn.' : 'Chưa kết nối được máy chủ; mã ẩn danh đã được đổi.',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    ),
  );

  Future<void> openSaved(BuildContext context) => sheet<void>(
    context,
    'Địa điểm đã lưu',
    body: ListenableBuilder(
      listenable: travel,
      builder: (context, _) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 330),
        child: travel.savedPlaces.isEmpty
            ? const Text('Chưa lưu địa điểm nào')
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final place in travel.places.where(travel.isPlaceSaved))
                    ListTile(
                      leading: Art(place.image, width: 48, height: 42),
                      title: Text(place.name),
                      onTap: () => placeDetails(context, travel, place),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: brown),
                        tooltip: 'Bỏ lưu ${place.name}',
                        onPressed: () => travel.togglePlace(place),
                      ),
                    ),
                ],
              ),
      ),
    ),
  );

  Future<void> openHistory(BuildContext context) {
    final now = DateTime.now();
    final done = travel.trips.where((t) => t.completed(now)).toList();
    return sheet<void>(
      context,
      'Lịch sử chuyến đi',
      body: done.isEmpty
          ? const Text('Chưa có chuyến nào đã kết thúc.')
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 330),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final trip in done)
                    ListTile(
                      leading: Art(trip.image, width: 48, height: 42),
                      title: Text(trip.name),
                      subtitle: Text(
                        '${trip.dates} · ${trip.stops} điểm',
                        style: caption,
                      ),
                      onTap: () async {
                        Navigator.of(context, rootNavigator: true).pop();
                        if (await travel.openTrip(trip.id) && context.mounted) {
                          context.go('/');
                        }
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> editProfile(BuildContext context) async {
    final me = travel.profile;
    if (me == null) return;
    var (name, email, phone) = (me.name, me.email, me.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa hồ sơ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: name,
              onChanged: (text) => name = text,
              decoration: const InputDecoration(labelText: 'Tên'),
            ),
            TextFormField(
              initialValue: email,
              onChanged: (text) => email = text,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextFormField(
              initialValue: phone,
              onChanged: (text) => phone = text,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await travel.updateProfile(name, email, phone);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: travel,
    builder: (context, _) => buildPage(context),
  );

  Widget buildPage(BuildContext context) {
    final me = travel.profile;
    final now = DateTime.now();
    const rows = [
      (
        Icons.people_outline,
        'Sở thích du lịch',
        'Sở thích, phong cách, ngân sách',
      ),
      (Icons.favorite_border, 'Địa điểm đã lưu', 'Những nơi bạn đã lưu'),
      (Icons.history, 'Lịch sử chuyến đi', 'Các chuyến đã đi'),
      (Icons.settings_outlined, 'Cài đặt', 'Ứng dụng, thông báo, ngôn ngữ'),
      (Icons.help_outline, 'Trợ giúp', 'Câu hỏi thường gặp, liên hệ'),
      (
        Icons.shield_outlined,
        'Dữ liệu & quyền riêng tư',
        'Thu thập ẩn danh, xoá dữ liệu của bạn',
      ),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        const PageHeader(
          title: 'Cá nhân',
          subtitle: 'Tài khoản của bạn',
          icon: Icons.person_outline,
          profile: true,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Panel(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: tint,
                          foregroundColor: brown,
                          child: Text(
                            (me?.name.trim().isNotEmpty ?? false)
                                ? me!.name.trim()[0].toUpperCase()
                                : '?',
                            style: display(30),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      me?.name ?? '…',
                                      style: display(19),
                                    ),
                                  ),
                                  Pill(
                                    'Sửa',
                                    icon: Icons.edit_outlined,
                                    compact: true,
                                    onTap: () => editProfile(context),
                                  ),
                                ],
                              ),
                              Meta(
                                Icons.mail_outline,
                                me == null || me.email.isEmpty
                                    ? 'Chưa có email'
                                    : me.email,
                              ),
                              const SizedBox(height: 5),
                              Meta(
                                Icons.call_outlined,
                                me == null || me.phone.isEmpty
                                    ? 'Chưa có số điện thoại'
                                    : me.phone,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: line),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            stat(
                              Icons.flight_takeoff,
                              '${travel.trips.length}',
                              'Chuyến đi',
                            ),
                            const VerticalDivider(width: 1, color: outline),
                            stat(
                              Icons.check_circle_outline,
                              '${travel.trips.where((t) => t.completed(now)).length}',
                              'Đã đi',
                            ),
                            const VerticalDivider(width: 1, color: outline),
                            stat(
                              Icons.favorite_border,
                              '${travel.savedPlaces.length}',
                              'Đã lưu',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 13,
                          endIndent: 13,
                          color: line,
                        ),
                      ListTile(
                        visualDensity: VisualDensity.compact,
                        leading: Icon(rows[i].$1, color: brown),
                        title: Text(
                          rows[i].$2,
                          style: const TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(rows[i].$3, style: caption),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: brown,
                          size: 19,
                        ),
                        onTap: () => switch (i) {
                          1 => openSaved(context),
                          2 => openHistory(context),
                          5 => openPrivacy(context),
                          _ => sheet<void>(context, rows[i].$2),
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Pill(
                'Đăng xuất',
                icon: Icons.logout,
                onTap: () => logout(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget stat(IconData icon, String number, String label) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
      child: Column(
        children: [
          Icon(icon, color: brown, size: 21),
          Text(number, style: display(18)),
          Text(label, textAlign: TextAlign.center, style: caption),
        ],
      ),
    ),
  );
}
