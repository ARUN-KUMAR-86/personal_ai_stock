import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Professional institutional stat card with theme awareness,
/// optional trend icon, and micro-metrics.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? valueColor;
  final Color? accentColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.valueColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardBox(
        isDark,
        borderCol: accentColor?.withOpacity(0.3),
        glow: accentColor != null,
        glowColor: accentColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.textMuted(isDark),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  size: 16,
                  color: accentColor ?? AppTheme.textMuted(isDark),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.mono(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor ?? AppTheme.textPrimary(isDark),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppTheme.textMuted(isDark),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
