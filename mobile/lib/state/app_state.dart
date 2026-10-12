import 'package:flutter/foundation.dart';
import '../models/market_status.dart';
import '../models/stock_summary.dart';
import '../models/signal.dart';
import '../models/alert.dart';
import '../models/portfolio.dart';
import '../models/funds.dart';
import '../models/order.dart';
import '../models/watchlist.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isLoading = false;
  bool isOnline = true;
  String? errorMessage;

  MarketStatus? marketStatus;
  List<StockSummary> stocks = [];
  List<StockSignal> latestSignals = [];
  List<StockAlert> alerts = [];
  PortfolioSummary? portfolio;
  BrokerFunds? funds;
  SafetyStatus? safetyStatus;
  Map<String, dynamic>? growwStatus;

  // Watchlist state
  List<WatchlistItem> watchlistItems = [];
  Set<String> watchlistSymbols = {};
  bool isScanningWatchlist = false;

  bool isWatchlisted(String symbol) => watchlistSymbols.contains(symbol.toUpperCase());

  bool get isGrowwConnected =>
      growwStatus != null &&
      growwStatus!['is_configured'] == true &&
      growwStatus!['is_authenticated'] == true;

  bool isScanning = false;
  String? lastScanInfo;
  bool isScheduleActive = false;
  String? scheduleNextRun;
  int scheduleIntervalMinutes = 15;
  bool isTogglingSchedule = false;

  AppState() {
    refreshAll();
  }

  Future<void> refreshAll() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final healthy = await api.checkHealth();
      isOnline = healthy;
      if (!healthy) {
        errorMessage = 'Unable to reach backend. Check your LAN IP or connection settings.';
        isLoading = false;
        notifyListeners();
        return;
      }

      final results = await Future.wait([
        api.getMarketStatus().catchError((_) => MarketStatus(
              exchange: 'NSE',
              status: 'UNKNOWN',
              reason: 'Connection error',
              serverTimeIst: '',
              isOpen: false,
              marketOpenTime: '',
              marketCloseTime: '',
            )),
        api.getStockUniverse().catchError((_) => <StockSummary>[]),
        api.getLatestSignals(limit: 10).catchError((_) => <StockSignal>[]),
        api.getAlerts().catchError((_) => <StockAlert>[]),
        api.getPortfolioSummary().catchError((_) => PortfolioSummary(
              totalPortfolioValue: 0.0,
              totalInvestedValue: 0.0,
              totalUnrealizedPnl: 0.0,
              totalRealizedPnl: 0.0,
              openPositionsCount: 0,
              portfolioExposurePct: 0.0,
              positions: [],
            )),
        api.getFunds().catchError((_) => BrokerFunds(
              brokerName: 'GROWW',
              isConnected: false,
              availableFunds: 0.0,
              unsettledFunds: 0.0,
              withdrawableFunds: 0.0,
              currency: 'INR',
            )),
      ]);

      marketStatus = results[0] as MarketStatus;
      stocks = results[1] as List<StockSummary>;
      latestSignals = results[2] as List<StockSignal>;
      alerts = results[3] as List<StockAlert>;
      portfolio = results[4] as PortfolioSummary;
      funds = results[5] as BrokerFunds;

      // Fetch Safety Status & Groww Status
      try {
        safetyStatus = await api.getSafetyStatus();
        growwStatus = await api.getGrowwStatus();
      } catch (_) {}

      // Fetch Watchlist
      try {
        watchlistItems = await api.getWatchlist();
        if (watchlistItems.isNotEmpty) {
          watchlistSymbols = watchlistItems.map((w) => w.symbol.toUpperCase()).toSet();
          await StorageService.saveWatchlist(watchlistSymbols.toList());
        } else {
          final cached = await StorageService.getWatchlist();
          watchlistSymbols = cached.map((s) => s.toUpperCase()).toSet();
        }
      } catch (_) {
        final cached = await StorageService.getWatchlist();
        watchlistSymbols = cached.map((s) => s.toUpperCase()).toSet();
      }

      // Update scan and schedule status
      final scanStatus = await api.getScannerStatus();
      isScanning = scanStatus['is_scanning'] ?? false;
      if (scanStatus['latest_job'] != null) {
        final job = scanStatus['latest_job'];
        lastScanInfo = 'Job #${job['id']} (${job['status']}): ${job['scanned_stocks']} scanned, ${job['passed_signals']} signals';
      }

      try {
        final sched = await api.getScheduleStatus();
        isScheduleActive = sched['auto_scan_active'] == true;
        scheduleNextRun = sched['next_run_time'];
        scheduleIntervalMinutes = sched['interval_minutes'] ?? 15;
      } catch (_) {}
    } catch (e) {
      errorMessage = e.toString();
      isOnline = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleWatchlist(String symbol, {String exchange = 'NSE'}) async {
    final sym = symbol.toUpperCase();
    final wasPresent = watchlistSymbols.contains(sym);

    if (wasPresent) {
      watchlistSymbols.remove(sym);
      watchlistItems.removeWhere((item) => item.symbol.toUpperCase() == sym);
      notifyListeners();
      await StorageService.saveWatchlist(watchlistSymbols.toList());
      try {
        await api.removeFromWatchlist(sym, exchange: exchange);
      } catch (_) {}
    } else {
      watchlistSymbols.add(sym);
      notifyListeners();
      await StorageService.saveWatchlist(watchlistSymbols.toList());
      try {
        final added = await api.addToWatchlist(sym, exchange: exchange);
        watchlistItems.removeWhere((item) => item.symbol.toUpperCase() == sym);
        watchlistItems.insert(0, added);
        notifyListeners();
      } catch (_) {
        final existingStock = stocks.firstWhere(
          (s) => s.symbol.toUpperCase() == sym,
          orElse: () => StockSummary(
            symbol: sym,
            exchange: exchange,
            name: sym,
            isLive: false,
            latestSignal: 'NO TRADE',
            signalStrength: 0.0,
          ),
        );
        watchlistItems.removeWhere((item) => item.symbol.toUpperCase() == sym);
        watchlistItems.insert(
          0,
          WatchlistItem(
            id: DateTime.now().millisecondsSinceEpoch,
            symbol: sym,
            exchange: exchange,
            createdAt: DateTime.now(),
            stock: existingStock,
          ),
        );
        notifyListeners();
      }
    }
  }

  Future<void> scanWatchlist({String exchange = 'NSE'}) async {
    try {
      isScanningWatchlist = true;
      notifyListeners();
      await api.scanWatchlist(exchange: exchange, force: true);
      await Future.delayed(const Duration(seconds: 2));
      await refreshAll();
    } catch (e) {
      errorMessage = 'Watchlist scan error: $e';
    } finally {
      isScanningWatchlist = false;
      notifyListeners();
    }
  }

  Future<void> toggleEmergencyStop(bool enable) async {
    try {
      await api.toggleEmergencyStop(enable);
      safetyStatus = await api.getSafetyStatus();
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to toggle emergency stop: $e';
      notifyListeners();
    }
  }

  Future<void> updateSafetySettings({
    bool? autoSellEnabled,
    double? maxPositionRiskPct,
    double? maxSingleStockPct,
    double? maxPortfolioExposurePct,
  }) async {
    try {
      safetyStatus = await api.updateSafetySettings(
        autoSellEnabled: autoSellEnabled,
        maxPositionRiskPct: maxPositionRiskPct,
        maxSingleStockPct: maxSingleStockPct,
        maxPortfolioExposurePct: maxPortfolioExposurePct,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to update safety settings: $e';
      notifyListeners();
    }
  }

  Future<void> updatePositionMonitoring(
    int positionId, {
    double? stopLoss,
    double? target,
    int? holdingPeriodHours,
    bool? autoSellEnabled,
  }) async {
    try {
      await api.updatePositionMonitoring(
        positionId,
        stopLoss: stopLoss,
        target: target,
        holdingPeriodHours: holdingPeriodHours,
        autoSellEnabled: autoSellEnabled,
      );
      portfolio = await api.getPortfolioSummary();
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to update position monitoring: $e';
      notifyListeners();
    }
  }

  Future<void> checkPositionMonitoring() async {
    try {
      await api.triggerPositionMonitorCheck();
      portfolio = await api.getPortfolioSummary();
      notifyListeners();
    } catch (e) {
      errorMessage = 'Position monitor check failed: $e';
      notifyListeners();
    }
  }

  Future<void> triggerScan() async {
    try {
      isScanning = true;
      notifyListeners();
      await api.triggerScan(force: true);
      await Future.delayed(const Duration(seconds: 2));
      await refreshAll();
    } catch (e) {
      errorMessage = 'Failed to trigger scan: $e';
    } finally {
      isScanning = false;
      notifyListeners();
    }
  }

  Future<void> startScheduleAnalysis({int intervalMinutes = 15}) async {
    try {
      isTogglingSchedule = true;
      notifyListeners();
      final res = await api.startSchedule(intervalMinutes: intervalMinutes);
      isScheduleActive = true;
      scheduleNextRun = res['next_run_time'];
      scheduleIntervalMinutes = intervalMinutes;
    } catch (e) {
      errorMessage = 'Failed to start scheduled analysis: $e';
    } finally {
      isTogglingSchedule = false;
      notifyListeners();
    }
  }

  Future<void> stopScheduleAnalysis() async {
    try {
      isTogglingSchedule = true;
      notifyListeners();
      await api.stopSchedule();
      isScheduleActive = false;
      scheduleNextRun = null;
    } catch (e) {
      errorMessage = 'Failed to stop scheduled analysis: $e';
    } finally {
      isTogglingSchedule = false;
      notifyListeners();
    }
  }

  Future<void> markAlertRead(int id) async {
    try {
      await api.markAlertsRead([id]);
      final idx = alerts.indexWhere((a) => a.id == id);
      if (idx != -1) {
        alerts[idx].isRead = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> syncBrokerFunds() async {
    try {
      funds = await api.syncFunds();
      notifyListeners();
    } catch (e) {
      errorMessage = 'Funds sync error: $e';
      notifyListeners();
    }
  }

  Future<bool> executePaperTrade({
    required String symbol,
    required String action,
    required int quantity,
    double? price,
  }) async {
    try {
      final success = await api.executePaperTrade(
        symbol: symbol,
        action: action,
        quantity: quantity,
        price: price,
      );
      if (success) {
        portfolio = await api.getPortfolioSummary();
        notifyListeners();
      }
      return success;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginGroww({
    String? apiKey,
    String? apiSecret,
    String? totpKey,
    String? authToken,
    bool orderExecutionEnabled = false,
  }) async {
    try {
      final res = await api.loginGroww(
        apiKey: apiKey,
        apiSecret: apiSecret,
        totpKey: totpKey,
        authToken: authToken,
        orderExecutionEnabled: orderExecutionEnabled,
      );
      growwStatus = await api.getGrowwStatus();
      funds = await api.getFunds();
      safetyStatus = await api.getSafetyStatus();
      notifyListeners();
      return res['success'] == true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logoutGroww() async {
    try {
      await api.logoutGroww();
      growwStatus = await api.getGrowwStatus();
      funds = await api.getFunds();
      safetyStatus = await api.getSafetyStatus();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshGrowwStatus() async {
    try {
      growwStatus = await api.getGrowwStatus();
      funds = await api.getFunds();
      notifyListeners();
    } catch (_) {}
  }
}
