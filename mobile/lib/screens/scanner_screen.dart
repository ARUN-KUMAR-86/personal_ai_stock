import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/signal_pill.dart';
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
      final matchesSignal = (selectedSignal == 'ALL' || selectedSignal == '⭐ WATCHLIST') ||
          s.latestSignal == selectedSignal;
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

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: const Text('STOCK SCANNER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'Trigger Market Scan',
            icon: state.isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                  )
                : const Icon(Icons.radar, color: Colors.blueAccent),
            onPressed: state.isScanning ? null : () => state.triggerScan(),
          ),
          IconButton(
            tooltip: 'Refresh Universe',
            icon: const Icon(Icons.refresh),
            onPressed: () => state.refreshAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF1E222D),
            child: Column(
              children: [
                // Search Input
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search stock symbol or company name...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF131722),
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
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
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
                                        color: state.isWatchlisted(stock.symbol) ? Colors.amberAccent : Colors.grey.shade500,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    stock.symbol,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                stock.latestPrice != null
                                    ? '₹${stock.latestPrice!.toStringAsFixed(2)}'
                                    : '---',
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
                              Text(
                                stock.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
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
