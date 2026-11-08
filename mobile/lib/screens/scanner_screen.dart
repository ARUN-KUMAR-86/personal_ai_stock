import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/signal_pill.dart';
import '../widgets/priority_badge.dart';
import '../widgets/zed_logo.dart';
import '../models/stock_summary.dart';
import 'stock_recommendation_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String searchQuery = '';
  String selectedSignal = 'ALL';
  String sortBy = 'PRIORITY'; // 'PRIORITY', 'STRENGTH', 'PRICE', 'SYMBOL'
  String selectedHorizon = '1-DAY'; // '1-DAY' or '1-MONTH'

  List<Map<String, dynamic>> onlineSearchResults = [];
  bool isSearchingOnline = false;
  Timer? _searchDebounce;

  final List<String> signalFilters = [
    'ALL',
    '🔴 HIGH PRIORITY',
    '🟢 MEDIUM PRIORITY',
    '⚪ LOW PRIORITY',
    '🤖 AI PREDICTED',
    '⭐ WATCHLIST',
    'BUY WATCH',
    'HOLD',
    'SELL/EXIT WATCH',
    'NO TRADE',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<AppState>(context, listen: false);
      setState(() {
        selectedHorizon = state.selectedScannerHorizon;
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val, AppState state) {
    setState(() => searchQuery = val);
    _searchDebounce?.cancel();
    if (val.trim().length >= 2) {
      _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
        setState(() => isSearchingOnline = true);
        final results = await state.searchOnlineStocks(val.trim());
        if (mounted) {
          setState(() {
            onlineSearchResults = results;
            isSearchingOnline = false;
          });
        }
      });
    } else {
      setState(() => onlineSearchResults = []);
    }
  }

  Future<void> _changeHorizon(String horizon, AppState state) async {
    if (selectedHorizon == horizon) return;
    setState(() => selectedHorizon = horizon);
    await state.fetchUniverseForHorizon(horizon);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUS = state.isUSMarket;
    final curr = isUS ? '\$' : '₹';
    final isMonth = selectedHorizon.contains('MONTH');

    List<StockSummary> baseList = state.stocks;
    if (selectedSignal == '⭐ WATCHLIST') {
      final stockMap = {for (var s in state.stocks) s.symbol.toUpperCase(): s};
      baseList = state.watchlistSymbols.map((sym) {
        if (stockMap.containsKey(sym)) return stockMap[sym]!;
        final wItem = state.watchlistItems.where((w) => w.symbol.toUpperCase() == sym).firstOrNull;
        if (wItem != null && wItem.stock != null) return wItem.stock!;
        return StockSummary(
          symbol: sym,
          exchange: isUS ? 'US' : 'NSE',
          name: sym,
          isLive: false,
          latestSignal: 'NO TRADE',
          signalStrength: 0.0,
          timeHorizon: selectedHorizon,
        );
      }).toList();
    }

    // Filter stocks
    var filtered = baseList.where((s) {
      final matchesSearch = s.symbol.toLowerCase().contains(searchQuery.toLowerCase()) ||
          s.name.toLowerCase().contains(searchQuery.toLowerCase());
      bool matchesSignal = true;
      if (selectedSignal == 'ALL' || selectedSignal == '⭐ WATCHLIST') {
        matchesSignal = true;
      } else if (selectedSignal == '🤖 AI PREDICTED') {
        matchesSignal = s.hasPrediction || (s.predictedConfidence != null && s.predictedConfidence! > 0);
      } else if (selectedSignal == '🔴 HIGH PRIORITY') {
        matchesSignal = s.isHighPriority;
      } else if (selectedSignal == '🟢 MEDIUM PRIORITY') {
        matchesSignal = s.isMediumPriority;
      } else if (selectedSignal == '⚪ LOW PRIORITY') {
        matchesSignal = s.isLowPriority;
      } else {
        matchesSignal = s.latestSignal == selectedSignal;
      }
      return matchesSearch && matchesSignal;
    }).toList();

    // Sort stocks: Default is PRIORITY (High -> Medium -> Low), then AI Confidence descending
    if (sortBy == 'PRIORITY') {
      filtered.sort((a, b) {
        final rankCmp = a.priorityRank.compareTo(b.priorityRank);
        if (rankCmp != 0) return rankCmp;
        return (b.predictedConfidence ?? b.signalStrength)
            .compareTo(a.predictedConfidence ?? a.signalStrength);
      });
    } else if (sortBy == 'STRENGTH') {
      filtered.sort((a, b) => (b.predictedConfidence ?? b.signalStrength)
          .compareTo(a.predictedConfidence ?? a.signalStrength));
    } else if (sortBy == 'PRICE') {
      filtered.sort((a, b) => (b.latestPrice ?? 0).compareTo(a.latestPrice ?? 0));
    } else {
      filtered.sort((a, b) => a.symbol.compareTo(b.symbol));
    }

    final highCount = filtered.where((s) => s.isHighPriority).length;
    final medCount = filtered.where((s) => s.isMediumPriority).length;
    final lowCount = filtered.where((s) => s.isLowPriority).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            const ZedLogo(size: 24),
            const SizedBox(width: 8),
            Text(
              'ZED AI SCANNER',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Trigger Market Scan',
            icon: state.isScanning
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                  )
                : Icon(Icons.radar, color: theme.primaryColor),
            onPressed: state.isScanning ? null : () => state.triggerScan(),
          ),
          IconButton(
            tooltip: 'Refresh Universe & Quotes',
            icon: Icon(Icons.refresh, color: theme.primaryColor),
            onPressed: () => state.refreshAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 1. MARKET TERMINAL SELECTOR (🇮🇳 Indian vs 🇺🇸 US) ──────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.4))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MARKET TERMINAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUS ? 'US DESK ACTIVE' : 'INDIA DESK ACTIVE',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // 🇮🇳 INDIAN MARKET OPTION
                    Expanded(
                      child: _buildMarketChip(
                        context: context,
                        isSelected: !isUS,
                        flag: '🇮🇳',
                        title: 'Indian Market',
                        subtitle: 'NSE • BSE • ₹ INR',
                        activeColor: const Color(0xFF0D9488), // Emerald / Teal
                        isDark: isDark,
                        onTap: () async {
                          if (isUS) {
                            await state.selectMarket('INDIA');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 🇺🇸 US MARKET OPTION
                    Expanded(
                      child: _buildMarketChip(
                        context: context,
                        isSelected: isUS,
                        flag: '🇺🇸',
                        title: 'US Market',
                        subtitle: 'NYSE • NASDAQ • \$ USD',
                        activeColor: const Color(0xFF2563EB), // Deep Blue
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
                const SizedBox(height: 10),

                // ── 2. TIME HORIZON SELECTOR (1-DAY vs 1-MONTH) ────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildHorizonTab(
                          label: '⚡ 1-DAY (Short Term / Swing)',
                          sublabel: '24-48 Hours Target',
                          isSelected: !isMonth,
                          isDark: isDark,
                          onTap: () => _changeHorizon('1-DAY', state),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildHorizonTab(
                          label: '📅 1-MONTH (Long Term)',
                          sublabel: '30 Days Positional',
                          isSelected: isMonth,
                          isDark: isDark,
                          onTap: () => _changeHorizon('1-MONTH', state),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 3. SEARCH & SIGNAL FILTERS ────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: isUS
                        ? 'Search US stocks (e.g. TSLA, NVDA, AMD, AAPL)...'
                        : 'Search Indian stocks (e.g. TCS, RELIANCE, JIOFIN)...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                    prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.grey : const Color(0xFF64748B)),
                    suffixIcon: isSearchingOnline
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : (searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() {
                                  searchQuery = '';
                                  onlineSearchResults = [];
                                }),
                              )
                            : null),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => _onSearchChanged(val, state),
                ),
                const SizedBox(height: 8),

                // Signal & Priority Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: signalFilters.map((sig) {
                      final isSelected = selectedSignal == sig;
                      final isAi = sig.contains('AI');
                      final isHigh = sig.contains('HIGH');
                      final isMed = sig.contains('MEDIUM');
                      final isLow = sig.contains('LOW');

                      Color chipActiveColor = Colors.blueAccent;
                      if (isHigh) chipActiveColor = Colors.redAccent.shade700;
                      if (isMed) chipActiveColor = Colors.green.shade700;
                      if (isLow) chipActiveColor = Colors.blueGrey.shade700;
                      if (isAi) chipActiveColor = Colors.purpleAccent.shade700;

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            sig,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isHigh
                                      ? Colors.redAccent
                                      : (isMed
                                          ? Colors.greenAccent
                                          : (isAi
                                              ? Colors.purpleAccent
                                              : (isDark ? Colors.grey.shade400 : const Color(0xFF475569))))),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: chipActiveColor,
                          backgroundColor: isDark ? const Color(0xFF131722) : const Color(0xFFF1F5F9),
                          onSelected: (_) => setState(() => selectedSignal = sig),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // ── Online Discovery / New IPO Results (if any) ────────────────────
          if (onlineSearchResults.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.shade900.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.travel_explore, color: Colors.purpleAccent, size: 15),
                          SizedBox(width: 6),
                          Text(
                            'ONLINE MARKET DISCOVERY',
                            style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text('${onlineSearchResults.length} found', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...onlineSearchResults.take(3).map((item) {
                    final sym = item['symbol'] as String;
                    final name = item['name'] as String? ?? sym;
                    final price = (item['price'] as num?)?.toDouble();
                    final inUniv = item['is_in_universe'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(sym, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(3)),
                                      child: Text(item['exchange'] ?? (isUS ? 'US' : 'NSE'), style: const TextStyle(color: Colors.grey, fontSize: 9)),
                                    ),
                                  ],
                                ),
                                Text(name, style: TextStyle(color: Colors.grey.shade400, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (price != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                '$curr${price.toStringAsFixed(2)}',
                                style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: inUniv ? Colors.teal.shade900 : Colors.purpleAccent.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              if (!inUniv) {
                                await state.addStockToUniverse(sym, exchange: item['exchange'] ?? (isUS ? 'US' : 'NSE'), name: name);
                                if (mounted) {
                                  setState(() {
                                    item['is_in_universe'] = true;
                                  });
                                }
                              }
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => StockRecommendationScreen(
                                    symbol: sym,
                                    exchange: item['exchange'] ?? (isUS ? 'US' : 'NSE'),
                                    initialHorizon: selectedHorizon,
                                  ),
                                ),
                              );
                            },
                            child: Text(inUniv ? 'View' : '+ Add', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // ── 4. PRIORITY OVERVIEW & SORT BAR ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quick priority count badges
                Row(
                  children: [
                    _buildMiniBadge('HIGH', highCount, Colors.redAccent),
                    const SizedBox(width: 6),
                    _buildMiniBadge('MED', medCount, Colors.greenAccent),
                    const SizedBox(width: 6),
                    _buildMiniBadge('LOW', lowCount, Colors.blueGrey),
                    const SizedBox(width: 8),
                    Text(
                      '• ${filtered.length} total',
                      style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
                // Sort Dropdown
                Row(
                  children: [
                    Text('Sort: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    DropdownButton<String>(
                      value: sortBy,
                      dropdownColor: isDark ? const Color(0xFF1E222D) : Colors.white,
                      underline: const SizedBox(),
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'PRIORITY', child: Text('Priority (High→Low)')),
                        DropdownMenuItem(value: 'STRENGTH', child: Text('AI Confidence')),
                        DropdownMenuItem(value: 'PRICE', child: Text('Price')),
                        DropdownMenuItem(value: 'SYMBOL', child: Text('Symbol A-Z')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => sortBy = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── 5. STOCKS LIST WITH STRICT PRIORITY HIERARCHY ─────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 36, color: Colors.grey.shade600),
                        const SizedBox(height: 8),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'No stocks found for "$searchQuery" in ${isUS ? "US Market" : "Indian Market"}.'
                              : 'No matching stocks found for active filter.',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        ),
                        if (searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent.shade700),
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final sym = searchQuery.trim().toUpperCase();
                              await state.addStockToUniverse(sym, exchange: isUS ? 'US' : 'NSE');
                              navigator.push(
                                MaterialPageRoute(
                                  builder: (_) => StockRecommendationScreen(
                                    symbol: sym,
                                    exchange: isUS ? 'US' : 'NSE',
                                    initialHorizon: selectedHorizon,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add, size: 14),
                            label: Text('Discover & Add "$searchQuery"'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _calculateTotalItems(filtered, sortBy),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    itemBuilder: (context, idx) {
                      return _buildItemOrHeader(
                        filtered: filtered,
                        index: idx,
                        sortBy: sortBy,
                        state: state,
                        isDark: isDark,
                        theme: theme,
                        curr: curr,
                        isMonth: isMonth,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Helper UI Widgets ───────────────────────────────────────────────────────

  Widget _buildMarketChip({
    required BuildContext context,
    required bool isSelected,
    required String flag,
    required String title,
    required String subtitle,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final bg = isSelected
        ? (isDark ? activeColor.withOpacity(0.22) : activeColor.withOpacity(0.12))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final borderColor = isSelected
        ? activeColor
        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1.0),
          boxShadow: isSelected
              ? [BoxShadow(color: activeColor.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? (isDark ? Colors.white : activeColor)
                                : (isDark ? Colors.grey.shade300 : const Color(0xFF1E293B)),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle, size: 12, color: activeColor),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? (isDark ? Colors.grey.shade300 : const Color(0xFF475569))
                          : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizonTab({
    required String label,
    required String sublabel,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF0F172A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [const BoxShadow(color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? (isDark ? Colors.amberAccent : const Color(0xFFD97706))
                    : (isDark ? Colors.grey.shade400 : const Color(0xFF64748B)),
              ),
            ),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.grey.shade300 : const Color(0xFF475569))
                    : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Section Grouping & Item Rendering ─────────────────────────────────────

  int _calculateTotalItems(List<StockSummary> filtered, String currentSort) {
    if (currentSort != 'PRIORITY') {
      return filtered.length;
    }
    // Count sections with at least one stock
    int headers = 0;
    if (filtered.any((s) => s.isHighPriority)) headers++;
    if (filtered.any((s) => s.isMediumPriority)) headers++;
    if (filtered.any((s) => s.isLowPriority)) headers++;
    return filtered.length + headers;
  }

  Widget _buildItemOrHeader({
    required List<StockSummary> filtered,
    required int index,
    required String sortBy,
    required AppState state,
    required bool isDark,
    required ThemeData theme,
    required String curr,
    required bool isMonth,
  }) {
    if (sortBy != 'PRIORITY') {
      return _buildStockCard(filtered[index], state, isDark, theme, curr, isMonth);
    }

    // Categorize
    final highs = filtered.where((s) => s.isHighPriority).toList();
    final meds = filtered.where((s) => s.isMediumPriority).toList();
    final lows = filtered.where((s) => s.isLowPriority).toList();

    int curIdx = 0;

    // High Priority Section
    if (highs.isNotEmpty) {
      if (index == curIdx) {
        return _buildSectionBanner(
          title: '🔴 HIGH PRIORITY AI PICKS',
          subtitle: 'Immediate Breakout • High AI Confluence (≥75%)',
          count: highs.length,
          color: Colors.redAccent,
          isDark: isDark,
        );
      }
      curIdx++;
      if (index < curIdx + highs.length) {
        return _buildStockCard(highs[index - curIdx], state, isDark, theme, curr, isMonth);
      }
      curIdx += highs.length;
    }

    // Medium Priority Section
    if (meds.isNotEmpty) {
      if (index == curIdx) {
        return _buildSectionBanner(
          title: '🟢 MEDIUM PRIORITY SETUPS',
          subtitle: 'Emerging Swing Trend • Moderate Confluence (50-74%)',
          count: meds.length,
          color: Colors.greenAccent,
          isDark: isDark,
        );
      }
      curIdx++;
      if (index < curIdx + meds.length) {
        return _buildStockCard(meds[index - curIdx], state, isDark, theme, curr, isMonth);
      }
      curIdx += meds.length;
    }

    // Low Priority Section
    if (lows.isNotEmpty) {
      if (index == curIdx) {
        return _buildSectionBanner(
          title: '⚪ LOW PRIORITY / MONITORING',
          subtitle: 'Consolidation / Range-Bound / Awaiting Trigger',
          count: lows.length,
          color: Colors.blueGrey,
          isDark: isDark,
        );
      }
      curIdx++;
      if (index < curIdx + lows.length) {
        return _buildStockCard(lows[index - curIdx], state, isDark, theme, curr, isMonth);
      }
    }

    return const SizedBox();
  }

  Widget _buildSectionBanner({
    required String title,
    required String subtitle,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.12) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35), width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          Flexible(
            child: Text(
              subtitle,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                fontSize: 9.5,
                fontStyle: FontStyle.italic,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(
    StockSummary stock,
    AppState state,
    bool isDark,
    ThemeData theme,
    String curr,
    bool isMonth,
  ) {
    final isHigh = stock.isHighPriority;
    final isMed = stock.isMediumPriority;

    final bgColor = isDark
        ? (isHigh ? const Color(0xFF241317) : (isMed ? const Color(0xFF122318) : const Color(0xFF111827)))
        : (isHigh ? const Color(0xFFFEF2F2) : (isMed ? const Color(0xFFF0FDF4) : Colors.white));

    final borderColor = isHigh
        ? (isDark ? Colors.redAccent.withOpacity(0.85) : const Color(0xFFFCA5A5))
        : (isMed ? (isDark ? Colors.greenAccent.withOpacity(0.75) : const Color(0xFF86EFAC)) : theme.dividerColor);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: (isHigh || isMed) ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : const Color(0x080F172A),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => state.toggleWatchlist(stock.symbol, exchange: stock.exchange),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      state.isWatchlisted(stock.symbol) ? Icons.star : Icons.star_border,
                      color: state.isWatchlisted(stock.symbol)
                          ? Colors.amber
                          : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                      size: 18,
                    ),
                  ),
                ),
                Text(
                  stock.symbol,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    stock.exchange,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (stock.priority.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  PriorityBadge(priority: stock.explicitPriority ?? stock.priority, fontSize: 9.0),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stock.latestPrice != null
                      ? '$curr${stock.latestPrice!.toStringAsFixed(2)}'
                      : '---',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (stock.latestPrice != null && (stock.change != 0 || stock.percentChange != 0))
                  Text(
                    '${stock.percentChange >= 0 ? "+" : ""}${stock.percentChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: stock.percentChange >= 0 ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stock.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
            // AI Prediction Pill with Horizon
            if (stock.hasPrediction || (stock.predictedConfidence != null && stock.predictedConfidence! > 0)) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (stock.isBullish ? Colors.green : Colors.red).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: (stock.isBullish ? Colors.greenAccent : Colors.redAccent).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      '🤖 ${stock.predictedDirection ?? (stock.isBullish ? "BULLISH" : "BEARISH")} target $curr${stock.predictedTarget?.toStringAsFixed(2) ?? "--"} (${stock.predictedConfidence?.toStringAsFixed(0) ?? "75"}% conf • ${isMonth ? "📅 1-MO" : "⚡ 1-DAY"})',
                      style: TextStyle(
                        color: stock.isBullish ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SignalPill(
                  signalType: stock.latestSignal,
                  strength: stock.signalStrength,
                ),
                Text(
                  stock.latestTimestamp != null
                      ? '${stock.latestTimestamp!.hour}:${stock.latestTimestamp!.minute.toString().padLeft(2, '0')} ${state.isUSMarket ? "EST" : "IST"}'
                      : 'Live Tick',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockRecommendationScreen(
                symbol: stock.symbol,
                exchange: stock.exchange,
                initialHorizon: selectedHorizon,
              ),
            ),
          );
        },
      ),
    );
  }
}
