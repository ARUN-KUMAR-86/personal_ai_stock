import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alert.dart';
import '../state/app_state.dart';

class TradeAlertCard extends StatefulWidget {
  final StockAlert alert;
  final VoidCallback? onResponded;

  const TradeAlertCard({
    super.key,
    required this.alert,
    this.onResponded,
  });

  @override
  State<TradeAlertCard> createState() => _TradeAlertCardState();
}

class _TradeAlertCardState extends State<TradeAlertCard> {
  bool _isProcessing = false;

  Future<void> _handleResponse(String action) async {
    setState(() => _isProcessing = true);
    final state = context.read<AppState>();
    final success = await state.respondToTradeAlert(widget.alert.id, action);
    if (mounted) {
      setState(() => _isProcessing = false);
      if (widget.onResponded != null) {
        widget.onResponded!();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'APPROVE'
                ? (success
                    ? 'Order placed and verified with broker! Updated funds & P/L.'
                    : state.errorMessage ?? 'Execution failed. Check Groww authorization.')
                : 'Trade rejected. No order was placed.',
          ),
          backgroundColor: action == 'APPROVE'
              ? (success ? Colors.green.shade800 : Colors.red.shade900)
              : Colors.grey.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final isBuy = alert.action.toUpperCase() == 'BUY';
    final actionColor = isBuy ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: alert.isPendingApproval ? actionColor.withOpacity(0.5) : Colors.white12,
          width: alert.isPendingApproval ? 1.5 : 1,
        ),
        boxShadow: alert.isPendingApproval
            ? [
                BoxShadow(
                  color: actionColor.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PERSONAL AI STOCK — TRADE ALERT',
                style: TextStyle(
                  color: actionColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: alert.isPendingApproval
                      ? Colors.amber.withOpacity(0.2)
                      : (alert.status == 'EXECUTED' ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alert.status.replaceAll('_', ' '),
                  style: TextStyle(
                    color: alert.isPendingApproval
                        ? Colors.amberAccent
                        : (alert.status == 'EXECUTED' ? Colors.greenAccent : Colors.grey.shade400),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Core Trade Alert Grid
          _buildInfoRow('Stock:', '${alert.symbol} (${alert.exchange})', isBold: true),
          _buildInfoRow('Action:', alert.action.toUpperCase(), valueColor: actionColor, isBold: true),
          _buildInfoRow('Suggested investment:', '₹${alert.suggestedInvestment.toStringAsFixed(0)}'),
          _buildInfoRow('Estimated quantity:', '${alert.estimatedQuantity} shares'),
          _buildInfoRow('Estimated order value:', '₹${alert.estimatedOrderValue.toStringAsFixed(2)}'),
          _buildInfoRow('Reason:', alert.reason ?? 'AI analysis and market signals'),
          _buildInfoRow('Risk:', alert.riskLevel, valueColor: _getRiskColor(alert.riskLevel)),
          _buildInfoRow('Stop-loss:', alert.stopLoss != null ? '₹${alert.stopLoss!.toStringAsFixed(2)}' : 'Suggested price level'),
          _buildInfoRow('Target:', alert.target != null ? '₹${alert.target!.toStringAsFixed(2)}' : 'Suggested price level'),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),

          // Actions / Status
          if (alert.isPendingApproval) ...[
            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBuy ? Colors.green.shade700 : Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _handleResponse('APPROVE'),
                      child: Text(
                        'APPROVE ${alert.action.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade300,
                        side: BorderSide(color: Colors.grey.shade600),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _handleResponse('REJECT'),
                      child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'No order is placed until you approve it.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF131722),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    alert.status == 'EXECUTED' ? Icons.check_circle : Icons.cancel,
                    color: alert.status == 'EXECUTED' ? Colors.greenAccent : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.status == 'EXECUTED'
                          ? 'Executed with broker verification (Order #${alert.orderId ?? "COMPLETED"})'
                          : 'Order proposal rejected by owner.',
                      style: TextStyle(
                        color: alert.status == 'EXECUTED' ? Colors.white70 : Colors.grey.shade400,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'low':
        return Colors.greenAccent;
      case 'high':
        return Colors.redAccent;
      default:
        return Colors.amberAccent;
    }
  }
}
