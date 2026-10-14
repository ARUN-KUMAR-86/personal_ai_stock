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
    final isHigh = clean == 'HIGH' || clean.contains('HIGH');
    final isMedium = clean == 'MEDIUM' || clean.contains('MEDIUM');

    // Strict user requirement: Highest Priority = RED, Medium = GREEN
    final Color badgeColor = isHigh
        ? Colors.redAccent
        : (isMedium ? Colors.greenAccent : Colors.lightBlueAccent);

    final Color bgColor = isHigh
        ? const Color(0xFF381216)
        : (isMedium ? const Color(0xFF10281C) : const Color(0xFF132238));

    final IconData icon = isHigh
        ? Icons.local_fire_department
        : (isMedium ? Icons.shield_outlined : Icons.info_outline);

    final String label = isHigh
        ? 'HIGH PRIORITY'
        : (isMedium ? 'MEDIUM PRIORITY' : 'NORMAL');

    final double effectiveFontSize = fontSize ?? 10.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withOpacity(0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.18),
            blurRadius: 6,
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
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
