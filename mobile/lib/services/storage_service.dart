import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  static String? _cachedActiveBaseUrl;
  static DateTime? _lastHealthCheckTime;

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keyBaseUrl)?.trim();

    // 1. If user explicitly entered a custom URL (that is NOT the default cloud URL), respect it
    if (saved != null &&
        saved.isNotEmpty &&
        saved != cloudProductionUrl &&
        !saved.contains('10.0.2.2')) {
      return saved;
    }

    // Cache active URL for 15 seconds to minimize network checks
    final now = DateTime.now();
    if (_cachedActiveBaseUrl != null &&
        _lastHealthCheckTime != null &&
        now.difference(_lastHealthCheckTime!).inSeconds < 15) {
      return _cachedActiveBaseUrl!;
    }

    // 2. Check if local ADB reverse port 8000 daemon is active on the device
    try {
      final res = await http
          .get(Uri.parse('http://127.0.0.1:8000/api/v1/market-status'))
          .timeout(const Duration(milliseconds: 1200));
      if (res.statusCode == 200) {
        _cachedActiveBaseUrl = 'http://127.0.0.1:8000';
        _lastHealthCheckTime = now;
        return _cachedActiveBaseUrl!;
      }
    } catch (_) {}

    // 3. Fallback to 24/7 Cloud Production Backend
    _cachedActiveBaseUrl = cloudProductionUrl;
    _lastHealthCheckTime = now;
    return cloudProductionUrl;
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

  static const String keyDarkMode = 'user_is_dark_mode';
  static const String keyOnlySellAlerts = 'user_only_sell_alerts';

  static Future<bool> getOnlySellAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    // Default is true (User strictly wants SELL alerts only for bought/marked stocks)
    return prefs.getBool(keyOnlySellAlerts) ?? true;
  }

  static Future<void> setOnlySellAlerts(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyOnlySellAlerts, enabled);
  }

  static Future<bool> getIsDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Default is false (White & Blue theme)
    return prefs.getBool(keyDarkMode) ?? false;
  }

  static Future<void> setIsDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyDarkMode, enabled);
  }

  static Future<void> setAutoTakeProfit(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAutoTakeProfit, enabled);
  }

  // ────────────────────────────────────────────────────────────
  // Dual-Market Architecture: Indian & US Stock Market Settings
  // ────────────────────────────────────────────────────────────
  static const String keyActiveMarket = 'user_selected_market'; // 'INDIA' or 'US'

  static Future<String> getActiveMarket() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyActiveMarket) ?? 'INDIA';
  }

  static Future<void> setActiveMarket(String market) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyActiveMarket, market.toUpperCase());
  }

  static Future<List<String>> getRecentlyAnalyzed(String market) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('recently_analyzed_${market.toUpperCase()}') ?? [];
  }

  static Future<void> addRecentlyAnalyzed(String symbol, String market) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'recently_analyzed_${market.toUpperCase()}';
      final list = prefs.getStringList(key) ?? [];
      final sym = symbol.toUpperCase().trim();
      list.remove(sym);
      list.insert(0, sym);
      if (list.length > 15) {
        list.removeRange(15, list.length);
      }
      await prefs.setStringList(key, list);
    } catch (_) {}
  }
}
