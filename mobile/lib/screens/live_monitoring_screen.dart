import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/zed_logo.dart';
import '../widgets/manual_purchase_dialog.dart';
import '../widgets/mini_sparkline.dart';
import 'stock_recommendation_screen.dart';

class LiveMonitoringScreen extends StatefulWidget {
  const LiveMonitoringScreen({super.key});

  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  String selectedFilter = 'ALL'; // 'ALL', 'TRENDING', 'GAINERS', 'LOSERS', 'WATCHLIST', 'RECENT', 'BULLISH', 'BEARISH'
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _localTickerTimer;
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _onlineSearchResults = [];
  bool _isSearchingOnline = false;

  @override
  void initState() {
    super.initState();
    // Refresh feed and overview when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.fetchMarketOverview(silent: true);
      state.fetchLiveFeed(exchange: state.activeExchangeDefault);
    });
    // Visual tick animation timer (subtle heartbeat)
    _localTickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _localTickerTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => searchQuery = query.trim());
    _searchDebounce?.cancel();
    if (searchQuery.length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
        if (!mounted) return;
        setState(() => _isSearchingOnline = true);
        try {
          final results = await context.read<AppState>().searchOnlineStocks(searchQuery);
          if (mounted) {
            setState(() {
              _onlineSearchResults = results;
              _isSearchingOnline = false;
            });
          }
        } catch (_) {
          if (mounted) setState(() => _isSearchingOnline = false);
        }
      });
    } else {
      setState(() {
        _onlineSearchResults = [];
        _isSearchingOnline = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter feed items based on selected category
    List<Map<String, dynamic>> items = [];

    if (selectedFilter == 'TRENDING') {
      items = state.trendingStocks.isNotEmpty
          ? List.from(state.trendingStocks)
          : _mapUniverseToItems(state.stocks);
    } else if (selectedFilter == 'GAINERS') {
      items = state.topGainers.isNotEmpty
          ? List.from(state.topGainers)
          : _mapUniverseToItems(state.stocks.where((s) => s.percentChange > 0).toList());
    } else if (selectedFilter == 'LOSERS') {
      items = state.topLosers.isNotEmpty
          ? List.from(state.topLosers)
          : _mapUniverseToItems(state.stocks.where((s) => s.percentChange < 0).toList());
    } else if (selectedFilter == 'WATCHLIST') {
      items = _mapUniverseToItems(state.stocks.where((s) => state.isWatchlisted(s.symbol)).toList());
    } else if (selectedFilter == 'RECENT') {
      final recentSet = state.recentAnalyzedStocks.toSet();
      items = _mapUniverseToItems(state.stocks.where((s) => recentSet.contains(s.symbol.toUpperCase())).toList());
      // If none found in local universe, build stub items from recent symbols
      if (items.isEmpty && state.recentAnalyzedStocks.isNotEmpty) {
        items = state.recentAnalyzedStocks.map((sym) => {
          'symbol': sym,
          'name': sym,
          'exchange': state.activeExchangeDefault,
          'price': 0.0,
          'percent_change': 0.0,
          'currency_symbol': state.activeCurrencySymbol,
          'tick_direction': 'FLAT',
          'signal_type': 'RECENTLY RESEARCHED',
        }).toList();
      }
    } else {
      // Default: ALL
      items = List.from(state.liveFeed);
      if (items.isEmpty && state.stocks.isNotEmpty) {
        items = _mapUniverseToItems(state.stocks);
      }
      if (items.isEmpty && state.trendingStocks.isNotEmpty) {
        items = List.from(state.trendingStocks);
      }
    }

    // Strictly enforce active market isolation (Never mix Indian and US stocks)
    items = items.where((it) {
      final ex = (it['exchange'] ?? '').toString().toUpperCase();
      if (state.isUSMarket) {
        return ex == 'US' || ex == 'NASDAQ' || ex == 'NYSE';
      } else {
        return ex == 'NSE' || ex == 'BSE' || ex.isEmpty;
      }
    }).toList();

    if (selectedFilter == 'BULLISH') {
      items = items.where((it) => (it['supertrend_direction'] == 'BULLISH' || ((it['percent_change'] ?? 0) as num) > 0)).toList();
    } else if (selectedFilter == 'BEARISH') {
      items = items.where((it) => (it['supertrend_direction'] == 'BEARISH' || ((it['percent_change'] ?? 0) as num) < 0)).toList();
    }

    // Local filter by search query if any
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      items = items.where((it) {
        final sym = (it['symbol'] ?? '').toString().toLowerCase();
        final name = (it['name'] ?? '').toString().toLowerCase();
        return sym.contains(q) || name.contains(q);
      }).toList();
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
            onPressed: () {
              state.fetchMarketOverview();
              state.fetchLiveFeed(exchange: state.activeExchangeDefault);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await state.fetchMarketOverview();
          await state.fetchLiveFeed(exchange: state.activeExchangeDefault);
          await state.refreshAll();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          children: [
            // ─────────────────────────────────────────────────────────────
            // 1. HOME PAGE – TWO LARGE ATTRACTIVE MARKET SELECTION OPTIONS
            // ─────────────────────────────────────────────────────────────
            _buildMarketSelectionHero(context, state, isDark),

            const SizedBox(height: 12),

            // ─────────────────────────────────────────────────────────────
            // 2. LIVE BENCHMARK & SECTOR INDICES RIBBON
            // ─────────────────────────────────────────────────────────────
            _buildIndexRibbon(context, state, isDark),

            const SizedBox(height: 10),

            // ─────────────────────────────────────────────────────────────
            // 3. MARKET PULSE & SESSION STATUS BANNER
            // ─────────────────────────────────────────────────────────────
            _buildMarketPulseBanner(context, state, isDark, isMarketOpen, serverTime, items.length),

            const SizedBox(height: 10),

            // ─────────────────────────────────────────────────────────────
            // 4. MARKET-ISOLATED SEARCH & CATEGORY SELECTORS
            // ─────────────────────────────────────────────────────────────
            _buildSearchAndFilters(context, state, isDark),

            const SizedBox(height: 12),

            // ─────────────────────────────────────────────────────────────
            // 5. ONLINE SEARCH RESULTS (IF ACTIVE QUERY)
            // ─────────────────────────────────────────────────────────────
            if (searchQuery.isNotEmpty && _onlineSearchResults.isNotEmpty) ...[
              _buildOnlineSearchResultsHeader(context, isDark),
              ..._onlineSearchResults.map((item) => _buildOnlineSearchResultTile(context, state, item, isDark)),
              const Divider(height: 24),
            ],

            // ─────────────────────────────────────────────────────────────
            // 6. MONITORED STOCK TICKER CARDS (ISOLATED TO ACTIVE MARKET)
            // ─────────────────────────────────────────────────────────────
            if (items.isEmpty && !_isSearchingOnline)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.sensors_off, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No ${state.isIndianMarket ? "Indian" : "US"} stocks match this filter',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Category Filters'),
                        onPressed: () {
                          setState(() {
                            selectedFilter = 'ALL';
                            searchQuery = '';
                            _searchController.clear();
                            _onlineSearchResults = [];
                          });
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map((item) => _buildLiveStockCard(context, state, item, isDark)),

            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_shopping_cart, size: 20),
        label: Text(
          state.isIndianMarket ? 'I Bought a Stock (INR)' : 'I Bought a Stock (USD)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
        ),
        onPressed: () {
          ManualPurchaseDialog.show(context, symbol: '', exchange: state.activeExchangeDefault);
        },
      ),
    );
  }

  /// Helper to convert StockSummary universe list into live monitoring item format
  List<Map<String, dynamic>> _mapUniverseToItems(List<dynamic> stocks) {
    return stocks.map((s) => {
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

  /// ──────────────────────────────────────────────────────────────────────────
  /// 1. TWO LARGE, ATTRACTIVE MARKET SELECTION OPTIONS (HERO CARDS)
  /// ──────────────────────────────────────────────────────────────────────────
  Widget _buildMarketSelectionHero(BuildContext context, AppState state, bool isDark) {
    final isIndia = state.isIndianMarket;
    final isUS = state.isUSMarket;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.public, size: 16, color: Color(0xFF2563EB)),
            const SizedBox(width: 6),
            Text(
              'SELECT ACTIVE MARKET TERMINAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // 🇮🇳 INDIAN STOCK MARKET OPTION
            Expanded(
              child: _buildMarketHeroCard(
                context: context,
                isSelected: isIndia,
                flag: '🇮🇳',
                title: 'Indian Market',
                subtitle: 'NSE • BSE • NIFTY 50',
                currencyText: '₹ INR Pricing',
                tag: 'IST 09:15 - 15:30',
                activeColor: const Color(0xFF0D9488), // Teal/Emerald
                isDark: isDark,
                onTap: () async {
                  if (!isIndia) {
                    await state.selectMarket('INDIA');
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            // 🇺🇸 US STOCK MARKET OPTION
            Expanded(
              child: _buildMarketHeroCard(
                context: context,
                isSelected: isUS,
                flag: '🇺🇸',
                title: 'US Market',
                subtitle: 'NYSE • NASDAQ • S&P',
                currencyText: '\$ USD Pricing',
                tag: 'EST 09:30 - 16:00',
                activeColor: const Color(0xFF2563EB), // Blue/Indigo
                isDark: isDark,
                onTap: () async {
                  if (!isUS) {
                    await state.selectMarket('US');
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMarketHeroCard({
    required BuildContext context,
    required bool isSelected,
    required String flag,
    required String title,
    required String subtitle,
    required String currencyText,
    required String tag,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final cardBg = isSelected
        ? (isDark ? activeColor.withOpacity(0.18) : activeColor.withOpacity(0.08))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    final borderColor = isSelected
        ? activeColor
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  flag,
                  style: const TextStyle(fontSize: 26),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_circle, size: 10, color: Colors.white),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        isSelected ? 'ACTIVE' : 'SELECT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currencyText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? activeColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ──────────────────────────────────────────────────────────────────────────
  /// 2. LIVE BENCHMARK & SECTOR INDICES RIBBON
  /// ──────────────────────────────────────────────────────────────────────────
  Widget _buildIndexRibbon(BuildContext context, AppState state, bool isDark) {
    // If backend indices are loaded, use them; otherwise use defaults for market
    List<Map<String, dynamic>> indices = state.marketIndices;
    if (indices.isEmpty) {
      if (state.isIndianMarket) {
        indices = [
          {'name': 'NIFTY 50', 'symbol': '^NSEI', 'price': 24148.20, 'change': 112.40, 'percent_change': 0.47},
          {'name': 'BANK NIFTY', 'symbol': '^NSEBANK', 'price': 51630.50, 'change': 240.10, 'percent_change': 0.47},
          {'name': 'NIFTY IT', 'symbol': '^CNXIT', 'price': 42890.15, 'change': -85.30, 'percent_change': -0.20},
          {'name': 'BSE SENSEX', 'symbol': '^BSESN', 'price': 79486.32, 'change': 320.15, 'percent_change': 0.40},
        ];
      } else {
        indices = [
          {'name': 'S&P 500', 'symbol': '^GSPC', 'price': 5929.04, 'change': 42.15, 'percent_change': 0.72},
          {'name': 'NASDAQ 100', 'symbol': '^NDX', 'price': 20780.50, 'change': 185.30, 'percent_change': 0.90},
          {'name': 'DOW JONES', 'symbol': '^DJI', 'price': 43729.93, 'change': 259.65, 'percent_change': 0.60},
          {'name': 'RUSSELL 2000', 'symbol': '^RUT', 'price': 2390.10, 'change': 32.40, 'percent_change': 1.37},
        ];
      }
    }

    final curSym = state.activeCurrencySymbol;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: indices.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final idxItem = indices[idx];
          final name = idxItem['name'] ?? '';
          final price = (idxItem['price'] as num?)?.toDouble() ?? 0.0;
          final pct = (idxItem['percent_change'] as num?)?.toDouble() ?? 0.0;
          final isPos = pct >= 0;
          final color = isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      price > 0 ? '$curSym${price.toStringAsFixed(1)}' : 'INDEX',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${isPos ? '+' : ''}${pct.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ──────────────────────────────────────────────────────────────────────────
  /// 3. MARKET PULSE & SESSION STATUS BANNER
  /// ──────────────────────────────────────────────────────────────────────────
  Widget _buildMarketPulseBanner(
    BuildContext context,
    AppState state,
    bool isDark,
    bool isMarketOpen,
    String serverTime,
    int activeCount,
  ) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final isIndia = state.isIndianMarket;
    final marketName = isIndia ? 'NSE / BSE INDIA' : 'NYSE / NASDAQ US';
    final marketHours = isIndia ? '09:15 - 15:30 IST' : '09:30 - 16:00 EST';

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
                      '$marketName • ${isMarketOpen ? "SESSION ACTIVE" : "MARKET CLOSED"}',
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
                  '$activeCount Stocks Monitored ($marketHours • ${state.activeCurrency})',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          // Server Time Tag
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

  /// ──────────────────────────────────────────────────────────────────────────
  /// 4. MARKET-ISOLATED SEARCH & CATEGORY FILTER TABS
  /// ──────────────────────────────────────────────────────────────────────────
  Widget _buildSearchAndFilters(BuildContext context, AppState state, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final hint = state.isIndianMarket
        ? 'Search Indian stock (e.g. RELIANCE, TCS, INFY, HDFCBANK)...'
        : 'Search US stock (e.g. AAPL, TSLA, NVDA, MSFT, AMZN)...';

    return Column(
      children: [
        // Search Input
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
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
                          _onlineSearchResults = [];
                        });
                      },
                    )
                  : (_isSearchingOnline
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: Center(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : null),
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
              _filterChip('ALL', '🔥 All Stocks', isDark),
              const SizedBox(width: 6),
              _filterChip('TRENDING', '📈 Trending', isDark),
              const SizedBox(width: 6),
              _filterChip('GAINERS', '🚀 Top Gainers', isDark),
              const SizedBox(width: 6),
              _filterChip('LOSERS', '🔻 Top Losers', isDark),
              const SizedBox(width: 6),
              _filterChip('WATCHLIST', '⭐ Watchlist', isDark),
              const SizedBox(width: 6),
              _filterChip('RECENT', '🕒 Recently Analyzed', isDark),
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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

  /// ──────────────────────────────────────────────────────────────────────────
  /// 5. ONLINE SEARCH RESULTS VIEW
  /// ──────────────────────────────────────────────────────────────────────────
  Widget _buildOnlineSearchResultsHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_sync, size: 14, color: Color(0xFF2563EB)),
          const SizedBox(width: 6),
          Text(
            'MATCHING MARKET INSTRUMENTS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineSearchResultTile(
    BuildContext context,
    AppState state,
    Map<String, dynamic> item,
    bool isDark,
  ) {
    final symbol = item['symbol'] ?? '';
    final name = item['name'] ?? symbol;
    final exchange = item['exchange'] ?? state.activeExchangeDefault;
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final sector = item['sector'] ?? '';
    final curSym = (exchange == 'US' || exchange == 'NASDAQ' || exchange == 'NYSE' || state.isUSMarket) ? '\$' : '₹';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF2563EB).withOpacity(0.4),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Row(
          children: [
            Text(
              symbol,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
          ],
        ),
        subtitle: Text(
          '$name • $sector',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (price > 0)
              Text(
                '$curSym${price.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
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
              child: const Text('Analyze', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// ──────────────────────────────────────────────────────────────────────────
  /// 6. MONITORED STOCK TCKER CARD (ISOLATED TO ACTIVE MARKET)
  /// ──────────────────────────────────────────────────────────────────────────
  Widget _buildLiveStockCard(
    BuildContext context,
    AppState state,
    Map<String, dynamic> item,
    bool isDark,
  ) {
    final symbol = item['symbol'] ?? '';
    final name = item['name'] ?? symbol;
    final exchange = item['exchange'] ?? state.activeExchangeDefault;
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

    // Determine correct currency symbol for this stock
    final curSym = (exchange == 'US' || exchange == 'NASDAQ' || exchange == 'NYSE' || state.isUSMarket) ? '\$' : '₹';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardBox(
        isDark,
        borderCol: sigPriority == 'HIGH'
            ? const Color(0xFF2563EB).withOpacity(0.6)
            : null,
        borderWidth: sigPriority == 'HIGH' ? 1.4 : 1.0,
        glow: sigPriority == 'HIGH',
        glowColor: const Color(0xFF2563EB),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
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

                  // Mini Sparkline Trend Visualization
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: MiniSparkline.fromTrend(
                      price: price,
                      changePct: pctChange,
                      high: dayHigh,
                      low: dayLow,
                      width: 54,
                      height: 22,
                    ),
                  ),

                  // Real-time Price & Tick with isolated currency symbol
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
                            '$curSym${price.toStringAsFixed(2)}',
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
                      'T: $curSym${target.toStringAsFixed(1)}',
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
                      'SL: $curSym${sl.toStringAsFixed(1)}',
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
    ),
  );
}
}
