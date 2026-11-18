import 'package:flutter/material.dart';

/// Displays Indian Market-specific fundamentals, NSE/BSE trading session status,
/// and macro benchmarks for Indian equities.
class IndianStockMetricsCard extends StatelessWidget {
  final String symbol;
  final String exchange;
  final Map<String, dynamic>? fundamentals;
  final Map<String, dynamic>? macro;

  const IndianStockMetricsCard({
    super.key,
    required this.symbol,
    required this.exchange,
    this.fundamentals,
    this.macro,
  });

  /// Check Indian market session (09:15 - 15:30 IST, Mon-Fri)
  static Map<String, dynamic> getIndianMarketSessionStatus() {
    final nowUtc = DateTime.now().toUtc();
    // Indian Standard Time is UTC+5:30
    final ist = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final weekday = ist.weekday; // 1 = Monday, 7 = Sunday
    final isWeekend = weekday == DateTime.saturday || weekday == DateTime.sunday;
    final totalMinutes = ist.hour * 60 + ist.minute;

    // Normal Trading: 09:15 (555m) to 15:30 (930m)
    // Pre-Open: 09:00 (540m) to 09:15 (555m)
    // Post-Market: 15:40 (940m) to 16:00 (960m)
    if (isWeekend) {
      return {'status': 'CLOSED', 'label': 'Weekend (Closed)', 'color': Colors.grey};
    } else if (totalMinutes >= 555 && totalMinutes < 930) {
      return {'status': 'OPEN', 'label': 'NSE/BSE Open (Live)', 'color': const Color(0xFF10B981)};
    } else if (totalMinutes >= 540 && totalMinutes < 555) {
      return {'status': 'PRE_OPEN', 'label': 'Pre-Open Session', 'color': Colors.amberAccent};
    } else if (totalMinutes >= 930 && totalMinutes < 960) {
      return {'status': 'POST_CLOSE', 'label': 'Post-Market / Closing', 'color': Colors.cyanAccent};
    } else {
      return {'status': 'CLOSED', 'label': 'Market Closed (Reopens 09:15 IST)', 'color': Colors.grey};
    }
  }

  static String formatIndianMarketCap(num? mcap) {
    if (mcap == null || mcap <= 0) return 'N/A';
    final val = mcap.toDouble();
    // Format in ₹ Crores (1 Crore = 10,000,000)
    final crores = val / 1e7;
    if (crores >= 100000) {
      return '₹${(crores / 100000).toStringAsFixed(2)} Lakh Cr';
    } else if (crores >= 1) {
      return '₹${crores.toStringAsFixed(0)} Cr';
    }
    return '₹${val.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final session = getIndianMarketSessionStatus();
    final funds = fundamentals ?? {};
    final mcapRaw = funds['market_cap'] as num?;
    final mcapStr = formatIndianMarketCap(mcapRaw);
    final pe = (funds['pe_ratio'] as num?)?.toStringAsFixed(1) ?? 'N/A';
    final pb = (funds['price_to_book'] as num?)?.toStringAsFixed(1) ?? 'N/A';
    final roe = (funds['return_on_equity'] as num?) != null ? '${((funds['return_on_equity'] as num) * 100).toStringAsFixed(1)}%' : 'N/A';
    final netMargin = (funds['profit_margins'] as num?) != null ? '${((funds['profit_margins'] as num) * 100).toStringAsFixed(1)}%' : 'N/A';
    final eps = (funds['earnings_per_share'] as num?) != null ? '₹${(funds['earnings_per_share'] as num).toStringAsFixed(2)}' : 'N/A';
    final rbiStance = macro?['monetary_policy'] ?? 'Calibrated Tightening / Stable';
    final benchmark = macro?['benchmark_index'] ?? 'NIFTY 50 / SENSEX';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.show_chart, color: Colors.tealAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INDIAN MARKET & NSE/BSE METRICS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '$symbol • $exchange • 09:15 - 15:30 IST',
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

          // Indian Fundamentals Grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip('Market Cap (NSE)', mcapStr, Colors.tealAccent),
              _metricChip('P/E Ratio', pe != 'N/A' ? '${pe}x' : 'N/A', Colors.white),
              _metricChip('EPS (TTM)', eps, Colors.greenAccent),
              _metricChip('P/B Ratio', pb != 'N/A' ? '${pb}x' : 'N/A', Colors.white70),
              _metricChip('ROE', roe, Colors.amberAccent),
              _metricChip('Net Margin', netMargin, Colors.cyanAccent),
            ],
          ),
          const SizedBox(height: 12),

          // Macro & RBI Framework
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF131722),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance, color: Colors.tealAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reserve Bank of India (RBI) & Domestic Liquidity:',
                        style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$rbiStance • Benchmark: $benchmark',
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
