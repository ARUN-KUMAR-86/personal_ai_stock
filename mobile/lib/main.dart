import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'screens/live_monitoring_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/settings_screen.dart';

import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

    // White & Blue Theme (Default)
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Clean soft slate
      primaryColor: const Color(0xFF2563EB),           // Royal Blue
      cardColor: Colors.white,
      canvasColor: const Color(0xFFF1F5F9),
      dividerColor: const Color(0xFFE2E8F0),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2563EB),
        secondary: Color(0xFF0284C7),
        surface: Colors.white,
        onSurface: Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0.5,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF2563EB),
        unselectedItemColor: Color(0xFF64748B),
        elevation: 8,
      ),
    );

    // Dark Mode Theme
    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0F19), // Deep dark navy
      primaryColor: const Color(0xFF3B82F6),           // Bright blue
      cardColor: const Color(0xFF111827),
      canvasColor: const Color(0xFF0B0F19),
      dividerColor: const Color(0xFF1F2937),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF38BDF8),
        surface: Color(0xFF111827),
        onSurface: Color(0xFFF8FAFC),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111827),
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFF8FAFC)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF111827),
        selectedItemColor: Color(0xFF3B82F6),
        unselectedItemColor: Color(0xFF94A3B8),
        elevation: 0,
      ),
    );

    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Zed',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
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
    NotificationsScreen(),
    ScannerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unreadCount = state.alerts.where((a) => !a.isRead).length;
    final isDark = state.isDarkMode;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        selectedItemColor: isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
        unselectedItemColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            activeIcon: Icon(Icons.sensors, color: Color(0xFF10B981)),
            label: 'Live Monitor',
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
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            activeIcon: Icon(Icons.radar, color: Colors.blueAccent),
            label: 'AI Scanner',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
