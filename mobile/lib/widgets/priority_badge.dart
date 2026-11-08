import 'package:flutter/material.dart';

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

    Color badgeColor;
    Color bgColor;
    IconData icon;
    String label;

    if (clean == 'P0' || clean.contains('CRITICAL')) {
      badgeColor = Colors.redAccent;
      bgColor = const Color(0xFF381216);
      icon = Icons.warning_rounded;
      label = clean == 'P0' ? 'P0 • CRITICAL' : clean;
    } else if (clean == 'P1' || clean.contains('VERY HIGH')) {
      badgeColor = Colors.deepOrangeAccent;
      bgColor = const Color(0xFF351A10);
      icon = Icons.local_fire_department;
      label = clean == 'P1' ? 'P1 • VERY HIGH' : clean;
    } else if (clean == 'P2' || clean == 'HIGH' || clean.contains('HIGH')) {
      badgeColor = Colors.amberAccent;
      bgColor = const Color(0xFF332910);
      icon = Icons.trending_up;
      label = clean == 'P2' ? 'P2 • HIGH' : clean;
    } else if (clean == 'P3' || clean == 'MEDIUM' || clean.contains('MEDIUM')) {
      badgeColor = Colors.greenAccent;
      bgColor = const Color(0xFF10281C);
      icon = Icons.shield_outlined;
      label = clean == 'P3' ? 'P3 • MEDIUM' : clean;
    } else {
      badgeColor = Colors.lightBlueAccent;
      bgColor = const Color(0xFF132238);
      icon = Icons.info_outline;
      label = clean == 'P4' ? 'P4 • LOW' : (clean.isEmpty ? 'P4 • WATCH' : clean);
    }

    final double effectiveFontSize = fontSize ?? 10.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withOpacity(0.8), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.18),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
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
              fontWeight: FontWeight.bold,
              fontSize: effectiveFontSize,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
