import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/market_badge.dart';
import '../widgets/stat_card.dart';
import '../widgets/signal_pill.dart';
import 'stock_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: const Text(
          'AI STOCK INTEL',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => state.refreshAll(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connectivity warning if backend offline
            if (!state.isOnline)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage ?? 'Backend offline. Go to Settings to set LAN IP.',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Market Session Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Indian Markets (${state.marketStatus?.exchange ?? 'NSE'})',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      state.marketStatus?.serverTimeIst.isNotEmpty == true
                          ? state.marketStatus!.serverTimeIst
                          : 'IST Time',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                MarketBadge(
                  status: state.marketStatus?.status ?? 'CLOSED',
                  serverTime: state.marketStatus?.serverTimeIst ?? '',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Summary Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(
                  title: 'Tracked Universe',
                  value: '${state.stocks.length} Stocks',
                  subtitle: 'NIFTY 50 & High Liquidity',
                  icon: Icons.list_alt,
                ),
                StatCard(
                  title: 'Latest Signals',
                  value: '${state.latestSignals.length}',
                  subtitle: 'Actionable Opportunities',
                  icon: Icons.auto_awesome,
                  valueColor: Colors.amberAccent,
                ),
                StatCard(
                  title: 'Paper Portfolio',
                  value: '₹${state.portfolio?.totalPortfolioValue.toStringAsFixed(0) ?? '0'}',
                  subtitle: 'Exposure: ${state.portfolio?.portfolioExposurePct ?? 0}%',
                  icon: Icons.account_balance_wallet,
                ),
                StatCard(
                  title: 'Unrealized P&L',
                  value: '₹${state.portfolio?.totalUnrealizedPnl.toStringAsFixed(2) ?? '0.00'}',
                  subtitle: '${state.portfolio?.openPositionsCount ?? 0} open positions',
                  icon: Icons.trending_up,
                  valueColor: (state.portfolio?.totalUnrealizedPnl ?? 0) >= 0
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Scanner Control & Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.radar,
                            color: state.isScanning ? Colors.amberAccent : Colors.lightBlueAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'BACKGROUND SCANNER',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: state.isScanning ? null : () => state.triggerScan(),
                        icon: state.isScanning
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow, size: 16),
                        label: Text(state.isScanning ? 'Scanning...' : 'Scan Now'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.lastScanInfo ?? 'Last Scan: Ready. Runs automatically every 15 min.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Actionable Signals Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RECENT SIGNALS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Rule Confluence',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (state.latestSignals.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No recent signals. Tap "Scan Now" to scan the stock universe.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...state.latestSignals.map((sig) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E222D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          sig.symbol,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '₹${sig.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SignalPill(signalType: sig.signalType, strength: sig.strength),
                            Text(
                              sig.strategyName,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sig.explanation,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockDetailScreen(
                            symbol: sig.symbol,
                            exchange: sig.exchange,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
