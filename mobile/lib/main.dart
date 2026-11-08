import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/live_monitoring_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('FLUTTER_ERROR_EXACT: ${details.exception}');
    // ignore: avoid_print
    print('FLUTTER_STACK_EXACT: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: avoid_print
    print('FLUTTER_ASYNC_ERROR: $error');
    // ignore: avoid_print
    print('FLUTTER_ASYNC_STACK: $stack');
    return true;
  };

  final appState = AppState();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
      ],
      child: const PersonalStockApp(),
    ),
  );

  // Initialize push notification & background listeners post-render
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await NotificationService().initialize(apiService: appState.api);
    } catch (e) {
      debugPrint('NotificationService init error (gracefully running local): $e');
    }
  });
}

class PersonalStockApp extends StatelessWidget {
  const PersonalStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Zed Terminal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    LiveMonitoringScreen(),
    ScannerScreen(),
    PortfolioScreen(),
    NotificationsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unreadCount = state.alerts.where((a) => !a.isRead).length;
    final isDark = state.isDarkMode;
    final isTabletOrDesktop = MediaQuery.of(context).size.width >= 800;

    if (isTabletOrDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
              labelType: NavigationRailLabelType.all,
              backgroundColor: isDark ? const Color(0xFF0B101D) : Colors.white,
              selectedIconTheme: IconThemeData(
                color: isDark ? AppTheme.accentCyan : const Color(0xFF1D4ED8),
              ),
              unselectedIconTheme: IconThemeData(
                color: AppTheme.textMuted(isDark),
              ),
              selectedLabelTextStyle: TextStyle(
                color: isDark ? AppTheme.accentCyan : const Color(0xFF1D4ED8),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: AppTheme.textMuted(isDark),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00F0FF), Color(0xFF2563EB)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Z',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.sensors_outlined),
                  selectedIcon: Icon(Icons.sensors, color: Color(0xFF00E676)),
                  label: Text('Live Feed'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.radar_outlined),
                  selectedIcon: Icon(Icons.radar),
                  label: Text('Scanner'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: Text('Portfolio'),
                ),
                NavigationRailDestination(
                  icon: unreadCount > 0
                      ? Badge(label: Text('$unreadCount'), child: const Icon(Icons.notifications_none))
                      : const Icon(Icons.notifications_none),
                  selectedIcon: unreadCount > 0
                      ? Badge(label: Text('$unreadCount'), child: const Icon(Icons.notifications))
                      : const Icon(Icons.notifications),
                  label: Text('Alerts ($unreadCount)'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B101D) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? const Color(0xFF0B101D) : Colors.white,
          selectedItemColor: isDark ? AppTheme.accentCyan : const Color(0xFF1D4ED8),
          unselectedItemColor: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          selectedFontSize: 11,
          unselectedFontSize: 10.5,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.sensors),
              activeIcon: Icon(Icons.sensors, color: Color(0xFF00E676)),
              label: 'Live Feed',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.radar),
              activeIcon: Icon(Icons.radar, color: Color(0xFF00F0FF)),
              label: 'AI Scanner',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF38BDF8)),
              label: 'Portfolio',
            ),
            BottomNavigationBarItem(
              icon: unreadCount > 0
                  ? Badge(
                      label: Text('$unreadCount'),
                      child: const Icon(Icons.notifications_none),
                    )
                  : const Icon(Icons.notifications_none),
              activeIcon: unreadCount > 0
                  ? Badge(
                      label: Text('$unreadCount'),
                      child: const Icon(Icons.notifications),
                    )
                  : const Icon(Icons.notifications),
              label: 'Alerts',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Terminal',
            ),
          ],
        ),
      ),
    );
  }
}
