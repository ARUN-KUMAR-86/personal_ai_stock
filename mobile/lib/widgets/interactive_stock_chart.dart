import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// Professional TradingView-style interactive price chart with touch cursor,
/// dynamic trend gradients, timeframe toggles, and high/low reference markers.
class InteractiveStockChart extends StatefulWidget {
  final List<dynamic> candles;
  final String currencySymbol;
  final double? targetPrice;
  final double? stopLossPrice;
  final double? currentPrice;
  final ValueChanged<String>? onTimeframeChanged;
  final String activeTimeframe;
  final bool isDark;

  const InteractiveStockChart({
    super.key,
    required this.candles,
    this.currencySymbol = '₹',
    this.targetPrice,
    this.stopLossPrice,
    this.currentPrice,
    this.onTimeframeChanged,
    this.activeTimeframe = '1D',
    this.isDark = true,
  });

  @override
  State<InteractiveStockChart> createState() => _InteractiveStockChartState();
}

class _InteractiveStockChartState extends State<InteractiveStockChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: AppTheme.cardBox(widget.isDark),
        child: Text(
          'No candle data available',
          style: TextStyle(color: AppTheme.textMuted(widget.isDark), fontSize: 13),
        ),
      );
    }

    // Extract spots
    final List<FlSpot> spots = [];
    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;

    for (int i = 0; i < widget.candles.length; i++) {
      final c = widget.candles[i];
      final close = ((c is Map ? (c['close'] ?? c['price']) : null) as num?)?.toDouble() ?? 0.0;
      if (close <= 0) continue;

      if (close < minPrice) {
        minPrice = close;
      }
      if (close > maxPrice) {
        maxPrice = close;
      }
      spots.add(FlSpot(i.toDouble(), close));
    }

    if (spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final firstPrice = spots.first.y;
    final lastPrice = spots.last.y;
    final isBullish = lastPrice >= firstPrice;
    final trendColor = isBullish
        ? AppTheme.profit(widget.isDark)
        : AppTheme.loss(widget.isDark);

    // Padding on Y axis for clean display
    final priceDiff = (maxPrice - minPrice).abs();
    final yMargin = priceDiff > 0 ? priceDiff * 0.12 : maxPrice * 0.02;
    final minY = (minPrice - yMargin).clamp(0.0, double.infinity);
    final maxY = maxPrice + yMargin;

    // Hovered spot calculation
    final activeSpot = _touchedIndex != null && _touchedIndex! < spots.length
        ? spots[_touchedIndex!]
        : spots.last;
    final activeCandle = _touchedIndex != null && _touchedIndex! < widget.candles.length
        ? widget.candles[_touchedIndex!]
        : widget.candles.last;

    String timestampStr = '';
    if (activeCandle is Map && activeCandle['timestamp'] != null) {
      try {
        final dt = DateTime.parse(activeCandle['timestamp'].toString());
        timestampStr = DateFormat('dd MMM, HH:mm').format(dt);
      } catch (_) {
        timestampStr = activeCandle['timestamp'].toString();
      }
    }

    final diffFromFirst = activeSpot.y - firstPrice;
    final pctDiffFromFirst = firstPrice > 0 ? (diffFromFirst / firstPrice) * 100 : 0.0;

    return Container(
      decoration: AppTheme.cardBox(
        widget.isDark,
        borderCol: trendColor.withOpacity(0.2),
        glow: true,
        glowColor: trendColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Active Touch Point / Live Price ─────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${widget.currencySymbol}${activeSpot.y.toStringAsFixed(2)}',
                        style: AppTheme.mono(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary(widget.isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: AppTheme.terminalBadge(
                          color: diffFromFirst >= 0 ? AppTheme.profit(widget.isDark) : AppTheme.loss(widget.isDark),
                        ),
                        child: Text(
                          '${diffFromFirst >= 0 ? "+" : ""}${diffFromFirst.toStringAsFixed(2)} (${diffFromFirst >= 0 ? "+" : ""}${pctDiffFromFirst.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            color: diffFromFirst >= 0 ? AppTheme.profit(widget.isDark) : AppTheme.loss(widget.isDark),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (timestampStr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        timestampStr,
                        style: TextStyle(
                          color: AppTheme.textMuted(widget.isDark),
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                ],
              ),

              // Timeframe Switcher
              _buildTimeframeBar(),
            ],
          ),

          const SizedBox(height: 14),

          // ── Interactive fl_chart LineChart ─────────────────────────────────
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: priceDiff > 0 ? priceDiff / 3 : 1.0,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: widget.isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.04),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    if (!event.isInterestedForInteractions ||
                        touchResponse == null ||
                        touchResponse.lineBarSpots == null ||
                        touchResponse.lineBarSpots!.isEmpty) {
                      setState(() => _touchedIndex = null);
                      return;
                    }
                    setState(() {
                      _touchedIndex = touchResponse.lineBarSpots!.first.spotIndex;
                    });
                  },
                  getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((spotIndex) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: trendColor.withOpacity(0.6),
                          strokeWidth: 1.5,
                          dashArray: [3, 3],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                            radius: 5,
                            color: trendColor,
                            strokeWidth: 2.5,
                            strokeColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => widget.isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    tooltipBorder: BorderSide(
                      color: trendColor.withOpacity(0.5),
                      width: 1,
                    ),
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          '${widget.currencySymbol}${barSpot.y.toStringAsFixed(2)}',
                          TextStyle(
                            color: trendColor,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    color: trendColor,
                    barWidth: 2.2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          trendColor.withOpacity(widget.isDark ? 0.28 : 0.18),
                          trendColor.withOpacity(widget.isDark ? 0.02 : 0.00),
                        ],
                      ),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    // Baseline (starting price)
                    HorizontalLine(
                      y: firstPrice,
                      color: widget.isDark ? Colors.white24 : Colors.black26,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: false,
                      ),
                    ),
                    // Optional Target Line
                    if (widget.targetPrice != null &&
                        widget.targetPrice! >= minY &&
                        widget.targetPrice! <= maxY)
                      HorizontalLine(
                        y: widget.targetPrice!,
                        color: AppTheme.profit(widget.isDark).withOpacity(0.8),
                        strokeWidth: 1.2,
                        dashArray: [5, 3],
                      ),
                    // Optional Stop Loss Line
                    if (widget.stopLossPrice != null &&
                        widget.stopLossPrice! >= minY &&
                        widget.stopLossPrice! <= maxY)
                      HorizontalLine(
                        y: widget.stopLossPrice!,
                        color: AppTheme.loss(widget.isDark).withOpacity(0.8),
                        strokeWidth: 1.2,
                        dashArray: [5, 3],
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Footer: Low / High markers & indicators ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'LOW: ',
                    style: TextStyle(
                      color: AppTheme.textMuted(widget.isDark),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${widget.currencySymbol}${minPrice.toStringAsFixed(2)}',
                    style: AppTheme.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.loss(widget.isDark),
                    ),
                  ),
                ],
              ),
              if (widget.targetPrice != null)
                Row(
                  children: [
                    Text(
                      'TARGET: ',
                      style: TextStyle(
                        color: AppTheme.textMuted(widget.isDark),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${widget.currencySymbol}${widget.targetPrice!.toStringAsFixed(2)}',
                      style: AppTheme.mono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.profit(widget.isDark),
                      ),
                    ),
                  ],
                ),
              Row(
                children: [
                  Text(
                    'HIGH: ',
                    style: TextStyle(
                      color: AppTheme.textMuted(widget.isDark),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${widget.currencySymbol}${maxPrice.toStringAsFixed(2)}',
                    style: AppTheme.mono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.profit(widget.isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeBar() {
    final frames = ['1D', '1W', '1M', '1Y'];
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: frames.map((tf) {
          final isSelected = widget.activeTimeframe == tf;
          return GestureDetector(
            onTap: () {
              if (widget.onTimeframeChanged != null) {
                widget.onTimeframeChanged!(tf);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (widget.isDark ? const Color(0xFF0F172A) : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                tf,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (widget.isDark ? AppTheme.accentCyan : const Color(0xFF1D4ED8))
                      : AppTheme.textMuted(widget.isDark),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
