import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'chat.dart';
import 'theme.dart';
import 'travel_data.dart';
import 'trip_tools.dart';

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

  TravelState get travel => widget.travel;

  void openChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    context.push('/ai', extra: widget.search.text.trim());
  }

  /// Sửa chuyến thật (bảng Đổi kế hoạch → chat soạn sẵn); chưa có chuyến thật thì mở chat.
  void edit(Itinerary? plan) =>
      plan == null ? openChat() : replanSavedTrip(context, plan, travel);

  /// Tên các điểm của từng ngày (chuyến thật, hoặc lịch mẫu khi chưa có).
  List<List<String>> dayNames(Itinerary? plan) => plan == null
      ? [
          for (final stops in homeDays) [for (final (_, p) in stops) p.name],
        ]
      : [
          for (final d in plan.days)
            d.details.isNotEmpty
                ? [for (final s in d.details) s.name]
                : [for (final s in d.stops) s.$2],
        ];

  List<String> routesOf(Itinerary? plan, int index) {
    final urls = plan?.days[index].routeUrls ?? const <String>[];
    return urls.isNotEmpty
        ? urls
        : dayRoutes(dayNames(plan)[index].map(mapsPlace).toList());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: travel,
    builder: (context, _) {
      final trip = travel.latestRealTrip;
      final plan = trip?.preview;
      final dayCount = plan?.days.length ?? homeDays.length;
      final d = day.clamp(0, dayCount - 1);
      return ListView(
        padding: const EdgeInsets.only(bottom: 10),
        children: [
          const PageHeader(
            title: 'Hanoi\nTravel Planner',
            subtitle: 'Plan · Explore · Travel with AI',
            home: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchPill(
                  controller: widget.search,
                  hint: 'Plan a trip in Hanoi... (e.g., 2 days, culture, food)',
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
                              "👋 Hi! I'm your Hanoi Travel AI",
                              style: display(15),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Tell me your travel dates, interests, or time, and I'll create a personalized itinerary for you!",
                              style: caption,
                            ),
                            const SizedBox(height: 5),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Pill(
                                'Generate My Itinerary',
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
                Panel(
                  padding: const EdgeInsets.fromLTRB(10, 8, 9, 8),
                  onTap: trip == null
                      ? null
                      : () => context.push('/trip', extra: trip),
                  child: Row(
                    children: [
                      Transform.rotate(
                        angle: -.10,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            boxShadow: shadow,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.fromLTRB(3, 3, 3, 6),
                            child: Art(
                              'quarter.jpg',
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
                              trip?.name ?? 'Your Trip to Hanoi',
                              style: display(16),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              plan == null
                                  ? 'Lịch mẫu · tạo lịch thật với AI rồi bấm Lưu trip'
                                  : '${plan.duration} · ${trip!.dates}',
                              style: caption,
                            ),
                          ],
                        ),
                      ),
                      Pill(
                        plan == null ? 'Tạo lịch' : 'Đổi kế hoạch',
                        icon: plan == null
                            ? Icons.auto_awesome
                            : Icons.edit_calendar_outlined,
                        compact: true,
                        onTap: () => edit(plan),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                TabStrip(
                  items: const [
                    ('Itinerary', null),
                    ('Map', Icons.map_outlined),
                    ('Trip Details', Icons.info_outline),
                    ('Saved', Icons.bookmark_outline),
                  ],
                  selected: tab,
                  onSelect: (index) => setState(() => tab = index),
                ),
                const Divider(height: 9, color: line),
                ...switch (tab) {
                  1 => mapTab(plan),
                  2 => detailsTab(trip, plan),
                  3 => savedTab(),
                  _ => itineraryTab(trip, plan, dayCount, d),
                },
              ],
            ),
          ),
        ],
      );
    },
  );

  List<Widget> itineraryTab(Trip? trip, Itinerary? plan, int dayCount, int d) =>
      [
        Row(
          children: [
            for (var i = 0; i < dayCount; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Pill(
                    'Day ${i + 1}',
                    filled: d == i,
                    compact: true,
                    onTap: () => setState(() => day = i),
                  ),
                ),
              ),
            Pill(
              'View on Map',
              icon: Icons.place_outlined,
              compact: true,
              onTap: () {
                travel.sync.log('bam_chi_duong', {'cap': 'ngay', 'tu': 'home'});
                openLink(context, routesOf(plan, d).first);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: plan != null && plan.days[d].details.isNotEmpty
              ? DayPlan(
                  key: ValueKey('real-$d'),
                  index: d + 1,
                  day: plan.days[d],
                  tripId: trip!.id,
                  travel: travel,
                )
              : Column(
                  key: ValueKey(d),
                  children: [
                    if (plan == null)
                      for (var i = 0; i < homeDays[d].length; i++)
                        TimelineStop(
                          stop: homeDays[d][i],
                          isLast: i == homeDays[d].length - 1,
                          travel: travel,
                        )
                    else
                      DayPreview(index: d + 1, day: plan.days[d]),
                  ],
                ),
        ),
        const SizedBox(height: 6),
        CustomPaint(
          painter: const DashedOutline(),
          child: TextButton.icon(
            onPressed: () => edit(plan),
            icon: const Icon(Icons.add_circle_outline, size: 17),
            label: Text(
              plan == null ? 'Add a stop (tạo lịch với AI)' : 'Add a stop',
            ),
          ),
        ),
      ];

  List<Widget> mapTab(Itinerary? plan) {
    final names = dayNames(plan);
    return [
      if (plan == null)
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Lịch mẫu — đường đi dưới đây theo lịch mẫu.',
            style: caption,
          ),
        ),
      for (var i = 0; i < names.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ngày ${i + 1}', style: display(15)),
                const SizedBox(height: 3),
                Text(names[i].join(' → '), style: caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (k, url) in routesOf(plan, i).indexed)
                      Pill(
                        routesOf(plan, i).length == 1
                            ? 'Chỉ đường cả ngày'
                            : 'Chỉ đường phần ${k + 1}',
                        icon: Icons.directions_outlined,
                        compact: true,
                        onTap: () {
                          travel.sync.log('bam_chi_duong', {
                            'cap': 'ngay',
                            'tu': 'home_map',
                          });
                          openLink(context, url);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const Text(
        'Mở Google Maps để xem bản đồ và thời gian đi thực tế.',
        style: caption,
      ),
    ];
  }

  List<Widget> detailsTab(Trip? trip, Itinerary? plan) {
    if (trip == null || plan == null) {
      return [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chưa có chuyến thật. Nhờ AI xếp lịch rồi bấm "Lưu trip" — '
                'chuyến mới nhất sẽ hiện ở đây.',
              ),
              const SizedBox(height: 8),
              Pill(
                'Tạo lịch với AI',
                icon: Icons.auto_awesome,
                filled: true,
                compact: true,
                onTap: openChat,
              ),
            ],
          ),
        ),
      ];
    }
    final stops = plan.days.fold<int>(0, (n, d) => n + d.details.length);
    final checked = travel.done
        .where((key) => key.startsWith('${trip.id}|'))
        .length;
    return [
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.title, style: display(16)),
            const SizedBox(height: 5),
            Meta(
              Icons.calendar_month_outlined,
              '${plan.duration} · ${trip.dates}',
            ),
            Meta(Icons.place_outlined, '$stops điểm · đã xong $checked'),
            if (plan.tags.isNotEmpty) Meta(Icons.people_outline, plan.tags),
            if (plan.totalVnd != null)
              Meta(
                Icons.payments_outlined,
                'Tổng vé ${vnd(plan.totalVnd!)}'
                '${plan.perPersonVnd == null ? '' : ' (${vnd(plan.perPersonVnd!)}/người)'}'
                '${plan.taxiVnd == null ? '' : ' · taxi ước tính ${vnd(plan.taxiVnd!)} (chỉ tham khảo)'}',
              ),
            if (plan.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              KeyNotes(notes: plan.notes, max: 12),
            ],
            const SizedBox(height: 8),
            Pill(
              'Mở chuyến',
              icon: Icons.open_in_new,
              compact: true,
              onTap: () => context.push('/trip', extra: trip),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> savedTab() => [
    if (travel.savedPlaces.isEmpty)
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chưa lưu điểm nào. Vào Explore, bấm ♥ ở điểm bạn thích.',
            ),
            const SizedBox(height: 8),
            Pill(
              'Mở Explore',
              icon: Icons.explore_outlined,
              compact: true,
              onTap: () => context.go('/explore'),
            ),
          ],
        ),
      ),
    for (final place in travel.savedPlaces)
      Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Panel(
          padding: const EdgeInsets.all(5),
          onTap: () => openPlace(context, place, travel),
          child: Row(
            children: [
              Art(place.image, width: 64, height: 52, radius: 10),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: display(14)),
                    Text(place.district, style: caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: brown, size: 16),
            ],
          ),
        ),
      ),
  ];
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
    this.travel,
  });
  final Stop stop;
  final bool isLast;
  final TravelState? travel;

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
                  onTap: () => travel == null
                      ? sheet<void>(context, place.name)
                      : openPlace(context, place, travel!),
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
  String category = 'All';

  /// Lọc theo nhãn sở thích (bảng Filters) — chỉ có với điểm thật từ máy chủ.
  final tags = <String>{};

  Future<void> openFilters(List<Place> all) async {
    final available = {for (final place in all) ...place.tags};
    await sheet<void>(
      context,
      'Filters',
      body: available.isEmpty
          ? const Text(
              'Bản chạy thử không có nhãn điểm; chạy kèm máy chủ để lọc theo sở thích.',
              style: caption,
            )
          : StatefulBuilder(
              builder: (context, setSheet) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in tagLabels.keys)
                        if (available.contains(tag))
                          FilterChip(
                            label: Text(tagLabels[tag]!),
                            selected: tags.contains(tag),
                            onSelected: (on) {
                              setSheet(
                                () => on ? tags.add(tag) : tags.remove(tag),
                              );
                              setState(() {});
                            },
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheet(tags.clear);
                          setState(() {});
                        },
                        child: const Text('Bỏ lọc'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Xem kết quả'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

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
      final showPopular = category == 'All' && query.isEmpty && tags.isEmpty;
      final all = widget.travel.places.isNotEmpty
          ? widget.travel.places
          : [...places, ...extraPlaces];
      final items = all
          .where(
            (place) =>
                (category == 'All' || place.category == category) &&
                tags.every(place.tags.contains) &&
                (searchable(place.name).contains(query) ||
                    searchable(place.localName).contains(query)),
          )
          .toList();
      const categories = [
        ('All', Icons.grid_view_rounded),
        ('Historical', Icons.account_balance_outlined),
        ('Nature', Icons.eco_outlined),
        ('Culture', Icons.theater_comedy_outlined),
        ('Food', Icons.restaurant),
      ];
      return CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: PageHeader(
              title: 'Explore Hanoi',
              subtitle: 'Discover must-visit places in Hanoi',
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
                          hint: 'Search places in Hanoi...',
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: tags.isNotEmpty,
                        label: Text('${tags.length}'),
                        child: RoundAction(
                          Icons.tune,
                          'Filters',
                          filled: true,
                          onTap: () => openFilters(all),
                        ),
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
                          showPopular
                              ? 'Popular Places in Hanoi'
                              : 'Places in Hanoi',
                          style: display(20, italic: true),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          category = 'All';
                          tags.clear();
                          search.clear();
                        }),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: const Row(
                          children: [
                            Text('See All'),
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
          if (items.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: Text('No places found')),
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

class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.place, required this.travel});
  final Place place;
  final TravelState travel;

  @override
  Widget build(BuildContext context) {
    final saved = travel.savedPlaces.contains(place);
    return Stack(
      children: [
        Positioned.fill(
          child: Panel(
            padding: EdgeInsets.zero,
            onTap: () => openPlace(context, place, travel),
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
                        Meta(
                          place.real
                              ? Icons.schedule_outlined
                              : Icons.place_outlined,
                          place.district,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (place.rating.isNotEmpty) ...[
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xffd78528),
                                size: 16,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  '${place.rating} (${place.reviews})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: caption.copyWith(fontSize: 10),
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                            Flexible(child: BadgeText(place.tag)),
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
            '${saved ? 'Unsave' : 'Save'} ${place.name}',
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
          3 => widget.travel.favorites.contains(trip.id),
          _ => true,
        },
      );
      return ListView(
        padding: const EdgeInsets.only(bottom: 10),
        children: [
          PageHeader(
            title: 'My Trip',
            subtitle: 'Manage your travel plans in Hanoi',
            icon: Icons.calendar_month_outlined,
            action: Pill(
              'Create Trip',
              icon: Icons.add,
              compact: true,
              filled: true,
              onTap: () => context.push('/ai'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                TabStrip(
                  items: const [
                    ('All Trips', null),
                    ('Upcoming', null),
                    ('Completed', null),
                    ('Favorites', Icons.favorite_border),
                  ],
                  selected: filter,
                  onSelect: (index) => setState(() => filter = index),
                ),
                const SizedBox(height: 11),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      children: [
                        Icon(Icons.work_outline, color: brown, size: 32),
                        SizedBox(height: 6),
                        Text('No trips yet'),
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

  Future<void> options(BuildContext context) => sheet<void>(
    context,
    trip.name,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.event_note_outlined, color: brown),
          title: const Text('Xem lịch'),
          onTap: () {
            Navigator.of(context).pop();
            context.push('/trip', extra: trip);
          },
        ),
        if (trip.preview?.detailed ?? false) ...[
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined, color: brown),
            title: const Text('Đổi kế hoạch'),
            onTap: () {
              Navigator.of(context).pop();
              replanSavedTrip(context, trip.preview!, travel);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: brown),
            title: const Text('Bỏ lưu chuyến'),
            onTap: () {
              Navigator.of(context).pop();
              travel.toggleTrip(trip.id, trip.preview!);
            },
          ),
        ] else
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Chuyến mẫu trong thiết kế — tạo chuyến thật với AI để đổi kế hoạch.',
              style: caption,
            ),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final favorite = travel.favorites.contains(trip.id);
    return Panel(
      padding: const EdgeInsets.fromLTRB(8, 7, 5, 7),
      onTap: () => context.push('/trip', extra: trip),
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
                      tooltip: favorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      onPressed: () => travel.toggleFavorite(trip.id),
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
                      tooltip: 'Trip options',
                      onPressed: () => options(context),
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
                const Meta(Icons.place_outlined, 'Hanoi'),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Meta(
                      Icons.people_outline,
                      '${trip.days} ${trip.days == 1 ? 'day' : 'days'} · ${trip.stops} stops',
                    ),
                    BadgeText(
                      completed ? 'Completed' : 'Upcoming',
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
        title: const Text('Log Out'),
        content: const Text('Log out of this demo session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    travel.reset();
    onLogout();
    context.go('/');
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

  List<Trip> get realTrips => [
    for (final trip in travel.trips)
      if (trip.preview?.detailed ?? false) trip,
  ];

  Future<void> noAccount(BuildContext context) => sheet<void>(
    context,
    'Tài khoản',
    body: const Text(
      'Chưa có đăng nhập. App dùng mã ẩn danh theo máy: chuyến đã lưu và '
      'check-in gắn với mã này. Đăng nhập (Google) sẽ làm ở bước sau.',
      style: caption,
    ),
  );

  Future<void> preferences(BuildContext context) => sheet<void>(
    context,
    'Travel Preferences',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Chưa lưu sở thích theo tài khoản. Hiện bạn ghi sở thích, ngân sách, '
          'nhịp đi ngay trong câu gửi AI (vd: "2 ngày, thích lịch sử, đi chậm, '
          'dưới 500k/người").',
          style: caption,
        ),
        const SizedBox(height: 10),
        Pill(
          'Mở chat AI',
          icon: Icons.auto_awesome,
          filled: true,
          compact: true,
          onTap: () {
            Navigator.of(context).pop();
            context.push('/ai');
          },
        ),
      ],
    ),
  );

  Future<void> openHistory(BuildContext context) => sheet<void>(
    context,
    'Travel History',
    body: ListenableBuilder(
      listenable: travel,
      builder: (context, _) {
        final trips = realTrips;
        if (trips.isEmpty) {
          return const Text(
            'Chưa có chuyến nào. Nhờ AI xếp lịch rồi bấm "Lưu trip".',
            style: caption,
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final trip in trips)
                ListTile(
                  leading: Art(trip.image, width: 48, height: 42),
                  title: Text(trip.name),
                  subtitle: Text(
                    '${trip.dates} · ${trip.stops} điểm · đã xong '
                    '${travel.done.where((k) => k.startsWith('${trip.id}|')).length}',
                    style: caption,
                  ),
                  trailing: const Icon(Icons.chevron_right, color: brown),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.push('/trip', extra: trip);
                  },
                ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> openSettings(BuildContext context) {
    var code = travel.accessCode;
    return sheet<void>(
      context,
      'Settings',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            initialValue: code,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mã truy cập API (nếu máy chủ yêu cầu)',
            ),
            onChanged: (value) => code = value,
          ),
          const SizedBox(height: 8),
          const Text(
            'Ngôn ngữ: Tiếng Việt. Chưa có thông báo đẩy.',
            style: caption,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              travel.accessCode = code.trim();
              Navigator.of(context).pop();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> openHelp(BuildContext context) => sheet<void>(
    context,
    'Help & Support',
    body: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .6,
      ),
      child: const SingleChildScrollView(
        child: Text(
          '1. Bấm AI, gõ: số ngày, ngày đi, số người, điểm muốn đi '
          '(vd "Đi Hà Nội 2 ngày từ 20/12, 2 người, thích lịch sử").\n'
          '2. Lịch hiện từng điểm: giờ đến, phút đi, vé, lý do. Giờ, phút và '
          'tiền do công cụ tính; giá taxi chỉ tham khảo.\n'
          '3. "Chỉ đường" mở Google Maps cho một điểm hoặc cả ngày.\n'
          '4. "Đổi kế hoạch": bỏ / thêm điểm, đổi giờ bắt đầu, thêm bớt ngày, '
          'xếp cho đỡ đi lòng vòng, nhập chỗ ở — AI xếp lại.\n'
          '5. "Lưu trip" để xem lại ở My Trip; khi đi, bấm "Đã xong" ở mỗi điểm.\n'
          '6. Giờ mở cửa và giá vé là dữ liệu mẫu của nhóm — kiểm lại trước khi đi.\n'
          '7. Profile → Dữ liệu & quyền riêng tư để tắt thu thập hoặc xoá dữ liệu.',
          style: TextStyle(color: ink, fontSize: 13, height: 1.4),
        ),
      ),
    ),
  );

  Future<void> openSaved(BuildContext context) => sheet<void>(
    context,
    'Saved Places',
    body: ListenableBuilder(
      listenable: travel,
      builder: (context, _) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 330),
        child: travel.savedPlaces.isEmpty
            ? const Text('No saved places yet')
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final place in travel.savedPlaces)
                    ListTile(
                      leading: Art(place.image, width: 48, height: 42),
                      title: Text(place.name),
                      onTap: () => openPlace(context, place, travel),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: brown),
                        tooltip: 'Unsave ${place.name}',
                        onPressed: () => travel.togglePlace(place),
                      ),
                    ),
                ],
              ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const rows = [
      (
        Icons.people_outline,
        'Travel Preferences',
        'Interests, travel style, budget',
      ),
      (Icons.favorite_border, 'Saved Places', 'Your favorite destinations'),
      (Icons.history, 'Travel History', 'Past trips and experiences'),
      (Icons.settings_outlined, 'Settings', 'App, notification, language'),
      (Icons.help_outline, 'Help & Support', 'FAQs, contact us'),
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
          title: 'Profile',
          subtitle: 'Your travel account',
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
                        Stack(
                          children: [
                            const Art(
                              'quarter.jpg',
                              width: 80,
                              height: 80,
                              radius: 50,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Material(
                                color: surface,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'Edit avatar',
                                  onPressed: () => noAccount(context),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 14,
                                    color: brown,
                                  ),
                                  constraints: const BoxConstraints.tightFor(
                                    width: 44,
                                    height: 44,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ],
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
                                      'Khách ẩn danh',
                                      style: display(19),
                                    ),
                                  ),
                                  Pill(
                                    'Edit',
                                    icon: Icons.edit_outlined,
                                    compact: true,
                                    onTap: () => noAccount(context),
                                  ),
                                ],
                              ),
                              const Meta(
                                Icons.lock_outline,
                                'Chưa đăng nhập — dữ liệu gắn với mã ẩn danh của máy này',
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
                      child: ListenableBuilder(
                        listenable: travel,
                        builder: (context, _) => IntrinsicHeight(
                          child: Row(
                            children: [
                              stat(
                                Icons.flight_takeoff,
                                '${realTrips.length}',
                                'Chuyến đã lưu',
                              ),
                              const VerticalDivider(width: 1, color: outline),
                              stat(
                                Icons.check_circle_outline,
                                '${travel.done.length}',
                                'Điểm đã xong',
                              ),
                              const VerticalDivider(width: 1, color: outline),
                              stat(
                                Icons.favorite_border,
                                '${travel.savedPlaces.length}',
                                'Điểm đã lưu',
                              ),
                            ],
                          ),
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
                          0 => preferences(context),
                          1 => openSaved(context),
                          2 => openHistory(context),
                          3 => openSettings(context),
                          4 => openHelp(context),
                          _ => openPrivacy(context),
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Pill('Log Out', icon: Icons.logout, onTap: () => logout(context)),
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
