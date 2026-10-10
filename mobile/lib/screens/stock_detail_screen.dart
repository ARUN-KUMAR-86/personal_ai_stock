import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../state/app_state.dart';
import '../models/signal.dart';
import '../widgets/signal_pill.dart';

class StockDetailScreen extends StatefulWidget {
  final String symbol;
  final String exchange;

  const StockDetailScreen({
    super.key,
    required this.symbol,
    required this.exchange,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  List<StockSignal> signals = [];
  List<Map<String, dynamic>> candles = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    final api = context.read<AppState>().api;
    try {
      final sigFuture = api.getSignalsForStock(widget.symbol);
      final candleFuture = api.getStockCandles(widget.symbol);

      final results = await Future.wait([sigFuture, candleFuture]);
      setState(() {
        signals = results[0] as List<StockSignal>;
        candles = results[1] as List<Map<String, dynamic>>;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _showPaperTradeDialog(double currentPrice, StockSignal? latestSignal) {
    int quantity = 10;
    String action = 'BUY';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paper Trade: ${widget.symbol}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('BUY')),
                          selected: action == 'BUY',
                          selectedColor: Colors.greenAccent.withOpacity(0.3),
                          labelStyle: TextStyle(
                            color: action == 'BUY' ? Colors.greenAccent : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => action = 'BUY');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('SELL')),
                          selected: action == 'SELL',
                          selectedColor: Colors.redAccent.withOpacity(0.3),
                          labelStyle: TextStyle(
                            color: action == 'SELL' ? Colors.redAccent : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val) setModalState(() => action = 'SELL');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quantity (Shares):', style: TextStyle(color: Colors.white70)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.blueAccent),
                            onPressed: () {
                              if (quantity > 1) setModalState(() => quantity -= 1);
                            },
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                            onPressed: () {
                              setModalState(() => quantity += 1);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated Value:', style: TextStyle(color: Colors.grey)),
                      Text(
                        '₹${(currentPrice * quantity).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: action == 'BUY' ? Colors.green : Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final success = await context.read<AppState>().executePaperTrade(
                              symbol: widget.symbol,
                              action: action,
                              quantity: quantity,
                              price: currentPrice,
                            );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? '$action $quantity shares of ${widget.symbol} executed.'
                                : 'Trade execution failed.'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      },
                      child: Text(
                        'Confirm $action Order',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestSignal = signals.isNotEmpty ? signals.first : null;
    final currentPrice = latestSignal?.price ?? (candles.isNotEmpty ? (candles.last['close'] as num).toDouble() : 0.0);

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: Text(
          '${widget.symbol} (${widget.exchange})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : RefreshIndicator(
              onRefresh: _fetchDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Price Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${currentPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            latestSignal?.timestamp != null
                                ? 'Updated: ${latestSignal!.timestamp.toLocal().toString().substring(0, 16)}'
                                : 'Historical Close',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                          ),
                        ],
                      ),
                      if (latestSignal != null)
                        SignalPill(
                          signalType: latestSignal.signalType,
                          strength: latestSignal.strength,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mini Candlestick / Price Trend Chart
                  if (candles.isNotEmpty)
                    Container(
                      height: 180,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: candles
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), (e.value['close'] as num).toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: Colors.blueAccent,
                              barWidth: 2,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blueAccent.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Action Levels: Entry, Stop-Loss, Target
                  if (latestSignal != null) ...[
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
                          const Text(
                            'STRATEGY EXECUTION LEVELS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLevelTile('Stop-Loss', '₹${latestSignal.stopLoss ?? 'N/A'}', Colors.redAccent),
                              _buildLevelTile('Entry Rule', latestSignal.entryCondition ?? 'Confirmation', Colors.blueAccent),
                              _buildLevelTile('Target', '₹${latestSignal.target ?? 'N/A'}', Colors.greenAccent),
                              _buildLevelTile('Risk/Reward', '${latestSignal.riskReward ?? 'N/A'}', Colors.amberAccent),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 24),
                          const Text(
                            'Explanation & Reasoning:',
                            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            latestSignal.explanation,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          ),
                          if (latestSignal.invalidationCondition != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Invalidation: ${latestSignal.invalidationCondition}',
                              style: TextStyle(color: Colors.orange.shade300, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Technical Indicators Summary Table
                    if (latestSignal.indicatorSummary != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CALCULATED INDICATORS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                _indicatorChip('RSI (14)', '${latestSignal.indicatorSummary!['rsi_14']}'),
                                _indicatorChip('RVOL (20d)', '${latestSignal.indicatorSummary!['rvol']}x'),
                                _indicatorChip('ATR (14)', '₹${latestSignal.indicatorSummary!['atr_14']}'),
                                _indicatorChip('EMA 21', '₹${latestSignal.indicatorSummary!['ema_21']}'),
                                _indicatorChip('SMA 50', '₹${latestSignal.indicatorSummary!['sma_50']}'),
                                _indicatorChip('Classic Pivot', '₹${latestSignal.indicatorSummary!['pivot']}'),
                                _indicatorChip('Support 1 (S1)', '₹${latestSignal.indicatorSummary!['s1']}'),
                                _indicatorChip('Resistance 1 (R1)', '₹${latestSignal.indicatorSummary!['r1']}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Paper Trade Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _showPaperTradeDialog(currentPrice, latestSignal),
                        icon: const Icon(Icons.flash_on),
                        label: const Text(
                          'Place Paper Trade',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildLevelTile(String title, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _indicatorChip(String name, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.grey, fontSize: 9)),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
