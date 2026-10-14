import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/market_status.dart';
import '../models/stock_summary.dart';
import '../models/signal.dart';
import '../models/alert.dart';
import '../models/portfolio.dart';
import '../models/funds.dart';
import '../models/order.dart';
import '../models/watchlist.dart';
import '../models/trading_control.dart';
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
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) return true;
    } catch (_) {}

    // Resilient Cloud Fallback with wake-up handling (takes up to 18 seconds for sleeping Render):
    try {
      const cloudUrl = StorageService.cloudProductionUrl;
      final res = await http.get(Uri.parse('$cloudUrl/health')).timeout(const Duration(seconds: 18));
      if (res.statusCode == 200) {
        await StorageService.setBaseUrl(cloudUrl);
        return true;
      }
    } catch (_) {}

    return false;
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

  Future<Map<String, dynamic>> getScheduleStatus() async {
    try {
      final url = await _getUrl('/scanner/schedule/status');
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {'auto_scan_active': false, 'scheduler_running': false};
  }

  Future<Map<String, dynamic>> startSchedule({int intervalMinutes = 15}) async {
    final url = await _getUrl('/scanner/schedule/start?interval_minutes=$intervalMinutes');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to start analysis schedule: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> stopSchedule() async {
    final url = await _getUrl('/scanner/schedule/stop');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to stop analysis schedule: ${res.statusCode}');
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

  Future<bool> registerDeviceToken(String token, {String deviceName = 'Android Phone'}) async {
    try {
      final url = await _getUrl('/alerts/register-token');
      final headers = await _headers();
      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'token': token,
          'device_name': deviceName,
        }),
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unregisterDeviceToken(String token) async {
    try {
      final url = await _getUrl('/alerts/unregister-token?token=${Uri.encodeComponent(token)}');
      final headers = await _headers();
      final res = await http.post(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
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
    double? stopLoss,
    double? target,
    int holdingPeriodHours = 48,
    bool autoSellEnabled = true,
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
        if (price != null) 'price': price,
        'exchange': 'NSE',
        if (stopLoss != null) 'stop_loss': stopLoss,
        if (target != null) 'target': target,
        'holding_period_hours': holdingPeriodHours,
        'auto_sell_enabled': autoSellEnabled,
      }),
    ).timeout(const Duration(seconds: 10));
    return res.statusCode == 200 || res.statusCode == 201;
  }

  Future<List<PaperTrade>> getPaperTrades({int limit = 50}) async {
    try {
      final url = await _getUrl('/portfolio/paper-trades?limit=$limit');
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body);
        return raw.map((item) => PaperTrade.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> syncPaperTrades(List<PaperTrade> trades) async {
    if (trades.isEmpty) return;
    try {
      final url = await _getUrl('/portfolio/sync-paper-trades');
      final headers = await _headers();
      await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'trades': trades.map((t) => t.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<Map<String, dynamic>> triggerAutoSellCheck() async {
    try {
      final url = await _getUrl('/portfolio/auto-sell-check');
      final headers = await _headers();
      final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {};
  }

  /// Ultra-low latency single-roundtrip synchronization endpoint
  Future<UltraSyncData?> ultraSync({bool runAutoSell = true}) async {
    final sw = Stopwatch()..start();
    try {
      final url = await _getUrl('/portfolio/ultra-sync?run_auto_sell=$runAutoSell');
      final headers = await _headers();
      final res = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 5));
      sw.stop();
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        return UltraSyncData.fromJson(data, sw.elapsedMilliseconds);
      }
    } catch (_) {}
    return null;
  }

  /// Ultra-low latency direct trade execution (< 50ms)
  Future<Map<String, dynamic>?> executeUltraTrade({
    required String symbol,
    required String action,
    required int quantity,
    double? price,
    double? stopLoss,
    double? target,
    int holdingPeriodHours = 48,
    bool autoSellEnabled = true,
  }) async {
    try {
      final url = await _getUrl('/portfolio/ultra-trade');
      final headers = await _headers();
      final res = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'symbol': symbol,
          'action': action,
          'quantity': quantity,
          if (price != null) 'price': price,
          'exchange': 'NSE',
          if (stopLoss != null) 'stop_loss': stopLoss,
          if (target != null) 'target': target,
          'holding_period_hours': holdingPeriodHours,
          'auto_sell_enabled': autoSellEnabled,
        }),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
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

  Future<StockSignal> getStockRecommendation(String symbol, {String exchange = 'NSE'}) async {
    final url = await _getUrl('/signals/recommendation/$symbol?exchange=$exchange');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return StockSignal.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load stock recommendation for $symbol (${res.statusCode})');
  }

  Future<StockSignal> regenerateAIThesis(int signalId) async {
    final url = await _getUrl('/signals/$signalId/thesis/regenerate');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 12));
    if (res.statusCode == 200) {
      return StockSignal.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to regenerate AI investment thesis (${res.statusCode})');
  }

  Future<Map<String, dynamic>> getStockAIThesis(String symbol, {String exchange = 'NSE'}) async {
    final url = await _getUrl('/stocks/$symbol/thesis?exchange=$exchange');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(res.body));
    }
    throw Exception('Failed to load AI thesis for $symbol (${res.statusCode})');
  }

  Future<OrderCalculation> calculateOrderMetrics({
    required String symbol,
    required double investmentAmount,
    double? entryPrice,
    double? stopLoss,
    double? target,
    int holdingPeriodHours = 48,
  }) async {
    final url = await _getUrl('/orders/calculate');
    final headers = await _headers();
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'symbol': symbol,
        'exchange': 'NSE',
        'investment_amount': investmentAmount,
        'entry_price': entryPrice,
        'stop_loss': stopLoss,
        'target': target,
        'holding_period_hours': holdingPeriodHours,
      }),
    ).timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      return OrderCalculation.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to calculate trade metrics: ${res.body}');
  }

  Future<PreparedBuyOrder> prepareBuyOrder({
    required String symbol,
    required double investmentAmount,
    required double expectedPrice,
    required double stopLoss,
    required double target,
    int holdingPeriodHours = 48,
    int? signalId,
  }) async {
    final url = await _getUrl('/orders/prepare-buy');
    final headers = await _headers();
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'symbol': symbol,
        'exchange': 'NSE',
        'investment_amount': investmentAmount,
        'expected_price': expectedPrice,
        'stop_loss': stopLoss,
        'target': target,
        'holding_period_hours': holdingPeriodHours,
        'signal_id': signalId,
      }),
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return PreparedBuyOrder.fromJson(jsonDecode(res.body));
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to prepare buy order');
  }

  Future<ConfirmedOrder> confirmBuyOrder({
    required String clientOrderId,
    required String symbol,
    required double investmentAmount,
    required double confirmedPrice,
    required int quantity,
    required double stopLoss,
    required double target,
    int holdingPeriodHours = 48,
    bool autoSellEnabled = false,
    int? signalId,
  }) async {
    final url = await _getUrl('/orders/buy-confirm');
    final headers = await _headers();
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'client_order_id': clientOrderId,
        'symbol': symbol,
        'exchange': 'NSE',
        'investment_amount': investmentAmount,
        'confirmed_price': confirmedPrice,
        'quantity': quantity,
        'stop_loss': stopLoss,
        'target': target,
        'holding_period_hours': holdingPeriodHours,
        'auto_sell_enabled': autoSellEnabled,
        'user_confirmed': true,
        'signal_id': signalId,
      }),
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode == 200) {
      return ConfirmedOrder.fromJson(jsonDecode(res.body));
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Order execution failed');
  }

  Future<SafetyStatus> getSafetyStatus() async {
    final url = await _getUrl('/safety/status');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
    if (res.statusCode == 200) {
      return SafetyStatus.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load safety status');
  }

  Future<bool> toggleEmergencyStop(bool enabled) async {
    final url = await _getUrl('/safety/emergency-stop?enabled=$enabled');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers);
    return res.statusCode == 200;
  }

  Future<SafetyStatus> updateSafetySettings({
    bool? emergencyStopEnabled,
    bool? autoSellEnabled,
    double? maxPositionRiskPct,
    double? maxSingleStockPct,
    double? maxPortfolioExposurePct,
  }) async {
    final url = await _getUrl('/safety/settings');
    final headers = await _headers();
    final res = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        if (emergencyStopEnabled != null) 'emergency_stop_enabled': emergencyStopEnabled,
        if (autoSellEnabled != null) 'auto_sell_enabled': autoSellEnabled,
        if (maxPositionRiskPct != null) 'max_position_risk_pct': maxPositionRiskPct,
        if (maxSingleStockPct != null) 'max_single_stock_pct': maxSingleStockPct,
        if (maxPortfolioExposurePct != null) 'max_portfolio_exposure_pct': maxPortfolioExposurePct,
      }),
    );
    if (res.statusCode == 200) {
      return SafetyStatus.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update safety settings');
  }

  Future<bool> updatePositionMonitoring(
    int positionId, {
    double? stopLoss,
    double? target,
    int? holdingPeriodHours,
    bool? autoSellEnabled,
  }) async {
    final url = await _getUrl('/safety/positions/$positionId/monitoring');
    final headers = await _headers();
    final res = await http.put(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        if (stopLoss != null) 'stop_loss': stopLoss,
        if (target != null) 'target': target,
        if (holdingPeriodHours != null) 'holding_period_hours': holdingPeriodHours,
        if (autoSellEnabled != null) 'auto_sell_enabled': autoSellEnabled,
      }),
    );
    return res.statusCode == 200;
  }

  Future<bool> triggerPositionMonitorCheck() async {
    final url = await _getUrl('/safety/monitor-check');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers);
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> getGrowwStatus() async {
    try {
      final url = await _getUrl('/groww/status');
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {'is_configured': false, 'is_authenticated': false};
  }

  Future<Map<String, dynamic>> loginGroww({
    String? apiKey,
    String? apiSecret,
    String? totpKey,
    String? authToken,
    bool orderExecutionEnabled = false,
  }) async {
    final url = await _getUrl('/groww/login');
    final headers = await _headers();
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        if (apiSecret != null && apiSecret.isNotEmpty) 'api_secret': apiSecret,
        if (totpKey != null && totpKey.isNotEmpty) 'totp_key': totpKey,
        if (authToken != null && authToken.isNotEmpty) 'auth_token': authToken,
        'order_execution_enabled': orderExecutionEnabled,
      }),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Groww login failed');
  }

  Future<Map<String, dynamic>> logoutGroww() async {
    final url = await _getUrl('/groww/logout');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return {'success': false};
  }

  Future<Map<String, dynamic>> refreshGrowwAuth() async {
    final url = await _getUrl('/groww/auth/refresh');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to refresh Groww session: ${res.body}');
  }

  // Watchlist Endpoints
  Future<List<WatchlistItem>> getWatchlist({String exchange = 'NSE'}) async {
    try {
      final url = await _getUrl('/watchlist?exchange=$exchange');
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List raw = jsonDecode(res.body);
        return raw.map((item) => WatchlistItem.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<WatchlistItem> addToWatchlist(String symbol, {String exchange = 'NSE', String? notes}) async {
    final query = notes != null ? '?exchange=$exchange&notes=${Uri.encodeComponent(notes)}' : '?exchange=$exchange';
    final url = await _getUrl('/watchlist/${symbol.toUpperCase()}$query');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return WatchlistItem.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to add to watchlist: ${res.body}');
  }

  Future<bool> removeFromWatchlist(String symbol, {String exchange = 'NSE'}) async {
    try {
      final url = await _getUrl('/watchlist/${symbol.toUpperCase()}?exchange=$exchange');
      final headers = await _headers();
      final res = await http.delete(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['removed'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> checkIsWatchlisted(String symbol, {String exchange = 'NSE'}) async {
    try {
      final url = await _getUrl('/watchlist/check/${symbol.toUpperCase()}?exchange=$exchange');
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['is_watchlisted'] == true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>> scanWatchlist({String exchange = 'NSE', bool force = true}) async {
    final url = await _getUrl('/watchlist/scan?exchange=$exchange&force=$force');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 25));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to scan watchlist: ${res.body}');
  }

  // Dedicated Trading Control API methods
  Future<TradingControlSummary> getTradingControlSummary() async {
    final url = await _getUrl('/trading-control/summary');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return TradingControlSummary.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to load trading control summary (${res.statusCode})');
  }

  Future<Map<String, dynamic>> startTrading() async {
    final url = await _getUrl('/trading-control/start');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to start trading (${res.statusCode})');
  }

  Future<Map<String, dynamic>> stopTrading() async {
    final url = await _getUrl('/trading-control/stop');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to stop trading (${res.statusCode})');
  }

  Future<Map<String, dynamic>> checkPositionMonitoring() async {
    return triggerAutoSellCheck();
  }

  Future<TradingControlSummary> updateTradingControlSettings({
    double? tradingBudget,
    double? maxAmountPerTrade,
    double? dailyLossLimit,
    bool? autoWithdrawProfits,
    double? autoWithdrawThreshold,
    bool? isTradingActive,
    String? tradingMode,
    String? activeAlgorithm,
    bool? autoTakeProfit,
  }) async {
    final url = await _getUrl('/trading-control/settings');
    final headers = await _headers();
    final body = <String, dynamic>{};
    if (tradingBudget != null) body['trading_budget'] = tradingBudget;
    if (maxAmountPerTrade != null) body['max_amount_per_trade'] = maxAmountPerTrade;
    if (dailyLossLimit != null) body['daily_loss_limit'] = dailyLossLimit;
    if (autoWithdrawProfits != null) body['auto_withdraw_profits'] = autoWithdrawProfits;
    if (autoWithdrawThreshold != null) body['auto_withdraw_threshold'] = autoWithdrawThreshold;
    if (isTradingActive != null) body['is_trading_active'] = isTradingActive;
    if (tradingMode != null) body['trading_mode'] = tradingMode;
    if (activeAlgorithm != null) body['active_algorithm'] = activeAlgorithm;
    if (autoTakeProfit != null) body['auto_take_profit'] = autoTakeProfit;

    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      return TradingControlSummary.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to update trading control settings: ${res.body}');
  }

  Future<List<FundTransaction>> getFundTransactions({int limit = 50}) async {
    final url = await _getUrl('/trading-control/transactions?limit=$limit');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List raw = jsonDecode(res.body);
      return raw.map((item) => FundTransaction.fromJson(item)).toList();
    }
    return [];
  }

  Future<FundTransaction> recordFundTransaction({
    required String type,
    required double amount,
    String? note,
  }) async {
    final url = await _getUrl('/trading-control/transactions');
    final headers = await _headers();
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({
        'transaction_type': type,
        'amount': amount,
        'note': note,
      }),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      return FundTransaction.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to record fund transaction: ${res.body}');
  }

  // Trade Alert Approval Flow
  Future<List<StockAlert>> getTradeAlerts({String? status, int limit = 20}) async {
    var query = '?limit=$limit';
    if (status != null) query += '&status=${Uri.encodeComponent(status)}';
    final url = await _getUrl('/alerts/trade-alerts$query');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      final List raw = jsonDecode(res.body);
      return raw.map((item) => StockAlert.fromJson(item)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> respondToTradeAlert(
    int alertId, {
    required String action,
    double? confirmedPrice,
  }) async {
    final url = await _getUrl('/alerts/trade-alerts/$alertId/respond');
    final headers = await _headers();
    final body = <String, dynamic>{'action': action};
    if (confirmedPrice != null) body['confirmed_price'] = confirmedPrice;

    final res = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to respond to trade alert: ${res.body}');
  }

  // Groww Verification & Renewal
  Future<Map<String, dynamic>> renewGrowwSession() async {
    final url = await _getUrl('/groww/renew');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to renew Groww session: ${res.body}');
  }

  Future<Map<String, dynamic>> verifyGrowwConnection() async {
    final url = await _getUrl('/groww/verify');
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to verify Groww connection: ${res.body}');
  }

  Future<Map<String, dynamic>> switchGrowwAccount() async {
    final url = await _getUrl('/groww/switch-account');
    final headers = await _headers();
    final res = await http.post(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to switch Groww account: ${res.body}');
  }
}
