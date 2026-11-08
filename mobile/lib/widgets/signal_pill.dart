import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SignalPill extends StatelessWidget {
  final String signalType;
  final double? strength;

  const SignalPill({
    super.key,
    required this.signalType,
    this.strength,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upper = signalType.toUpperCase();

    Color color;
    IconData? icon;

    if (upper.contains('BUY')) {
      color = AppTheme.profit(isDark);
      icon = Icons.trending_up;
    } else if (upper.contains('SELL') || upper.contains('EXIT')) {
      color = AppTheme.loss(isDark);
      icon = Icons.trending_down;
    } else if (upper.contains('HOLD') || upper.contains('WATCH')) {
      color = isDark ? AppTheme.accentCyan : const Color(0xFF0284C7);
      icon = Icons.visibility_outlined;
    } else {
      color = AppTheme.textMuted(isDark);
      icon = Icons.remove_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: AppTheme.terminalBadge(color: color, radius: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            signalType,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
          if (strength != null && strength! > 0) ...[
            const SizedBox(width: 4),
            Text(
              '${strength!.toInt()}%',
              style: TextStyle(
                color: color.withOpacity(0.85),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
