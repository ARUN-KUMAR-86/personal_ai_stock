import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
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
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'AI Stock Intelligence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF131722),
        primaryColor: Colors.blueAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.lightBlueAccent,
          surface: Color(0xFF1E222D),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E222D),
          elevation: 0,
        ),
      ),
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
    NotificationsScreen(),
    ScannerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unreadCount = state.alerts.where((a) => !a.isRead).length;

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
        backgroundColor: const Color(0xFF1E222D),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey.shade500,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
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
            label: 'Internet Scanner',
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
