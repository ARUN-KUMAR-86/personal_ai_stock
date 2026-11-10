import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;
  final double? fontSize;
  final bool showIcon;

  const PriorityBadge({
    super.key,
    required this.priority,
    this.fontSize,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final clean = priority.trim().toUpperCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color badgeColor;
    IconData icon;
    String label;

    if (clean == 'P0' || clean.contains('CRITICAL')) {
      badgeColor = isDark ? const Color(0xFFFF3366) : const Color(0xFFDC2626);
      icon = Icons.warning_rounded;
      label = clean == 'P0' ? 'P0 • CRITICAL' : clean;
    } else if (clean == 'P1' || clean.contains('VERY HIGH')) {
      badgeColor = isDark ? Colors.deepOrangeAccent : const Color(0xFFEA580C);
      icon = Icons.local_fire_department;
      label = clean == 'P1' ? 'P1 • VERY HIGH' : clean;
    } else if (clean == 'P2' || clean == 'HIGH' || clean.contains('HIGH')) {
      badgeColor = isDark ? Colors.amberAccent : const Color(0xFFD97706);
      icon = Icons.trending_up;
      label = clean == 'P2' ? 'P2 • HIGH' : clean;
    } else if (clean == 'P3' || clean == 'MEDIUM' || clean.contains('MEDIUM')) {
      badgeColor = isDark ? const Color(0xFF00E676) : const Color(0xFF059669);
      icon = Icons.shield_outlined;
      label = clean == 'P3' ? 'P3 • MEDIUM' : clean;
    } else {
      badgeColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      icon = Icons.info_outline;
      label = clean == 'P4' ? 'P4 • LOW' : (clean.isEmpty ? 'P4 • WATCH' : clean);
    }

    final double effectiveFontSize = fontSize ?? 10.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: AppTheme.terminalBadge(color: badgeColor, radius: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: effectiveFontSize + 2, color: badgeColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w800,
              fontSize: effectiveFontSize,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
