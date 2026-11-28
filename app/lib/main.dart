import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'chat.dart';
import 'pages.dart';
import 'theme.dart';
import 'sync.dart';
import 'travel_data.dart';

void main() {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const HanoiApp());
}

const interests = {
  'di_tich': 'Di tích',
  'lich_su': 'Lịch sử',
  'van_hoa': 'Văn hoá',
  'am_thuc': 'Ẩm thực',
  'pho_co': 'Phố cổ',
  'dao_pho': 'Dạo phố',
  'bao_tang': 'Bảo tàng',
  'kien_truc': 'Kiến trúc',
  'tam_linh': 'Tâm linh',
  'thien_nhien': 'Thiên nhiên',
  'chup_anh': 'Chụp ảnh',
  'mua_sam': 'Mua sắm',
  'buoi_toi': 'Buổi tối',
  'trai_nghiem': 'Trải nghiệm',
  'tre_em': 'Hợp trẻ em',
  'ngoai_thanh': 'Ngoại thành',
};

String composeRequest({
  required int days,
  required int adults,
  required int kids,
  required Set<String> picked,
  required String budget,
  required String note,
}) => [
  'Lần đầu đi Hà Nội $days ngày, $adults người lớn${kids > 0 ? ' và $kids trẻ em' : ''}.',
  if (picked.isNotEmpty)
    'Thích: ${picked.map((key) => interests[key]).join(', ')}.',
  if (budget.trim().isNotEmpty) 'Ngân sách vé khoảng ${budget.trim()} đồng.',
  if (note.trim().isNotEmpty) note.trim(),
].join(' ');

class HanoiApp extends StatefulWidget {
  const HanoiApp({super.key});

  @override
  State<HanoiApp> createState() => _HanoiAppState();
}

class _HanoiAppState extends State<HanoiApp> {
  final travel = TravelState()..sync = Sync(base: apiBase);

  @override
  void initState() {
    super.initState();
    if (travel.sync.enabled) {
      travel.sync.init().then((_) => travel.loadServerTrips());
    }
  }

  final homeSearch = TextEditingController();
  late final router = GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TravelShell(
          shell: shell,
          travel: travel,
          onChat: () {
            FocusManager.instance.primaryFocus?.unfocus();
            context.push(
              '/ai',
              extra: shell.currentIndex == 0 ? homeSearch.text.trim() : '',
            );
          },
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => HomePage(search: homeSearch),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => ExplorePage(travel: travel),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trips',
                builder: (context, state) => TripsPage(travel: travel),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) =>
                    ProfilePage(travel: travel, onLogout: homeSearch.clear),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/ai',
        builder: (context, state) => ChatPage(
          travel: travel,
          firstMessage: state.extra as String? ?? '',
        ),
      ),
    ],
  );

  @override
  void dispose() {
    router.dispose();
    homeSearch.dispose();
    unawaited(travel.sync.flush());
    travel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'Hanoi Travel Planner',
    routerConfig: router,
    scrollBehavior: const TravelScroll(),
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Nunito Sans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: brown,
        surface: surface,
        onSurface: ink,
        primary: brown,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 500),
      ),
    ),
    builder: (context, child) => ColoredBox(
      color: const Color(0xffecdac4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SizedBox.expand(child: Paper(child: child!)),
        ),
      ),
    ),
  );
}

class TravelShell extends StatelessWidget {
  const TravelShell({
    super.key,
    required this.shell,
    required this.onChat,
    this.travel,
  });
  final StatefulNavigationShell shell;
  final TravelState? travel;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(bottom: false, child: shell),
    bottomNavigationBar: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(9, 0, 9, 8),
      child: SizedBox(
        height: 77,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Material(
                elevation: 4,
                shadowColor: brown.withValues(alpha: .18),
                color: surface,
                borderRadius: BorderRadius.circular(26),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      navItem(
                        0,
                        'Home',
                        Icons.home_outlined,
                        Icons.home_rounded,
                      ),
                      navItem(
                        1,
                        'Explore',
                        Icons.explore_outlined,
                        Icons.explore,
                      ),
                      const Expanded(child: SizedBox()),
                      navItem(
                        2,
                        'My Trip',
                        Icons.work_outline_rounded,
                        Icons.work_rounded,
                      ),
                      navItem(
                        3,
                        'Profile',
                        Icons.person_outline_rounded,
                        Icons.person_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: surface,
                    boxShadow: shadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: brand,
                      ),
                      child: TextButton(
                        onPressed: onChat,
                        style: TextButton.styleFrom(
                          shape: const CircleBorder(),
                          fixedSize: const Size.square(52),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 20),
                            Text(
                              'AI',
                              style: TextStyle(fontSize: 12, height: 1.1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget navItem(int index, String label, IconData inactive, IconData active) {
    final selected = shell.currentIndex == index;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
          selected: selected,
          child: TextButton(
            onPressed: () {
              travel?.sync.log('mo_man_hinh', {'man': label});
              shell.goBranch(index);
            },
            style: TextButton.styleFrom(
              backgroundColor: selected ? tint : Colors.transparent,
              foregroundColor: selected ? brown : ink,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(selected ? active : inactive, size: 22),
                Text(label, style: const TextStyle(fontSize: 11, height: 1.2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
