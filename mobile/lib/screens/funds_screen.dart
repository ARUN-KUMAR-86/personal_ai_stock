import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class FundsScreen extends StatelessWidget {
  const FundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final funds = state.funds;

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: const Text('TRADING FUNDS & BROKER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Broker Funds',
            onPressed: () => state.syncBrokerFunds(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.syncBrokerFunds(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Broker Integration Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (funds?.isConnected ?? false) ? Colors.green.withOpacity(0.5) : Colors.amber.withOpacity(0.5),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (funds?.isConnected ?? false)
                          ? Colors.green.withOpacity(0.2)
                          : Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (funds?.isConnected ?? false) ? Icons.check_circle : Icons.link_off,
                      color: (funds?.isConnected ?? false) ? Colors.greenAccent : Colors.amberAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GROWW BROKER: ${(funds?.isConnected ?? false) ? 'CONNECTED' : 'UNCONFIGURED'}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (funds?.isConnected ?? false)
                              ? 'Live sync active with Groww Trade API.'
                              : 'Groww API auth token not configured in backend/.env. Running in unlinked safety mode.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Funds Overview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AVAILABLE TRADING BALANCE',
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${funds?.availableFunds.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildFundTile(
                        'Unsettled Proceeds',
                        '₹${funds?.unsettledFunds.toStringAsFixed(2) ?? '0.00'}',
                        'T+1 clearing settlement',
                      ),
                      _buildFundTile(
                        'Withdrawable Funds',
                        '₹${funds?.withdrawableFunds.toStringAsFixed(2) ?? '0.00'}',
                        'Eligible for bank payout',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (funds?.lastSyncedAt != null)
                    Text(
                      'Last Broker Sync: ${funds!.lastSyncedAt!.toLocal().toString().substring(0, 19)}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Manual Trading Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF171A24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.lightBlueAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'MANUAL-TRADING-FIRST ARCHITECTURE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For capital protection, automated real-money orders are disabled by default. '
                    'Use alerts as decision support: review signal parameters, calculate position sizing, '
                    'and place trades manually in the official Groww mobile app or website.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundTile(String title, String amount, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(amount, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(desc, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
      ],
    );
  }
}
