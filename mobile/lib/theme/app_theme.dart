import 'package:flutter/material.dart';

/// Institutional Financial Trading Terminal Theme System
/// Provides high-contrast, data-dense, eye-friendly palettes for both
/// Obsidian Dark (pro-terminal) and Executive Light modes.
class AppTheme {
  // ── Obsidian Dark Palette ──────────────────────────────────────────────────
  static const Color darkScaffold = Color(0xFF080C14);
  static const Color darkCard = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF162032);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkBorderLight = Color(0xFF334155);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // ── Executive Light Palette ────────────────────────────────────────────────
  static const Color lightScaffold = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderDark = Color(0xFFCBD5E1);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // ── High-Impact Financial Signal Colors ────────────────────────────────────
  static const Color profitGreen = Color(0xFF00E676);      // Neon emerald for dark
  static const Color profitGreenLight = Color(0xFF059669); // Deep emerald for light
  static const Color lossRed = Color(0xFFFF3366);          // High-contrast crimson for dark
  static const Color lossRedLight = Color(0xFFDC2626);     // Deep crimson for light

  static const Color accentCyan = Color(0xFF00F0FF);       // Cybernetic cyan
  static const Color accentBlue = Color(0xFF3B82F6);       // Royal blue
  static const Color accentGold = Color(0xFFF59E0B);       // Signal warning / pending
  static const Color accentPurple = Color(0xFFA855F7);     // Institutional AI / ML

  // ── Dynamic Accessors ──────────────────────────────────────────────────────
  static Color scaffold(bool isDark) => isDark ? darkScaffold : lightScaffold;
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color borderStrong(bool isDark) => isDark ? darkBorderLight : lightBorderDark;

  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color textMuted(bool isDark) => isDark ? darkTextMuted : lightTextMuted;

  static Color profit(bool isDark) => isDark ? profitGreen : profitGreenLight;
  static Color loss(bool isDark) => isDark ? lossRed : lossRedLight;

  // ── Common BoxDecorations ──────────────────────────────────────────────────
  static BoxDecoration cardBox(
    bool isDark, {
    Color? borderCol,
    double borderWidth = 1.0,
    double radius = 14.0,
    bool glow = false,
    Color? glowColor,
  }) {
    return BoxDecoration(
      color: card(isDark),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderCol ?? border(isDark),
        width: borderWidth,
      ),
      boxShadow: [
        if (glow && glowColor != null)
          BoxShadow(
            color: glowColor.withOpacity(isDark ? 0.22 : 0.12),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )
        else if (isDark)
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        else
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
      ],
    );
  }

  static BoxDecoration terminalBadge({
    required Color color,
    double radius = 6.0,
    double opacity = 0.12,
  }) {
    return BoxDecoration(
      color: color.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: color.withOpacity(0.35),
        width: 1.0,
      ),
    );
  }

  // ── Monospace Figures (for Stock Prices, Ticks, Dates) ──────────────────────
  static TextStyle mono({
    double fontSize = 13.0,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = -0.2,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  // ── Material ThemeData Objects ─────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScaffold,
      primaryColor: accentBlue,
      cardColor: darkCard,
      canvasColor: darkScaffold,
      dividerColor: darkBorder,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentCyan,
        surface: darkCard,
        surfaceContainerHighest: darkSurface,
        onSurface: darkTextPrimary,
        error: lossRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCard,
        selectedItemColor: accentCyan,
        unselectedItemColor: darkTextMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightScaffold,
      primaryColor: const Color(0xFF1D4ED8),
      cardColor: lightCard,
      canvasColor: lightScaffold,
      dividerColor: lightBorder,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1D4ED8),
        secondary: Color(0xFF0284C7),
        surface: lightCard,
        surfaceContainerHighest: lightSurface,
        onSurface: lightTextPrimary,
        error: lossRedLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightCard,
        foregroundColor: lightTextPrimary,
        elevation: 0.5,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightCard,
        selectedItemColor: Color(0xFF1D4ED8),
        unselectedItemColor: lightTextMuted,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
      ),
    );
  }
}
