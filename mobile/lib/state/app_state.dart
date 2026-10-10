import 'package:flutter/foundation.dart';
import '../models/market_status.dart';
import '../models/stock_summary.dart';
import '../models/signal.dart';
import '../models/alert.dart';
import '../models/portfolio.dart';
import '../models/funds.dart';
import '../services/api_service.dart';

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

  bool isScanning = false;
  String? lastScanInfo;

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

      // Update scan status
      final scanStatus = await api.getScannerStatus();
      isScanning = scanStatus['is_scanning'] ?? false;
      if (scanStatus['latest_job'] != null) {
        final job = scanStatus['latest_job'];
        lastScanInfo = 'Job #${job['id']} (${job['status']}): ${job['scanned_stocks']} scanned, ${job['passed_signals']} signals';
      }
    } catch (e) {
      errorMessage = e.toString();
      isOnline = false;
    } finally {
      isLoading = false;
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
}
