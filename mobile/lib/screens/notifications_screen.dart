import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/alert.dart';
import '../widgets/trade_alert_card.dart';
import '../widgets/zed_logo.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String selectedFilter = 'ALL';   // 'ALL', 'BUY', 'SELL'
  String selectedHorizon = 'ALL';  // 'ALL', '1-DAY', '1-MONTH'
  bool unreadOnly = false;

  static const int maxFifoNotifications = 100;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Enforce strict FIFO Queue limit of 100 notifications maximum
    List<StockAlert> alertsList = state.alerts;
    if (alertsList.length > maxFifoNotifications) {
      alertsList = alertsList.take(maxFifoNotifications).toList();
    }

    // 1. Action filter
    if (selectedFilter == 'BUY') {
      alertsList = alertsList.where((a) => a.action.toUpperCase() == 'BUY' || a.alertType.contains('BUY')).toList();
    } else if (selectedFilter == 'SELL') {
      alertsList = alertsList.where((a) => a.action.toUpperCase() == 'SELL' || a.alertType.contains('SELL')).toList();
    }

    // 2. Horizon filter
    if (selectedHorizon != 'ALL') {
      alertsList = alertsList.where((a) => a.timeHorizon.toUpperCase() == selectedHorizon).toList();
    }

    // 3. Unread filter
    if (unreadOnly) {
      alertsList = alertsList.where((a) => !a.isRead).toList();
    }

    final totalAlerts = state.alerts.length > maxFifoNotifications ? maxFifoNotifications : state.alerts.length;
    final unreadCount = state.alerts.take(maxFifoNotifications).where((a) => !a.isRead).length;
    final buyCount = state.alerts.take(maxFifoNotifications).where((a) => a.action.toUpperCase() == 'BUY' || a.alertType.contains('BUY')).length;
    final sellCount = state.alerts.take(maxFifoNotifications).where((a) => a.action.toUpperCase() == 'SELL' || a.alertType.contains('SELL')).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const ZedLogo(size: 24),
            const SizedBox(width: 8),
            Text(
              'ZED NOTIFICATIONS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.primaryColor),
            tooltip: 'Refresh Notifications',
            onPressed: () => state.refreshAll(),
          ),
          // Prominent "All Read" Button inside AppBar
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.blueAccent : theme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text(
              'All Read',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () async {
              await state.markAllAlertsRead();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ All notifications marked as read.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── FIFO Queue Info Bar with "All Read" Option ───────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_vert_rounded, size: 15, color: theme.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      'FIFO QUEUE ($totalAlerts/100 MAX)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                        ),
                        child: Text(
                          '$unreadCount UNREAD',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                // Prominent "All Read" text button inside banner
                InkWell(
                  onTap: () async {
                    await state.markAllAlertsRead();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ All notifications marked as read.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: unreadCount > 0
                              ? (isDark ? Colors.blueAccent : theme.primaryColor)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Mark All Read',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: unreadCount > 0
                                ? (isDark ? Colors.blueAccent : theme.primaryColor)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Tabs Bar (Action + Horizon)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              children: [
                // Row 1: Action (ALL / BUY / SELL) + Unread
                Row(
                  children: [
                    _buildFilterChip(
                      selectedFilter == 'ALL',
                      'All ($totalAlerts)',
                      theme.primaryColor,
                      () => setState(() => selectedFilter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      selectedFilter == 'BUY',
                      '🟢 BUY ($buyCount)',
                      isDark ? const Color(0xFF00E676) : const Color(0xFF15803D),
                      () => setState(() => selectedFilter = 'BUY'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      selectedFilter == 'SELL',
                      '🔴 SELL ($sellCount)',
                      isDark ? const Color(0xFFFF1744) : const Color(0xFFDC2626),
                      () => setState(() => selectedFilter = 'SELL'),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => setState(() => unreadOnly = !unreadOnly),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: unreadOnly ? theme.primaryColor.withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: unreadOnly ? theme.primaryColor : theme.dividerColor),
                        ),
                        child: Text(
                          'Unread',
                          style: TextStyle(
                            color: unreadOnly ? theme.primaryColor : (isDark ? Colors.grey : const Color(0xFF64748B)),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Row 2: Horizon Filter Chips (All Horizons / 1-DAY / 1-MONTH)
                Row(
                  children: [
                    _buildHorizonChip('ALL', 'All Horizons'),
                    const SizedBox(width: 8),
                    _buildHorizonChip('1-DAY', '⚡ 1-DAY (Short Term)'),
                    const SizedBox(width: 8),
                    _buildHorizonChip('1-MONTH', '📅 1-MONTH (Long Term)'),
                  ],
                ),
              ],
            ),
          ),

          // Alerts List Feed
          Expanded(
            child: alertsList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 54, color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text(
                          unreadOnly ? 'No unread notifications.' : 'No notifications in FIFO queue.',
                          style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF475569), fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'FIFO queue automatically manages the 100 most recent alerts.',
                          style: TextStyle(color: isDark ? Colors.grey.shade600 : const Color(0xFF94A3B8), fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.primaryColor,
                            side: BorderSide(color: theme.primaryColor.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => state.refreshAll(),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => state.refreshAll(),
                    child: ListView.builder(
                      itemCount: alertsList.length,
                      padding: const EdgeInsets.all(14),
                      itemBuilder: (context, idx) {
                        final alert = alertsList[idx];
                        return TradeAlertCard(
                          alert: alert,
                          onResponded: () => state.refreshAll(),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(bool isSelected, String label, Color color, VoidCallback onTap) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : (isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : (isDark ? Colors.grey.shade400 : const Color(0xFF475569)),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHorizonChip(String key, String label) {
    final isSelected = selectedHorizon == key;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = key == '1-MONTH'
        ? const Color(0xFF7C3AED)
        : (key == '1-DAY' ? const Color(0xFFD97706) : theme.primaryColor);

    return GestureDetector(
      onTap: () => setState(() => selectedHorizon = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : theme.dividerColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : (isDark ? Colors.grey.shade400 : const Color(0xFF64748B)),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
