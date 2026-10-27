import 'package:flutter/material.dart';
import '../models/alert.dart';
import '../screens/stock_recommendation_screen.dart';

class TradeAlertCard extends StatelessWidget {
  final StockAlert alert;
  final VoidCallback? onResponded;

  const TradeAlertCard({
    super.key,
    required this.alert,
    this.onResponded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isBuy = alert.action.toUpperCase() == 'BUY' || alert.alertType.contains('BUY');
    final action = isBuy ? 'BUY' : 'SELL';
    final actionColor = isBuy
        ? (isDark ? const Color(0xFF00E676) : const Color(0xFF15803D))
        : (isDark ? const Color(0xFFFF1744) : const Color(0xFFDC2626));
    final actionBg = isBuy
        ? (isDark ? const Color(0x1A00E676) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0x1AFF1744) : const Color(0xFFFEF2F2));

    final isUs = ['US', 'NASDAQ', 'NYSE', 'GLOBAL'].contains(alert.exchange.toUpperCase());
    final curr = isUs ? '\$' : '₹';

    final priceStr = alert.price != null ? '$curr${alert.price!.toStringAsFixed(2)}' : 'N/A';
    final targetStr = alert.target != null ? '$curr${alert.target!.toStringAsFixed(2)}' : 'None';
    final stopLossStr = alert.stopLoss != null ? '$curr${alert.stopLoss!.toStringAsFixed(2)}' : 'None';

    String rrStr = 'N/A';
    if (alert.price != null && alert.target != null && alert.stopLoss != null) {
      final risk = (alert.price! - alert.stopLoss!).abs();
      final reward = (alert.target! - alert.price!).abs();
      if (risk > 0) {
        rrStr = '1:${(reward / risk).toStringAsFixed(1)}';
      }
    }

    final isMonth = alert.timeHorizon.toUpperCase() == '1-MONTH';
    final horizonColor = isMonth ? const Color(0xFF7C3AED) : const Color(0xFFD97706);
    final horizonBg = isMonth
        ? (isDark ? const Color(0x267C3AED) : const Color(0xFFEDE9FE))
        : (isDark ? const Color(0x26D97706) : const Color(0xFFFEF3C7));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: actionColor, width: 4),
          top: BorderSide(color: alert.isRead ? theme.dividerColor : actionColor.withOpacity(0.35)),
          right: BorderSide(color: alert.isRead ? theme.dividerColor : actionColor.withOpacity(0.35)),
          bottom: BorderSide(color: alert.isRead ? theme.dividerColor : actionColor.withOpacity(0.35)),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0D0F172A),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Symbol + Exchange + Horizon + Action Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    alert.symbol,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Text(
                      alert.exchange,
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Horizon Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: horizonBg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: horizonColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      isMonth ? '📅 1-MO' : '⚡ 1-DAY',
                      style: TextStyle(
                        color: horizonColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!alert.isRead) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: actionBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: actionColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                      color: actionColor,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$action ALERT',
                      style: TextStyle(
                        color: actionColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tactical Numbers Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCol(context, 'PRICE', priceStr, theme.colorScheme.onSurface),
                _buildMetricCol(context, 'TARGET', targetStr, isBuy ? actionColor : theme.primaryColor),
                _buildMetricCol(context, 'STOP LOSS', stopLossStr, isDark ? const Color(0xFFFF1744) : const Color(0xFFDC2626)),
                _buildMetricCol(context, 'R:R', rrStr, theme.primaryColor),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Rationale / Gemini Pro Thesis
          if (alert.reason != null && alert.reason!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161C2E) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: theme.primaryColor, width: 3),
                ),
              ),
              child: Text(
                alert.reason!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Footer: Timestamp & Deep Research Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                alert.createdAt.toLocal().toString().substring(0, 16),
                style: TextStyle(
                  color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor, width: 1.0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.psychology, size: 16),
                label: const Text('Gemini Pro Research', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockRecommendationScreen(
                        symbol: alert.symbol,
                        exchange: alert.exchange,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(BuildContext context, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey.shade500 : const Color(0xFF64748B),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
