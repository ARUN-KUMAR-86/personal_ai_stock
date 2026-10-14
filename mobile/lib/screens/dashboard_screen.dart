import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/market_badge.dart';
import '../widgets/stat_card.dart';
import '../widgets/signal_pill.dart';
import 'stock_recommendation_screen.dart';
import 'trading_control_screen.dart';
import 'settings_screen.dart';
import '../widgets/groww_login_dialog.dart';
import '../widgets/trade_alert_card.dart';
import '../widgets/priority_badge.dart';
import '../models/stock_summary.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isGrowwLive = state.safetyStatus?.executionMode == 'GROWW_LIVE' && state.isGrowwConnected;

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: const Text(
          'AI STOCK INTEL',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: 0.5),
        ),
        actions: [
          // Groww In-App Broker Login & Status Pill
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: state.isGrowwConnected
                  ? Colors.teal.withOpacity(0.2)
                  : Colors.amber.shade900.withOpacity(0.3),
              foregroundColor: state.isGrowwConnected ? Colors.tealAccent : Colors.amberAccent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: state.isGrowwConnected
                      ? Colors.tealAccent.withOpacity(0.4)
                      : Colors.amberAccent.withOpacity(0.4),
                ),
              ),
            ),
            onPressed: () => GrowwLoginDialog.show(context),
            icon: Icon(
              state.isGrowwConnected ? Icons.check_circle : Icons.link,
              size: 14,
            ),
            label: Text(
              state.isGrowwConnected
                  ? 'Groww (₹${(state.funds?.availableFunds ?? 0).toStringAsFixed(0)})'
                  : 'Log In to Groww',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => state.refreshAll(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // UltraSync Low-Latency Live Status Bar
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: state.isUltraSyncActive ? Colors.tealAccent.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: state.isUltraSyncActive ? Colors.greenAccent : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: state.isUltraSyncActive
                          ? [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.6),
                                blurRadius: 6,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isUltraSyncActive ? 'ULTRASYNC 24/7' : 'SYNC PAUSED',
                    style: TextStyle(
                      color: state.isUltraSyncActive ? Colors.tealAccent : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (state.syncLatencyMs < 150 ? Colors.green : (state.syncLatencyMs < 400 ? Colors.orange : Colors.blue)).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⚡ ${state.syncLatencyMs > 0 ? "${state.syncLatencyMs}ms" : "< 50ms"}',
                      style: TextStyle(
                        color: state.syncLatencyMs < 150 ? Colors.greenAccent : (state.syncLatencyMs < 400 ? Colors.orangeAccent : Colors.lightBlueAccent),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => state.executeUltraSync(silent: false),
                    child: const Tooltip(
                      message: 'Instant Force Sync',
                      child: Icon(Icons.flash_on, size: 16, color: Colors.amberAccent),
                    ),
                  ),
                ],
              ),
            ),

            // Auto-Sell Notification Banner
            if (state.lastAutoSellMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade900.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.tealAccent),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.tealAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.lastAutoSellMessage!,
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.white70),
                      onPressed: () => state.clearAutoSellMessage(),
                    ),
                  ],
                ),
              ),

            // Resilient Connectivity Banner
            if (!state.isOnline)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_sync_outlined, color: Colors.amberAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Local Simulation Sandbox Active',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your paper trades and positions are saved safely on your device. Auto-reconnecting to 24/7 cloud server...',
                            style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => state.refreshAll(),
                      child: const Text('Retry', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
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

            // Active Trading Execution Mode Banner
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isGrowwLive
                    ? Colors.teal.shade900.withOpacity(0.35)
                    : Colors.blueGrey.shade900.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isGrowwLive
                      ? Colors.tealAccent.withOpacity(0.5)
                      : Colors.lightBlueAccent.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isGrowwLive ? Icons.verified_user : Icons.science_outlined,
                    color: isGrowwLive ? Colors.tealAccent : Colors.lightBlueAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isGrowwLive ? 'GROWW LIVE TRADING' : 'PAPER TRADING (SAFE SANDBOX)',
                              style: TextStyle(
                                color: isGrowwLive ? Colors.tealAccent : Colors.lightBlueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isGrowwLive
                                    ? Colors.tealAccent.withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isGrowwLive ? 'LIVE' : 'SIMULATED',
                                style: TextStyle(
                                  color: isGrowwLive ? Colors.tealAccent : Colors.lightBlueAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isGrowwLive
                              ? 'Verified Groww Trade API active. Orders execute with real broker capital upon approval.'
                              : 'Orders are fully simulated. Zero capital risk. Auto-risk controls active.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => GrowwLoginDialog.show(context),
                    child: Text(
                      isGrowwLive ? 'Manage' : 'Switch Mode',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pending Trade Alerts requiring owner approval (Section 4)
            if (state.pendingTradeAlerts.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade900.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.gavel, color: Colors.amberAccent, size: 14),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'ACTION REQUIRED: TRADE APPROVAL',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${state.pendingTradeAlerts.length} PENDING',
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...state.pendingTradeAlerts.map((alert) => TradeAlertCard(alert: alert)),
                  ],
                ),
              ),
            ],

            // Dedicated Trading Controls Card (Section 3)
            _buildTradingControlSummaryCard(context, state),

            // 1. TOP PRIORITY: AI OPPORTUNITIES (Notification-First Hero)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade900.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_active, color: Colors.amberAccent, size: 14),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'PRIORITY AI OPPORTUNITIES',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Notification-First Approval',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (state.latestSignals.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.radar, color: Colors.blueAccent, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI Scanner is Monitoring Markets',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'High-confidence trading recommendations will appear here instantly with full analysis.',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...state.latestSignals.take(4).map((sig) {
                      final isHigh = sig.isHighPriority;
                      final isMed = sig.isMediumPriority;
                      // Strict user requirement: Highest Priority = RED, Medium = GREEN
                      final Color priorityColor = isHigh
                          ? Colors.redAccent
                          : (isMed ? Colors.greenAccent : Colors.lightBlueAccent);
                      final Color priorityBg = isHigh
                          ? const Color(0xFF2E1218)
                          : (isMed ? const Color(0xFF10281C) : const Color(0xFF1E222D));

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: priorityBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: priorityColor.withOpacity(0.85),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: priorityColor.withOpacity(0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Priority Indicator Row (Red for High, Green for Medium)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                PriorityBadge(priority: sig.priority),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '⚡ Auto Take Money',
                                    style: TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // 2. Symbol & Price Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      sig.symbol,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SignalPill(signalType: sig.signalType, strength: sig.strength),
                                  ],
                                ),
                                Text(
                                  '₹${sig.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 3. Narrative Explanation
                            Text(
                              sig.explanation,
                              style: TextStyle(color: Colors.grey.shade300, fontSize: 12, height: 1.35),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),

                            // 4. Target & Stop-loss
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Target: ₹${sig.target?.toStringAsFixed(2) ?? "--"} • SL: ₹${sig.stopLoss?.toStringAsFixed(2) ?? "--"}',
                                  style: TextStyle(
                                    color: sig.target != null ? priorityColor : Colors.grey.shade400,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${sig.holdingPeriodHours}h Hold • R:R 1:${sig.riskReward?.toStringAsFixed(1) ?? "2.0"}',
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // 5. Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isHigh ? Colors.red.shade800 : Colors.green.shade700,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StockRecommendationScreen(
                                        symbol: sig.symbol,
                                        exchange: sig.exchange,
                                        initialSignal: sig,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.touch_app, size: 16),
                                label: Text(
                                  'Take Opportunity (Target ₹${sig.target?.toStringAsFixed(0) ?? "--"})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            // 2. USER PERSISTENT WATCHLIST SECTION
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'MY WATCHLIST (${state.watchlistSymbols.length})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      if (state.watchlistSymbols.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: state.isScanningWatchlist ? null : () => state.scanWatchlist(),
                          icon: state.isScanningWatchlist
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                                )
                              : const Icon(Icons.radar, size: 14, color: Colors.amberAccent),
                          label: Text(
                            state.isScanningWatchlist ? 'Scanning...' : 'Scan Watchlist',
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.watchlistSymbols.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star_outline, color: Colors.grey.shade500, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No stocks watchlisted yet. Tap ⭐ on any stock in the Scanner to pin priority tickers here.',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 125,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.watchlistItems.isNotEmpty
                            ? state.watchlistItems.length
                            : state.watchlistSymbols.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final item = state.watchlistItems.isNotEmpty ? state.watchlistItems[idx] : null;
                          final symbol = item?.symbol ?? state.watchlistSymbols.elementAt(idx);
                          final stock = item?.stock ??
                              state.stocks.firstWhere(
                                (s) => s.symbol.toUpperCase() == symbol.toUpperCase(),
                                orElse: () => StockSummary(
                                  symbol: symbol,
                                  exchange: 'NSE',
                                  name: symbol,
                                  isLive: false,
                                  latestSignal: 'NO TRADE',
                                  signalStrength: 0.0,
                                ),
                              );

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StockRecommendationScreen(
                                    symbol: symbol,
                                    exchange: stock.exchange,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 175,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E222D),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          symbol,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => state.toggleWatchlist(symbol),
                                        child: const Padding(
                                          padding: EdgeInsets.all(2.0),
                                          child: Icon(Icons.star, color: Colors.amberAccent, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    stock.latestPrice != null
                                        ? '₹${stock.latestPrice!.toStringAsFixed(2)}'
                                        : 'Awaiting Quote',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      SignalPill(signalType: stock.latestSignal, strength: stock.signalStrength),
                                      const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

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
                border: Border.all(
                  color: state.isScheduleActive
                      ? Colors.tealAccent.withOpacity(0.3)
                      : Colors.white.withOpacity(0.06),
                ),
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
                            color: state.isScanning
                                ? Colors.amberAccent
                                : (state.isScheduleActive ? Colors.tealAccent : Colors.lightBlueAccent),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'CLOUD AI SCANNER',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: state.isScheduleActive
                              ? Colors.teal.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: state.isScheduleActive
                                ? Colors.tealAccent
                                : Colors.grey.shade600,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          state.isScheduleActive ? 'SCHEDULE ACTIVE' : 'PAUSED',
                          style: TextStyle(
                            color: state.isScheduleActive ? Colors.tealAccent : Colors.grey.shade400,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.lastScanInfo ??
                        (state.isScheduleActive
                            ? 'Server-side analysis active every ${state.scheduleIntervalMinutes} min. Runs even when mobile app is closed.'
                            : 'Automated analysis is paused. Start analysis to run cloud market scans automatically.'),
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Start / Stop Analysis Button
                      Expanded(
                        child: state.isScheduleActive
                            ? OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.amberAccent.withOpacity(0.5)),
                                  foregroundColor: Colors.amberAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: state.isTogglingSchedule ? null : () => state.stopScheduleAnalysis(),
                                icon: state.isTogglingSchedule
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                                      )
                                    : const Icon(Icons.pause, size: 16),
                                label: const Text('Stop Analysis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              )
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: state.isTogglingSchedule ? null : () => state.startScheduleAnalysis(),
                                icon: state.isTogglingSchedule
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.play_arrow, size: 16),
                                label: const Text('Start Analysis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                      ),
                      const SizedBox(width: 10),
                      // Manual Scan Now Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: state.isScanning ? null : () => state.triggerScan(),
                        icon: state.isScanning
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: Text(state.isScanning ? 'Scanning...' : 'Scan Now'),
                      ),
                    ],
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
                          builder: (_) => StockRecommendationScreen(
                            symbol: sig.symbol,
                            exchange: sig.exchange,
                            initialSignal: sig,
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

  Widget _buildTradingControlSummaryCard(BuildContext context, AppState state) {
    final tc = state.tradingControl;
    final isTradingActive = tc?.isTradingActive ?? true;
    final isLiveBroker = state.isGrowwConnected;
    final accountStatusText = tc?.growwAccountStatus ?? (isLiveBroker ? 'Connected' : 'Not Connected (Paper Mode)');
    final isConn = accountStatusText.startsWith('Connected') && !accountStatusText.contains('Not');
    final statusColor = isConn
        ? Colors.tealAccent
        : (accountStatusText.contains('Expired') ? Colors.amberAccent : Colors.grey.shade400);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Colors.blueAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'PERSONAL AI STOCK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TradingControlScreen()),
                ),
                child: Row(
                  children: [
                    Text(
                      'Controls Screen',
                      style: TextStyle(color: Colors.blueAccent.shade100, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 16, color: Colors.blueAccent.shade100),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Groww Account', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        accountStatusText,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Trading Budget', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${(tc?.tradingBudget ?? 300.0).toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Available Funds', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${(tc?.availableFunds ?? 1000.0).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Today's P/L", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    '${(tc?.todaysPnl ?? 0) >= 0 ? "+" : ""}₹${(tc?.todaysPnl ?? 0.0).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: (tc?.todaysPnl ?? 0) >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTradingActive ? Colors.red.shade900.withOpacity(0.7) : Colors.teal.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: state.isTradingToggling
                      ? null
                      : () => isTradingActive ? state.stopTrading() : state.startTrading(),
                  icon: Icon(isTradingActive ? Icons.stop_circle_outlined : Icons.play_arrow_outlined, size: 16),
                  label: Text(
                    isTradingActive ? 'Stop Trading' : 'Start Trading',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TradingControlScreen()),
                  ),
                  icon: const Icon(Icons.settings_input_component, size: 15),
                  label: const Text('Trading Settings', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
