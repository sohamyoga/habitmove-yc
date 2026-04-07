import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'services/offline_service.dart';
import 'services/offline_cache_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/dashboard/profile_screen.dart';
import 'screens/courses/courses_screen.dart';
import 'screens/quiz/quiz_screen.dart';
import 'screens/membership/membership_screen.dart';
import 'screens/offline/offline_screen.dart';
import 'screens/support/support_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  final auth = AuthProvider();
  await auth.init();

  // Initialise notification service (graceful if Firebase not configured)
  await NotificationService.instance.init();

  // Initialise offline/cache service
  await OfflineService.instance.init();

  // Initialise offline cache (Hive + connectivity watcher)
  await OfflineCacheService.instance.init();

  runApp(
    ChangeNotifierProvider.value(
      value: auth,
      child: const HabitMoveApp(),
    ),
  );
}

class HabitMoveApp extends StatelessWidget {
  const HabitMoveApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'HabitMove',
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: const _AppRoot(),
  );
}

// ─── Root: auth gate ─────────────────────────────────────────────────────────

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) return const _MainShell();
    return const _AuthGate();
  }
}

// ─── Auth gate (login / register switcher) ────────────────────────────────────

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _showLogin = true;

  @override
  Widget build(BuildContext context) => _showLogin
      ? LoginScreen(onGoRegister: () => setState(() => _showLogin = false))
      : RegisterScreen(onGoLogin: () => setState(() => _showLogin = true));
}

// ─── Main shell with bottom nav ───────────────────────────────────────────────

class _MainShell extends StatefulWidget {
  const _MainShell();
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  static const _tabs = [
    _TabItem(icon: Icons.dashboard_outlined,       activeIcon: Icons.dashboard_rounded,       label: 'Home'),
    _TabItem(icon: Icons.school_outlined,           activeIcon: Icons.school_rounded,           label: 'Courses'),
    _TabItem(icon: Icons.quiz_outlined,             activeIcon: Icons.quiz_rounded,             label: 'Quizzes'),
    _TabItem(icon: Icons.card_membership_outlined,  activeIcon: Icons.card_membership_rounded,  label: 'Membership'),
    _TabItem(icon: Icons.download_outlined,         activeIcon: Icons.download_done_rounded,    label: 'Offline'),
    _TabItem(icon: Icons.person_outline_rounded,    activeIcon: Icons.person_rounded,           label: 'Profile'),
  ];

  static const _screens = [
    DashboardScreen(),
    CoursesScreen(),
    QuizScreen(),
    MembershipScreen(),
    OfflineScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _index,
      children: _screens,
    ),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.sage100, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: _tabs.map((t) => BottomNavigationBarItem(
          icon: Icon(t.icon),
          activeIcon: Icon(t.activeIcon),
          label: t.label,
        )).toList(),
      ),
    ),
  );
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({required this.icon, required this.activeIcon, required this.label});
}
