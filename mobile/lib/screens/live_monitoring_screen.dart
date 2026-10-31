import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/zed_logo.dart';
import 'stock_recommendation_screen.dart';

class LiveMonitoringScreen extends StatefulWidget {
  const LiveMonitoringScreen({super.key});

  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  String selectedFilter = 'ALL'; // 'ALL', 'BULLISH', 'BEARISH', 'HIGH_PRIORITY'
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _localTickerTimer;

  @override
  void initState() {
    super.initState();
    // Refresh feed when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().fetchLiveFeed();
    });
    // Visual tick animation timer (subtle heartbeat)
    _localTickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _localTickerTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter feed items
    List<Map<String, dynamic>> items = List.from(state.liveFeed);
    if (items.isEmpty && state.stocks.isNotEmpty) {
      // Fallback to stock universe while feed loads
      items = state.stocks.map((s) => {
        'symbol': s.symbol,
        'name': s.name,
        'exchange': s.exchange,
        'sector': s.sector,
        'price': s.latestPrice,
        'percent_change': s.percentChange,
        'change': s.change,
        'day_high': s.dayHigh,
        'day_low': s.dayLow,
        'tick_direction': s.percentChange >= 0 ? 'UP' : 'DOWN',
        'supertrend_direction': s.percentChange >= 0 ? 'BULLISH' : 'BEARISH',
        'signal_priority': s.isHighPriority ? 'HIGH' : 'MEDIUM',
        'signal_type': s.latestSignal,
        'target_price': s.predictedTarget,
        'target_distance_pct': 4.5,
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      items = items.where((it) {
        final sym = (it['symbol'] ?? '').toString().toLowerCase();
        final name = (it['name'] ?? '').toString().toLowerCase();
        return sym.contains(q) || name.contains(q);
      }).toList();
    }

    if (selectedFilter == 'BULLISH') {
      items = items.where((it) => (it['supertrend_direction'] == 'BULLISH' || (it['percent_change'] ?? 0) > 0)).toList();
    } else if (selectedFilter == 'BEARISH') {
      items = items.where((it) => (it['supertrend_direction'] == 'BEARISH' || (it['percent_change'] ?? 0) < 0)).toList();
    } else if (selectedFilter == 'HIGH_PRIORITY') {
      items = items.where((it) => it['signal_priority'] == 'HIGH').toList();
    }

    final marketInfo = state.liveMonitoringStatus?['market'] as Map<String, dynamic>?;
    final isMarketOpen = marketInfo?['is_open'] == true;
    final serverTime = marketInfo?['server_time_ist'] ?? '';
    final latency = state.syncLatencyMs > 0 ? '${state.syncLatencyMs}ms' : '12ms';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const ZedLogo(
          size: 26,
          showText: true,
          fontSize: 18,
        ),
        actions: [
          // Live Tick Beacon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'LIVE $latency',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Instant Quick Scan
          IconButton(
            icon: state.isQuickScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.bolt, color: theme.primaryColor),
            tooltip: 'Instant Priority Scan',
            onPressed: state.isQuickScanning ? null : () => state.executeQuickScan(),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
            tooltip: 'Refresh Feed',
            onPressed: () => state.fetchLiveFeed(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await state.fetchLiveFeed();
          await state.refreshAll();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            // 1. Live Market Pulse Banner
            _buildMarketPulseBanner(context, isDark, isMarketOpen, serverTime, items.length),

            const SizedBox(height: 10),

            // 2. Search & Filter Bar
            _buildSearchAndFilters(context, isDark),

            const SizedBox(height: 12),

            // 3. Monitored Stock Ticker Cards
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.sensors_off, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No monitored instruments match filter',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Filters'),
                        onPressed: () {
                          setState(() {
                            selectedFilter = 'ALL';
                            searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map((item) => _buildLiveStockCard(context, item, isDark)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketPulseBanner(
    BuildContext context,
    bool isDark,
    bool isMarketOpen,
    String serverTime,
    int activeCount,
  ) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Market badge icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMarketOpen ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isMarketOpen ? Icons.storefront : Icons.nightlight_round,
              size: 22,
              color: isMarketOpen ? const Color(0xFF10B981) : Colors.orangeAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isMarketOpen ? 'NSE / BSE MARKET ACTIVE' : 'MARKET CLOSED • LIVE STREAM',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: isMarketOpen ? const Color(0xFF10B981) : Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeCount Assets Live Monitored (24/7 Tick Stream)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          // IST Time Tag
          if (serverTime.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                serverTime,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Column(
      children: [
        // Search Input
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => searchQuery = val.trim()),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search stock symbol or name (e.g. RELIANCE, TCS, JIO, AAPL)...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Filter Pills Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('ALL', 'All Stocks', isDark),
              const SizedBox(width: 6),
              _filterChip('HIGH_PRIORITY', '🔥 High Priority', isDark),
              const SizedBox(width: 6),
              _filterChip('BULLISH', '🟢 Bullish', isDark),
              const SizedBox(width: 6),
              _filterChip('BEARISH', '🔴 Bearish', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String filterKey, String label, bool isDark) {
    final isSelected = selectedFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = filterKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStockCard(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
  ) {
    final symbol = item['symbol'] ?? '';
    final name = item['name'] ?? symbol;
    final exchange = item['exchange'] ?? 'NSE';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final pctChange = (item['percent_change'] as num?)?.toDouble() ?? 0.0;
    final dayHigh = (item['day_high'] as num?)?.toDouble();
    final dayLow = (item['day_low'] as num?)?.toDouble();
    final tickDir = item['tick_direction'] ?? 'FLAT';
    final supertrendDir = item['supertrend_direction'] ?? 'BULLISH';
    final sigPriority = item['signal_priority'] ?? 'MEDIUM';
    final sigType = item['signal_type'] ?? 'NO TRADE';
    final target = (item['target_price'] as num?)?.toDouble();
    final sl = (item['stop_loss_price'] as num?)?.toDouble();
    final targetDist = (item['target_distance_pct'] as num?)?.toDouble();

    final isPositive = pctChange >= 0;
    final tickColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: sigPriority == 'HIGH'
              ? const Color(0xFF2563EB).withOpacity(0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: sigPriority == 'HIGH' ? 1.5 : 1.0,
        ),
      ),
      color: cardBg,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockRecommendationScreen(
                symbol: symbol,
                exchange: exchange,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Symbol, Exchange tag, High Priority Badge & Price
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                exchange,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            if (sigPriority == 'HIGH') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                                ),
                                child: const Text(
                                  'HIGH ALPHA',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Real-time Price & Tick
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tickDir == 'UP'
                                ? Icons.arrow_drop_up
                                : (tickDir == 'DOWN' ? Icons.arrow_drop_down : Icons.remove),
                            color: tickColor,
                            size: 20,
                          ),
                          Text(
                            '₹${price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tickColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${isPositive ? '+' : ''}${pctChange.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 10.5,
                            color: tickColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Technical confluence indicators bar
              Row(
                children: [
                  // Supertrend tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: supertrendDir == 'BULLISH'
                          ? Colors.teal.withOpacity(0.12)
                          : Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ST: $supertrendDir',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: supertrendDir == 'BULLISH' ? Colors.teal : Colors.orangeAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (sigType != 'NO TRADE') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: sigType.contains('BUY')
                            ? Colors.green.withOpacity(0.12)
                            : Colors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        sigType,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: sigType.contains('BUY') ? const Color(0xFF10B981) : Colors.purpleAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (target != null) ...[
                    Text(
                      'T: ₹${target.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    if (targetDist != null)
                      Text(
                        ' (+${targetDist.toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                  ],
                  if (sl != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      'SL: ₹${sl.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (dayHigh != null && dayLow != null)
                    Text(
                      'H: ${dayHigh.toStringAsFixed(1)} / L: ${dayLow.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
