import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/market_status.dart';
import '../models/stock_summary.dart';
import '../models/signal.dart';
import '../models/alert.dart';
import '../models/portfolio.dart';
import '../models/funds.dart';
import 'storage_service.dart';

class ApiService {
  Future<String> _getUrl(String endpoint) async {
    final baseUrl = await StorageService.getBaseUrl();
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return '$cleanBase/api/v1$cleanEndpoint';
  }

  Future<Map<String, String>> _headers() async {
    final token = await StorageService.getAuthToken();
    final map = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  Future<bool> checkHealth() async {
    try {
      final url = await _getUrl('/health');
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<MarketStatus> getMarketStatus({String exchange = 'NSE'}) async {
    final url = await _getUrl('/market-status?exchange=$exchange');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      return MarketStatus.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load market status (${res.statusCode})');
  }

  Future<List<StockSummary>> getStockUniverse({String exchange = 'NSE', String? signalType}) async {
    var query = '?exchange=$exchange';
    if (signalType != null && signalType.isNotEmpty) {
      query += '&signal_type=${Uri.encodeComponent(signalType)}';
    }
    final url = await _getUrl('/stocks/universe$query');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List raw = jsonDecode(res.body);
      return raw.map((item) => StockSummary.fromJson(item)).toList();
    }
    throw Exception('Failed to load stocks universe');
  }

  Future<List<Map<String, dynamic>>> getStockCandles(String symbol, {String timeframe = '1d'}) async {
    final url = await _getUrl('/stocks/$symbol/candles?timeframe=$timeframe');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<StockSignal>> getLatestSignals({int limit = 20}) async {
    final url = await _getUrl('/signals/latest?limit=$limit');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List raw = jsonDecode(res.body);
      return raw.map((item) => StockSignal.fromJson(item)).toList();
    }
    return [];
  }

  Future<List<StockSignal>> getSignalsForStock(String symbol) async {
    final url = await _getUrl('/signals/$symbol');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      final List raw = jsonDecode(res.body);
      return raw.map((item) => StockSignal.fromJson(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> triggerScan({bool force = false}) async {
    final url = await _getUrl('/scanner/scan');
    final headers = await _headers();
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'force_rescan': force, 'exchange': 'NSE'}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to trigger scan');
  }

  Future<Map<String, dynamic>> getScannerStatus() async {
    final url = await _getUrl('/scanner/status');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {'is_scanning': false};
  }

  Future<List<StockAlert>> getAlerts({bool unreadOnly = false}) async {
    final url = await _getUrl('/alerts/history?unread_only=$unreadOnly');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List raw = jsonDecode(res.body);
      return raw.map((a) => StockAlert.fromJson(a)).toList();
    }
    return [];
  }

  Future<void> markAlertsRead(List<int> alertIds) async {
    final url = await _getUrl('/alerts/mark-read');
    final headers = await _headers();
    await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'alert_ids': alertIds}),
    );
  }

  Future<bool> sendTestPushAlert() async {
    final url = await _getUrl('/alerts/test-push');
    final headers = await _headers();
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'title': 'PERSONAL AI STOCK ALERT [TEST]',
        'body': 'Test alert dispatched to Android device from Personal AI Stock System.',
        'symbol': 'RELIANCE',
      }),
    );
    return res.statusCode == 200;
  }

  Future<PortfolioSummary> getPortfolioSummary() async {
    final url = await _getUrl('/portfolio/summary');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return PortfolioSummary.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load portfolio');
  }

  Future<bool> executePaperTrade({
    required String symbol,
    required String action,
    required int quantity,
    double? price,
  }) async {
    final url = await _getUrl('/portfolio/paper-trades');
    final headers = await _headers();
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'symbol': symbol,
        'action': action,
        'quantity': quantity,
        'price': price,
        'exchange': 'NSE',
      }),
    );
    return res.statusCode == 200;
  }

  Future<BrokerFunds> getFunds() async {
    final url = await _getUrl('/funds');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return BrokerFunds.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load broker funds');
  }

  Future<BrokerFunds> syncFunds() async {
    final url = await _getUrl('/funds/sync');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers);
    if (res.statusCode == 200) {
      return BrokerFunds.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to synchronize funds');
  }

  Future<bool> login(String username, String password) async {
    final url = await _getUrl('/auth/login');
    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final token = data['access_token'];
      if (token != null) {
        await StorageService.setAuthToken(token);
        return true;
      }
    }
    return false;
  }
}
