import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/alert.dart';
import '../widgets/trade_alert_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String selectedFilter = 'ALL'; // 'ALL', 'BUY', 'SELL'
  bool unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Filter alerts
    List<StockAlert> alertsList = state.alerts;
    if (selectedFilter == 'BUY') {
      alertsList = alertsList.where((a) => a.action.toUpperCase() == 'BUY' || a.alertType.contains('BUY')).toList();
    } else if (selectedFilter == 'SELL') {
      alertsList = alertsList.where((a) => a.action.toUpperCase() == 'SELL' || a.alertType.contains('SELL')).toList();
    }

    if (unreadOnly) {
      alertsList = alertsList.where((a) => !a.isRead).toList();
    }

    final buyCount = state.alerts.where((a) => a.action.toUpperCase() == 'BUY' || a.alertType.contains('BUY')).length;
    final sellCount = state.alerts.where((a) => a.action.toUpperCase() == 'SELL' || a.alertType.contains('SELL')).length;

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: const Row(
          children: [
            Text('⚡ ', style: TextStyle(fontSize: 18)),
            Text('STOCK NOTIFICATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            tooltip: 'Refresh Notifications',
            onPressed: () => state.refreshAll(),
          ),
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.grey),
            tooltip: 'Mark All Read',
            onPressed: () {
              final unread = state.alerts.where((a) => !a.isRead).map((a) => a.id).toList();
              if (unread.isNotEmpty) {
                state.markAlertsRead(unread);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All alerts marked as read.')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E222D),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All (${state.alerts.length})', null),
                const SizedBox(width: 8),
                _buildFilterChip('BUY', '🟢 BUY ($buyCount)', const Color(0xFF00E676)),
                const SizedBox(width: 8),
                _buildFilterChip('SELL', '🔴 SELL ($sellCount)', const Color(0xFFFF1744)),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => unreadOnly = !unreadOnly),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: unreadOnly ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: unreadOnly ? Colors.blueAccent : Colors.white24),
                    ),
                    child: Text(
                      'Unread',
                      style: TextStyle(
                        color: unreadOnly ? Colors.blueAccent : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                        const Icon(Icons.radar, size: 54, color: Colors.white24),
                        const SizedBox(height: 12),
                        Text(
                          'No $selectedFilter notifications yet.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Run Internet Scanner to discover setups.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => state.refreshAll(),
                    child: ListView.builder(
                      itemCount: alertsList.length,
                      padding: const EdgeInsets.all(16),
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

  Widget _buildFilterChip(String filterKey, String label, Color? activeColor) {
    final isSelected = selectedFilter == filterKey;
    final color = activeColor ?? Colors.blueAccent;

    return GestureDetector(
      onTap: () => setState(() => selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : const Color(0xFF131722),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey.shade400,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
