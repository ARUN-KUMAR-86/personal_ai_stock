import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/portfolio.dart';

class StorageService {
  static const String keyBaseUrl = 'backend_base_url';
  static const String keyAuthToken = 'auth_jwt_token';
  static const String keyFcmToken = 'fcm_device_token';
  static const String keyCachedPortfolio = 'cached_portfolio_json';
  static const String keyCachedPaperTrades = 'cached_paper_trades_json';
  static const String keyActiveAlgorithm = 'user_active_algorithm';
  static const String keyAutoTakeProfit = 'user_auto_take_profit';

  /// Primary Production Cloud URL (Render 24/7)
  static const String cloudProductionUrl = 'https://personal-ai-stock-backend.onrender.com';

  /// Compile-time configured API URL passed via `--dart-define=API_URL=https://...`
  static const String definedApiUrl = String.fromEnvironment('API_URL', defaultValue: '');

  /// Default base URL logic:
  /// Always load the live cloud backend by default! No copy-pasting needed.
  static String get defaultBaseUrl {
    if (definedApiUrl.isNotEmpty) {
      return definedApiUrl.trim();
    }
    return cloudProductionUrl;
  }

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keyBaseUrl);
    // If the saved URL is empty or points to stale emulator or local IP,
    // automatically default to the live cloud URL!
    if (saved != null &&
        saved.trim().isNotEmpty &&
        !saved.contains('10.0.2.2') &&
        !saved.contains('10.246.109.77') &&
        !saved.contains('192.168.1.77')) {
      return saved.trim();
    }
    return defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBaseUrl, url.trim());
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyAuthToken);
  }

  static Future<void> setAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyAuthToken, token);
  }

  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyAuthToken);
  }

  static Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyFcmToken);
  }

  static Future<void> setFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyFcmToken, token);
  }

  static const String keyWatchlist = 'user_watchlist_symbols';

  static Future<List<String>> getWatchlist() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyWatchlist) ?? [];
  }

  static Future<void> saveWatchlist(List<String> symbols) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(keyWatchlist, symbols.map((s) => s.toUpperCase()).toList());
  }

  static Future<bool> toggleWatchlist(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(keyWatchlist) ?? [];
    final upper = symbol.toUpperCase();
    bool added;
    if (list.contains(upper)) {
      list.remove(upper);
      added = false;
    } else {
      list.add(upper);
      added = true;
    }
    await prefs.setStringList(keyWatchlist, list);
    return added;
  }

  // ────────────────────────────────────────────────────────────
  // Offline & Persistent Local Storage for Paper Trades & Portfolio
  // Ensures trades are NEVER lost when app is closed / reopened!
  // ────────────────────────────────────────────────────────────

  static Future<void> saveCachedPortfolio(PortfolioSummary portfolio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(portfolio.toJson());
      await prefs.setString(keyCachedPortfolio, jsonStr);
    } catch (e) {
      debugPrint('Error caching portfolio locally: $e');
    }
  }

  static Future<PortfolioSummary?> getCachedPortfolio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(keyCachedPortfolio);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        return PortfolioSummary.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('Error reading cached portfolio: $e');
    }
    return null;
  }

  static Future<void> saveCachedPaperTrades(List<PaperTrade> trades) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = trades.map((t) => t.toJson()).toList();
      await prefs.setString(keyCachedPaperTrades, jsonEncode(rawList));
    } catch (e) {
      debugPrint('Error caching paper trades: $e');
    }
  }

  static Future<List<PaperTrade>> getCachedPaperTrades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(keyCachedPaperTrades);
      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        return decoded.map((item) => PaperTrade.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error reading cached paper trades: $e');
    }
    return [];
  }

  static Future<void> addLocalPaperTrade(PaperTrade trade) async {
    try {
      final trades = await getCachedPaperTrades();
      // Insert at the front (latest first)
      trades.insert(0, trade);
      await saveCachedPaperTrades(trades);
    } catch (e) {
      debugPrint('Error adding local paper trade: $e');
    }
  }

  static Future<String> getActiveAlgorithm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyActiveAlgorithm) ?? 'Highest Profit Maximizer (Auto Take Money)';
  }

  static Future<void> setActiveAlgorithm(String algo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyActiveAlgorithm, algo);
  }

  static Future<bool> getAutoTakeProfit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyAutoTakeProfit) ?? true;
  }

  static Future<void> setAutoTakeProfit(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAutoTakeProfit, enabled);
  }
}
