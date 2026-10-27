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
    final isBuy = alert.action.toUpperCase() == 'BUY' || alert.alertType.contains('BUY');
    final action = isBuy ? 'BUY' : 'SELL';
    final actionColor = isBuy ? const Color(0xFF00E676) : const Color(0xFFFF1744);
    final actionBg = isBuy ? const Color(0x1A00E676) : const Color(0x1AFF1744);

    final priceStr = alert.price != null ? '₹${alert.price!.toStringAsFixed(2)}' : 'N/A';
    final targetStr = alert.target != null ? '₹${alert.target!.toStringAsFixed(2)}' : 'None';
    final stopLossStr = alert.stopLoss != null ? '₹${alert.stopLoss!.toStringAsFixed(2)}' : 'None';

    String rrStr = 'N/A';
    if (alert.price != null && alert.target != null && alert.stopLoss != null) {
      final risk = (alert.price! - alert.stopLoss!).abs();
      final reward = (alert.target! - alert.price!).abs();
      if (risk > 0) {
        rrStr = '1:${(reward / risk).toStringAsFixed(1)}';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: actionColor, width: 4),
          top: BorderSide(color: alert.isRead ? Colors.white.withOpacity(0.04) : actionColor.withOpacity(0.3)),
          right: BorderSide(color: alert.isRead ? Colors.white.withOpacity(0.04) : actionColor.withOpacity(0.3)),
          bottom: BorderSide(color: alert.isRead ? Colors.white.withOpacity(0.04) : actionColor.withOpacity(0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: alert.isRead ? Colors.black.withOpacity(0.2) : actionColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Symbol + Action Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    alert.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131722),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      alert.exchange,
                      style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (!alert.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.lightBlueAccent,
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
              color: const Color(0xFF131722),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricCol('PRICE', priceStr, Colors.white),
                _buildMetricCol('TARGET', targetStr, isBuy ? actionColor : Colors.lightBlueAccent),
                _buildMetricCol('STOP LOSS', stopLossStr, const Color(0xFFFF1744)),
                _buildMetricCol('R:R', rrStr, Colors.cyanAccent),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Rationale / Gemini Pro Thesis
          if (alert.reason != null && alert.reason!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF131722).withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                  left: BorderSide(color: Colors.cyanAccent, width: 2),
                ),
              ),
              child: Text(
                alert.reason!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ),
          const SizedBox(height: 12),

          // Footer: Timestamp & Deep Research Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                alert.createdAt.toLocal().toString().substring(0, 16),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent, width: 0.8),
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

  Widget _buildMetricCol(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.bold),
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
