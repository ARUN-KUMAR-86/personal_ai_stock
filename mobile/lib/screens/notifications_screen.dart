import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/alert.dart';
import 'stock_recommendation_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool unreadOnly = false;

  void _openRecommendation(StockAlert alert) {
    if (!alert.isRead) {
      context.read<AppState>().markAlertRead(alert.id);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockRecommendationScreen(
          symbol: alert.symbol,
          exchange: alert.exchange,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final alertsList = unreadOnly ? state.alerts.where((a) => !a.isRead).toList() : state.alerts;

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: const Text('ALERTS & NOTIFICATIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.send_to_mobile),
            tooltip: 'Send Test Push Alert',
            onPressed: () async {
              final ok = await state.api.sendTestPushAlert();
              await state.refreshAll();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Test notification dispatched to Android phone.'
                      : 'Notification queued in database (FCM service account pending).'),
                  backgroundColor: ok ? Colors.green : Colors.amber.shade900,
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E222D),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${alertsList.length} ALERTS',
                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Unread Only', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Switch(
                      value: unreadOnly,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) => setState(() => unreadOnly = val),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Alerts List
          Expanded(
            child: alertsList.isEmpty
                ? Center(
                    child: Text(
                      'No notifications recorded.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: alertsList.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, idx) {
                      final alert = alertsList[idx];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: alert.isRead ? Colors.white.withOpacity(0.04) : Colors.blueAccent.withOpacity(0.4),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: alert.alertType.contains('BUY')
                                  ? Colors.green.withOpacity(0.2)
                                  : (alert.alertType.contains('SELL') || alert.alertType.contains('EXIT')
                                      ? Colors.red.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.2)),
                            ),
                            child: Icon(
                              alert.alertType.contains('BUY')
                                  ? Icons.trending_up
                                  : (alert.alertType.contains('SELL') || alert.alertType.contains('EXIT')
                                      ? Icons.trending_down
                                      : Icons.notifications),
                              size: 20,
                              color: alert.alertType.contains('BUY')
                                  ? Colors.greenAccent
                                  : (alert.alertType.contains('SELL') || alert.alertType.contains('EXIT')
                                      ? Colors.redAccent
                                      : Colors.lightBlueAccent),
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                alert.symbol,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: alert.isRead ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (!alert.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.blueAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                alert.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alert.createdAt.toLocal().toString().substring(0, 16),
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                              ),
                            ],
                          ),
                          onTap: () => _openRecommendation(alert),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
