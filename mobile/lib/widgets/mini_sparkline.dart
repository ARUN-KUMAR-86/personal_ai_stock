import 'package:flutter/material.dart';

/// Lightweight custom-painted sparkline for stock ticker cards.
/// Zero widget tree bloat, ultra-smooth 60fps scroll performance.
class MiniSparkline extends StatelessWidget {
  final List<double> data;
  final bool isPositive;
  final double width;
  final double height;
  final Color? customColor;

  const MiniSparkline({
    super.key,
    required this.data,
    required this.isPositive,
    this.width = 68.0,
    this.height = 26.0,
    this.customColor,
  });

  /// Generates a synthetic realistic 7-point intra-day sparkline when full historical candle array isn't cached
  factory MiniSparkline.fromTrend({
    required double price,
    required double changePct,
    double? high,
    double? low,
    double width = 68.0,
    double height = 26.0,
  }) {
    final isPos = changePct >= 0;
    final h = high != null && high > price ? high : price * (1 + (changePct.abs() * 0.005));
    final l = low != null && low < price && low > 0 ? low : price * (1 - (changePct.abs() * 0.005));

    final openPrice = price / (1 + (changePct / 100));
    final mid1 = isPos ? openPrice + (price - openPrice) * 0.35 : openPrice - (openPrice - price) * 0.25;
    final mid2 = isPos ? l : h;
    final mid3 = isPos ? h : l;
    final mid4 = isPos ? price * 0.99 : price * 1.01;

    return MiniSparkline(
      data: [openPrice, mid1, mid2, mid3, mid4, price],
      isPositive: isPos,
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(width: width, height: height);

    final color = customColor ?? (isPositive ? const Color(0xFF00E676) : const Color(0xFFFF3366));

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(data: data, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    double minVal = data.first;
    double maxVal = data.first;
    for (final v in data) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }

    final diff = (maxVal - minVal);
    final range = diff == 0 ? 1.0 : diff;

    final linePath = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      // Invert Y so higher price is higher on screen
      final normalizedY = (data[i] - minVal) / range;
      final y = size.height - (normalizedY * (size.height - 4) + 2);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        // Smooth cubic bezier
        final prevX = (i - 1) * stepX;
        final prevNormY = (data[i - 1] - minVal) / range;
        final prevY = size.height - (prevNormY * (size.height - 4) + 2);

        final midX = (prevX + x) / 2;
        linePath.cubicTo(midX, prevY, midX, y, x, y);
        fillPath.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Gradient fill beneath curve
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.25),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Glowing main line
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
  }
}
