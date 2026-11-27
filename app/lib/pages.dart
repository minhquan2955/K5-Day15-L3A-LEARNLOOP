import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';
import 'travel_data.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.search});
  final TextEditingController search;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int day = 0;
  int tab = 0;

  void openChat() {
    FocusManager.instance.primaryFocus?.unfocus();
    context.push('/ai', extra: widget.search.text.trim());
  }

  @override
  Widget build(BuildContext context) => ListView(
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
                        Text('Your Trip to Hanoi', style: display(16)),
                        const Text(
                          '3 Days · Culture · Sightseeing · Food',
                          style: caption,
                        ),
                      ],
                    ),
                  ),
                  Pill(
                    'Edit',
                    icon: Icons.edit_outlined,
                    compact: true,
                    onTap: () => sheet<void>(context, 'Edit'),
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
            if (tab == 0) ...[
              Row(
                children: [
                  for (var i = 0; i < homeDays.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Pill(
                          'Day ${i + 1}',
                          filled: day == i,
                          compact: true,
                          onTap: () => setState(() => day = i),
                        ),
                      ),
                    ),
                  Pill(
                    'View on Map',
                    icon: Icons.place_outlined,
                    compact: true,
                    onTap: () => setState(() => tab = 1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey(day),
                  children: [
                    for (var i = 0; i < homeDays[day].length; i++)
                      TimelineStop(
                        stop: homeDays[day][i],
                        isLast: i == homeDays[day].length - 1,
                      ),
                  ],
                ),
              ),
              CustomPaint(
                painter: const DashedOutline(),
                child: TextButton.icon(
                  onPressed: () => sheet<void>(context, 'Add a stop'),
                  icon: const Icon(Icons.add_circle_outline, size: 17),
                  label: const Text('Add a stop'),
                ),
              ),
            ] else
              Panel(
                child: ListTile(
                  title: Text(
                    ['Itinerary', 'Map', 'Trip Details', 'Saved'][tab],
                  ),
                  subtitle: const Text('Coming soon'),
                ),
              ),
          ],
        ),
      ),
    ],
  );
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
  const TimelineStop({super.key, required this.stop, required this.isLast});
  final Stop stop;
  final bool isLast;

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
                  onTap: () => sheet<void>(context, place.name),
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
      final showPopular = category == 'All' && query.isEmpty;
      final items = [...places, ...extraPlaces]
          .where(
            (place) =>
                (category == 'All' || place.category == category) &&
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
                      RoundAction(
                        Icons.tune,
                        'Filters',
                        filled: true,
                        onTap: () => sheet<void>(context, 'Filters'),
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
                        onPressed: () => sheet<void>(context, 'See All'),
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
            onTap: () => sheet<void>(context, place.name),
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

  @override
  Widget build(BuildContext context) {
    final favorite = travel.favorites.contains(trip.id);
    return Panel(
      padding: const EdgeInsets.fromLTRB(8, 7, 5, 7),
      onTap: () => sheet<void>(context, trip.name),
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
                      onPressed: () => sheet<void>(context, trip.name),
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
                                  onPressed: () =>
                                      sheet<void>(context, 'Edit avatar'),
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
                                      'Quan Nguyen',
                                      style: display(19),
                                    ),
                                  ),
                                  Pill(
                                    'Edit',
                                    icon: Icons.edit_outlined,
                                    compact: true,
                                    onTap: () =>
                                        sheet<void>(context, 'Edit profile'),
                                  ),
                                ],
                              ),
                              const Meta(
                                Icons.mail_outline,
                                'quan.nguyen@example.com',
                              ),
                              const SizedBox(height: 5),
                              const Meta(
                                Icons.call_outlined,
                                '+84 987 654 321',
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
                            stat(Icons.flight_takeoff, '5', 'Trips'),
                            const VerticalDivider(width: 1, color: outline),
                            stat(Icons.place_outlined, '42', 'Places Visited'),
                            const VerticalDivider(width: 1, color: outline),
                            stat(Icons.star_border, '4.8', 'Avg. Rating'),
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
                        onTap: () => i == 1
                            ? openSaved(context)
                            : sheet<void>(context, rows[i].$2),
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
