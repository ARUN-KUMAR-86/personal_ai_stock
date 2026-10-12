import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String keyBaseUrl = 'backend_base_url';
  static const String keyAuthToken = 'auth_jwt_token';
  static const String keyFcmToken = 'fcm_device_token';

  /// Compile-time configured API URL passed via `--dart-define=API_URL=https://...`
  static const String definedApiUrl = String.fromEnvironment('API_URL', defaultValue: '');

  /// Default base URL logic:
  /// 1. If defined at build-time (e.g. production cloud URL), use it.
  /// 2. If web, use localhost:8000.
  /// Default base URL logic:
  /// 1. If defined at build-time (e.g. production cloud URL), use it.
  /// 2. If web, use localhost:8000.
  /// 3. Physical phone default: use current workstation IP (10.246.109.77:8000).
  static String get defaultBaseUrl {
    if (definedApiUrl.isNotEmpty) {
      return definedApiUrl.trim();
    }
    return kIsWeb ? 'http://localhost:8000' : 'http://10.246.109.77:8000';
  }

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keyBaseUrl);
    // Ignore stale emulator IP on physical devices
    if (saved != null && saved.trim().isNotEmpty && !saved.contains('10.0.2.2')) {
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
}
