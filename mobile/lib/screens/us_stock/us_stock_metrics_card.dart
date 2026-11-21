import 'package:flutter/material.dart';

/// Displays US Market-specific fundamentals, Wall Street trading hours,
/// and institutional benchmarks for NASDAQ / NYSE equities.
class UsStockMetricsCard extends StatelessWidget {
  final String symbol;
  final String exchange;
  final Map<String, dynamic>? fundamentals;
  final Map<String, dynamic>? macro;

  const UsStockMetricsCard({
    super.key,
    required this.symbol,
    required this.exchange,
    this.fundamentals,
    this.macro,
  });

  /// Check Wall Street market session (09:30 - 16:00 EST / EDT, Mon-Fri)
  static Map<String, dynamic> getUsMarketSessionStatus() {
    final nowUtc = DateTime.now().toUtc();
    // US Eastern Time is typically UTC-5 (EST) or UTC-4 (EDT)
    // Approximate with UTC-5 (or UTC-4 in daylight savings)
    final est = nowUtc.subtract(const Duration(hours: 5));
    final weekday = est.weekday; // 1 = Monday, 7 = Sunday
    final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;
    final totalMinutes = est.hour * 60 + est.minute;

    // Regular Hours: 9:30 AM (570m) to 4:00 PM (960m)
    // Pre-Market: 4:00 AM (240m) to 9:30 AM (570m)
    // After-Hours: 4:00 PM (960m) to 8:00 PM (1200m)
    if (isWeekend) {
      return {'status': 'CLOSED', 'label': 'Weekend (Closed)', 'color': Colors.grey};
    } else if (totalMinutes >= 570 && totalMinutes < 960) {
      return {'status': 'OPEN', 'label': 'Regular Session (Live)', 'color': const Color(0xFF10B981)};
    } else if (totalMinutes >= 240 && totalMinutes < 570) {
      return {'status': 'PRE_MARKET', 'label': 'Pre-Market Session', 'color': Colors.amberAccent};
    } else if (totalMinutes >= 960 && totalMinutes < 1200) {
      return {'status': 'AFTER_HOURS', 'label': 'After-Hours Session', 'color': Colors.cyanAccent};
    } else {
      return {'status': 'CLOSED', 'label': 'Market Closed (Reopens 09:30 EST)', 'color': Colors.grey};
    }
  }

  static String formatUsMarketCap(num? mcap) {
    if (mcap == null || mcap <= 0) return 'N/A';
    final val = mcap.toDouble();
    if (val >= 1e12) {
      return '\$${(val / 1e12).toStringAsFixed(2)}T';
    } else if (val >= 1e9) {
      return '\$${(val / 1e9).toStringAsFixed(2)}B';
    } else if (val >= 1e6) {
      return '\$${(val / 1e6).toStringAsFixed(2)}M';
    }
    return '\$${val.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final session = getUsMarketSessionStatus();
    final funds = fundamentals ?? {};
    final mcapRaw = funds['market_cap'] as num?;
    final mcapStr = formatUsMarketCap(mcapRaw);
    final pe = (funds['pe_ratio'] as num?)?.toStringAsFixed(1) ?? 'N/A';
    final eps = (funds['earnings_per_share'] as num?) != null ? '\$${(funds['earnings_per_share'] as num).toStringAsFixed(2)}' : 'N/A';
    final pb = (funds['price_to_book'] as num?)?.toStringAsFixed(1) ?? 'N/A';
    final roe = (funds['return_on_equity'] as num?) != null ? '${((funds['return_on_equity'] as num) * 100).toStringAsFixed(1)}%' : 'N/A';
    final netMargin = (funds['profit_margins'] as num?) != null ? '${((funds['profit_margins'] as num) * 100).toStringAsFixed(1)}%' : 'N/A';
    final fedStance = macro?['monetary_policy'] ?? 'Neutral / Data Dependent';
    final benchmark = macro?['benchmark_index'] ?? 'S&P 500 / NASDAQ Composite';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Wall St Session status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.public, color: Colors.blueAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'US MARKET & WALL STREET METRICS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '$symbol • $exchange • 09:30 - 16:00 EST',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (session['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: (session['color'] as Color).withOpacity(0.4)),
                ),
                child: Text(
                  session['label'] as String,
                  style: TextStyle(
                    color: session['color'] as Color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // US Fundamentals Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip('Market Cap (USD)', mcapStr, Colors.cyanAccent),
              _metricChip('P/E Ratio', pe != 'N/A' ? '${pe}x' : 'N/A', Colors.white),
              _metricChip('EPS (TTM)', eps, Colors.greenAccent),
              _metricChip('P/B Ratio', pb != 'N/A' ? '${pb}x' : 'N/A', Colors.white70),
              _metricChip('ROE', roe, Colors.amberAccent),
              _metricChip('Net Margin', netMargin, Colors.tealAccent),
            ],
          ),
          const SizedBox(height: 12),

          // Macro & Fed Stance Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF131722),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.purpleAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'US Federal Reserve & Macro Environment:',
                        style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$fedStance • Benchmark: $benchmark',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value, Color valColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9.5)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: valColor, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
