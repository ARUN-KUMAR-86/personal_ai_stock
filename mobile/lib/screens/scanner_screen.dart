import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/signal_pill.dart';
import '../widgets/priority_badge.dart';
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
  String sortBy = 'STRENGTH'; // 'STRENGTH', 'PRICE', 'SYMBOL'

  final List<String> signalFilters = [
    'ALL',
    '🔴 HIGH PRIORITY',
    '🟢 MEDIUM PRIORITY',
    '⭐ WATCHLIST',
    'BUY WATCH',
    'HOLD',
    'SELL/EXIT WATCH',
    'NO TRADE',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    List<StockSummary> baseList = state.stocks;
    if (selectedSignal == '⭐ WATCHLIST') {
      final stockMap = {for (var s in state.stocks) s.symbol.toUpperCase(): s};
      baseList = state.watchlistSymbols.map((sym) {
        if (stockMap.containsKey(sym)) return stockMap[sym]!;
        final wItem = state.watchlistItems.where((w) => w.symbol.toUpperCase() == sym).firstOrNull;
        if (wItem != null && wItem.stock != null) return wItem.stock!;
        return StockSummary(
          symbol: sym,
          exchange: 'NSE',
          name: sym,
          isLive: false,
          latestSignal: 'NO TRADE',
          signalStrength: 0.0,
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
      } else if (selectedSignal == '🔴 HIGH PRIORITY') {
        matchesSignal = s.isHighPriority;
      } else if (selectedSignal == '🟢 MEDIUM PRIORITY') {
        matchesSignal = s.isMediumPriority;
      } else {
        matchesSignal = s.latestSignal == selectedSignal;
      }
      return matchesSearch && matchesSignal;
    }).toList();

    // Sort stocks
    if (sortBy == 'STRENGTH') {
      filtered.sort((a, b) => b.signalStrength.compareTo(a.signalStrength));
    } else if (sortBy == 'PRICE') {
      filtered.sort((a, b) => (b.latestPrice ?? 0).compareTo(a.latestPrice ?? 0));
    } else {
      filtered.sort((a, b) => a.symbol.compareTo(b.symbol));
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'STOCK SCANNER',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            letterSpacing: 0.5,
            color: theme.colorScheme.onSurface,
          ),
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
            tooltip: 'Refresh Universe',
            icon: Icon(Icons.refresh, color: theme.primaryColor),
            onPressed: () => state.refreshAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : Colors.white,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search stock symbol or company name...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => searchQuery = val),
                ),
                const SizedBox(height: 10),

                // Signal Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: signalFilters.map((sig) {
                      final isSelected = selectedSignal == sig;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(
                            sig,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade400,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.blueAccent,
                          backgroundColor: const Color(0xFF131722),
                          onSelected: (_) => setState(() => selectedSignal = sig),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Count & Sort Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filtered.length} STOCKS FOUND',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Text('Sort by: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    DropdownButton<String>(
                      value: sortBy,
                      dropdownColor: const Color(0xFF1E222D),
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: 'STRENGTH', child: Text('Confidence')),
                        DropdownMenuItem(value: 'PRICE', child: Text('Price')),
                        DropdownMenuItem(value: 'SYMBOL', child: Text('Symbol')),
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

          // Stock List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching stocks found for active filter.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemBuilder: (context, idx) {
                      final stock = filtered[idx];
                      final isHigh = stock.isHighPriority;
                      final isMed = stock.isMediumPriority;
                      final isUs = ['US', 'NASDAQ', 'NYSE', 'GLOBAL'].contains(stock.exchange.toUpperCase());
                      final curr = isUs ? '\$' : '₹';

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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                        color: state.isWatchlisted(stock.symbol) ? Colors.amber : (isDark ? Colors.grey.shade500 : const Color(0xFF94A3B8)),
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
                                  if (stock.priority.isNotEmpty && stock.priority.toUpperCase() != 'NORMAL') ...[
                                    const SizedBox(width: 8),
                                    PriorityBadge(priority: stock.priority, fontSize: 9.0),
                                  ],
                                ],
                              ),
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
                                        ? '${stock.latestTimestamp!.hour}:${stock.latestTimestamp!.minute.toString().padLeft(2, '0')} IST'
                                        : 'Awaiting Scan',
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
                                ),
                              ),
                            );
                          },
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
