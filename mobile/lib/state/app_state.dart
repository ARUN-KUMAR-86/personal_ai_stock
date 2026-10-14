import 'package:flutter/foundation.dart';
import '../models/market_status.dart';
import '../models/stock_summary.dart';
import '../models/signal.dart';
import '../models/alert.dart';
import '../models/portfolio.dart';
import '../models/funds.dart';
import '../models/order.dart';
import '../models/watchlist.dart';
import '../models/trading_control.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isLoading = false;
  bool isOnline = true;
  bool isWakingUpServer = false;
  String? errorMessage;
  String? lastAutoSellMessage;

  MarketStatus? marketStatus;
  List<StockSummary> stocks = [];
  List<StockSignal> latestSignals = [];
  List<StockAlert> alerts = [];
  List<StockAlert> tradeAlerts = [];
  PortfolioSummary? portfolio;
  List<PaperTrade> paperTrades = [];
  BrokerFunds? funds;
  SafetyStatus? safetyStatus;
  Map<String, dynamic>? growwStatus;
  TradingControlSummary? tradingControl;
  List<FundTransaction> fundTransactions = [];

  String activeAlgorithm = 'Highest Profit Maximizer (Auto Take Money)';
  bool autoTakeProfit = true;

  // Watchlist state
  List<WatchlistItem> watchlistItems = [];
  Set<String> watchlistSymbols = {};
  bool isScanningWatchlist = false;

  bool isWatchlisted(String symbol) => watchlistSymbols.contains(symbol.toUpperCase());

  bool get isGrowwConnected =>
      growwStatus != null &&
      growwStatus!['is_configured'] == true &&
      growwStatus!['is_authenticated'] == true;

  List<StockAlert> get pendingTradeAlerts =>
      tradeAlerts.where((a) => a.isPendingApproval).toList();

  bool isScanning = false;
  String? lastScanInfo;
  bool isScheduleActive = false;
  String? scheduleNextRun;
  int scheduleIntervalMinutes = 15;
  bool isTogglingSchedule = false;
  bool isTradingToggling = false;

  AppState() {
    _initData();
  }

  Future<void> _initData() async {
    // 1. Immediately load cached paper trades & portfolio from device storage
    // This ensures trades are NEVER blank or lost when app is closed / reopened!
    await _loadCachedData();
    // 2. Refresh live data from backend
    await refreshAll();
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedPf = await StorageService.getCachedPortfolio();
      if (cachedPf != null) {
        portfolio = cachedPf;
      }
      paperTrades = await StorageService.getCachedPaperTrades();
      activeAlgorithm = await StorageService.getActiveAlgorithm();
      autoTakeProfit = await StorageService.getAutoTakeProfit();
      final cachedWatch = await StorageService.getWatchlist();
      watchlistSymbols = cachedWatch.map((s) => s.toUpperCase()).toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> refreshAll() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final healthy = await api.checkHealth();
      isOnline = healthy;
      if (!healthy) {
        // Do NOT abort or clear existing trades! Keep local simulation positions fully visible.
        errorMessage = 'Connecting to backend... Running in offline simulation mode with your saved trades.';
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
        api.getLatestSignals(limit: 15).catchError((_) => <StockSignal>[]),
        api.getAlerts().catchError((_) => <StockAlert>[]),
        api.getPortfolioSummary().catchError((_) => portfolio ?? PortfolioSummary(
              totalPortfolioValue: 1000.0,
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
              availableFunds: 1000.0,
              unsettledFunds: 0.0,
              withdrawableFunds: 1000.0,
              currency: 'INR',
            )),
      ]);

      marketStatus = results[0] as MarketStatus;
      stocks = results[1] as List<StockSummary>;
      latestSignals = results[2] as List<StockSignal>;
      alerts = results[3] as List<StockAlert>;
      
      final fetchedPortfolio = results[4] as PortfolioSummary;
      if (fetchedPortfolio.positions.isNotEmpty || (portfolio == null || portfolio!.positions.isEmpty)) {
        portfolio = fetchedPortfolio;
        await StorageService.saveCachedPortfolio(portfolio!);
      }
      funds = results[5] as BrokerFunds;

      // Fetch Safety Status & Groww Status
      try {
        safetyStatus = await api.getSafetyStatus();
        growwStatus = await api.getGrowwStatus();
      } catch (_) {}

      // Fetch Server Paper Trades and sync with local
      try {
        final serverTrades = await api.getPaperTrades(limit: 50);
        if (serverTrades.isNotEmpty) {
          paperTrades = serverTrades;
          await StorageService.saveCachedPaperTrades(paperTrades);
        } else if (paperTrades.isNotEmpty) {
          // Sync local paper trades up to server so server has them
          await api.syncPaperTrades(paperTrades);
        }
      } catch (_) {}

      // Fetch Watchlist
      try {
        watchlistItems = await api.getWatchlist();
        if (watchlistItems.isNotEmpty) {
          watchlistSymbols = watchlistItems.map((w) => w.symbol.toUpperCase()).toSet();
          await StorageService.saveWatchlist(watchlistSymbols.toList());
        }
      } catch (_) {}

      // Update scan and schedule status
      try {
        final scanStatus = await api.getScannerStatus();
        isScanning = scanStatus['is_scanning'] ?? false;
        if (scanStatus['latest_job'] != null) {
          final job = scanStatus['latest_job'];
          lastScanInfo = 'Job #${job['id']} (${job['status']}): ${job['scanned_stocks']} scanned, ${job['passed_signals']} signals';
        }
        final sched = await api.getScheduleStatus();
        isScheduleActive = sched['auto_scan_active'] ?? false;
        scheduleNextRun = sched['next_run_time'];
        scheduleIntervalMinutes = sched['interval_minutes'] ?? 15;
      } catch (_) {}

      // Fetch Dedicated Trading Controls summary
      await refreshTradingControl();

      // Check auto-selling on open positions!
      await checkAndExecuteAutoSell();

    } catch (e) {
      debugPrint('refreshAll error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Automatically evaluates positions against target profit ("Take Money") & stop-loss
  Future<void> checkAndExecuteAutoSell() async {
    if (portfolio == null || portfolio!.positions.isEmpty) return;

    // 1. If backend online, trigger server PositionMonitor
    if (isOnline) {
      try {
        final res = await api.triggerAutoSellCheck();
        final actions = res['actions_taken'] as List?;
        if (actions != null && actions.isNotEmpty) {
          debugPrint('Server executed auto-sell actions: $actions');
          final updated = await api.getPortfolioSummary();
          portfolio = updated;
          await StorageService.saveCachedPortfolio(portfolio!);
          notifyListeners();
          return;
        }
      } catch (_) {}
    }

    // 2. Client-Side Simulation Auto-Sell Check:
    // If any open paper position has hit target ("Take Money") or stop-loss, execute auto-sell!
    final positionsCopy = List<Position>.from(portfolio!.positions);
    for (final pos in positionsCopy) {
      if (!pos.isOpen) continue;
      final price = pos.currentPrice;
      bool shouldAutoSell = false;
      String reason = '';

      if (pos.target != null && price >= pos.target! && (pos.autoSellEnabled || autoTakeProfit)) {
        shouldAutoSell = true;
        reason = 'AUTO TAKE PROFIT: Target ₹${pos.target!.toStringAsFixed(2)} reached';
      } else if (pos.stopLoss != null && price <= pos.stopLoss! && pos.autoSellEnabled) {
        shouldAutoSell = true;
        reason = 'AUTO STOP-LOSS: Stop-loss ₹${pos.stopLoss!.toStringAsFixed(2)} hit';
      }

      if (shouldAutoSell) {
        debugPrint('Auto-selling position for ${pos.symbol}: $reason');
        lastAutoSellMessage = '💰 $reason for ${pos.symbol}! Automatically taking profit and crediting funds.';
        await executePaperTrade(
          symbol: pos.symbol,
          action: 'SELL',
          quantity: pos.quantity,
          price: price,
        );
      }
    }
  }

  Future<void> refreshGrowwStatus() async {
    try {
      growwStatus = await api.getGrowwStatus();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshTradingControl() async {
    try {
      tradingControl = await api.getTradingControlSummary();
      tradeAlerts = await api.getTradeAlerts();
      fundTransactions = await api.getFundTransactions();
      if (tradingControl?.activeAlgorithm != null) {
        activeAlgorithm = tradingControl!.activeAlgorithm;
        await StorageService.setActiveAlgorithm(activeAlgorithm);
      }
      autoTakeProfit = tradingControl?.autoTakeProfit ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> startTrading() async {
    try {
      isTradingToggling = true;
      notifyListeners();
      await api.startTrading();
      await refreshTradingControl();
      await refreshAll();
    } catch (e) {
      errorMessage = 'Failed to start trading: $e';
    } finally {
      isTradingToggling = false;
      notifyListeners();
    }
  }

  Future<void> stopTrading() async {
    try {
      isTradingToggling = true;
      notifyListeners();
      await api.stopTrading();
      await refreshTradingControl();
      await refreshAll();
    } catch (e) {
      errorMessage = 'Failed to stop trading: $e';
    } finally {
      isTradingToggling = false;
      notifyListeners();
    }
  }

  Future<void> updateTradingBudget(double amount) async {
    try {
      tradingControl = await api.updateTradingControlSettings(tradingBudget: amount);
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to update trading budget: $e';
      notifyListeners();
    }
  }

  Future<void> updateTradingSettings({
    double? tradingBudget,
    double? maxAmountPerTrade,
    double? dailyLossLimit,
    bool? autoWithdrawProfits,
    double? autoWithdrawThreshold,
    String? tradingMode,
    String? activeAlgorithm,
    bool? autoTakeProfit,
  }) async {
    try {
      if (activeAlgorithm != null) {
        this.activeAlgorithm = activeAlgorithm;
        await StorageService.setActiveAlgorithm(activeAlgorithm);
      }
      if (autoTakeProfit != null) {
        this.autoTakeProfit = autoTakeProfit;
        await StorageService.setAutoTakeProfit(autoTakeProfit);
      }
      tradingControl = await api.updateTradingControlSettings(
        tradingBudget: tradingBudget,
        maxAmountPerTrade: maxAmountPerTrade,
        dailyLossLimit: dailyLossLimit,
        autoWithdrawProfits: autoWithdrawProfits,
        autoWithdrawThreshold: autoWithdrawThreshold,
        tradingMode: tradingMode,
        activeAlgorithm: activeAlgorithm,
        autoTakeProfit: autoTakeProfit,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to update settings: $e';
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

  Future<void> scanWatchlist() async {
    if (watchlistSymbols.isEmpty) return;
    try {
      isScanningWatchlist = true;
      notifyListeners();
      await api.scanWatchlist();
      await refreshAll();
    } catch (e) {
      errorMessage = 'Watchlist scan error: $e';
    } finally {
      isScanningWatchlist = false;
      notifyListeners();
    }
  }

  Future<void> toggleWatchlist(String symbol, {String exchange = 'NSE'}) async {
    final upper = symbol.toUpperCase();
    final wasWatched = watchlistSymbols.contains(upper);

    if (wasWatched) {
      watchlistSymbols.remove(upper);
      watchlistItems.removeWhere((item) => item.symbol.toUpperCase() == upper);
    } else {
      watchlistSymbols.add(upper);
    }
    notifyListeners();

    await StorageService.saveWatchlist(watchlistSymbols.toList());

    try {
      if (wasWatched) {
        await api.removeFromWatchlist(upper, exchange: exchange);
      } else {
        await api.addToWatchlist(upper, exchange: exchange);
      }
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────
  // Robust Simulation Trade Execution with Local Offline Cache
  // ────────────────────────────────────────────────────────────

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
    final cleanAction = action.toUpperCase().trim();
    final effectivePrice = price ?? 100.0;
    final totalAmount = effectivePrice * quantity;

    // 1. Create a local PaperTrade record immediately
    final localTrade = PaperTrade(
      id: DateTime.now().millisecondsSinceEpoch,
      symbol: symbol.toUpperCase(),
      exchange: 'NSE',
      action: cleanAction,
      quantity: quantity,
      price: effectivePrice,
      fees: (totalAmount * 0.001).clamp(2.0, 40.0),
      totalAmount: totalAmount,
      pnl: 0.0,
      reason: 'Simulation Trade (${autoSellEnabled ? "Auto Take Money Active" : "Manual"})',
      timestamp: DateTime.now(),
    );
    await StorageService.addLocalPaperTrade(localTrade);
    paperTrades.insert(0, localTrade);

    // 2. Update local positions immediately so closing/reopening never loses trades
    final existingPosIdx = portfolio?.positions.indexWhere(
      (p) => p.symbol.toUpperCase() == symbol.toUpperCase() && p.isOpen,
    ) ?? -1;

    List<Position> updatedPositions = List.from(portfolio?.positions ?? []);
    if (cleanAction == 'BUY') {
      if (existingPosIdx >= 0) {
        final cur = updatedPositions[existingPosIdx];
        final newQty = cur.quantity + quantity;
        final newAvg = ((cur.avgEntryPrice * cur.quantity) + totalAmount) / newQty;
        updatedPositions[existingPosIdx] = Position(
          id: cur.id,
          symbol: cur.symbol,
          exchange: cur.exchange,
          quantity: newQty,
          avgEntryPrice: newAvg,
          currentPrice: effectivePrice,
          stopLoss: stopLoss ?? cur.stopLoss,
          target: target ?? cur.target,
          unrealizedPnl: (effectivePrice - newAvg) * newQty,
          realizedPnl: cur.realizedPnl,
          fees: cur.fees + localTrade.fees,
          isOpen: true,
          holdingPeriodHours: holdingPeriodHours,
          autoSellEnabled: autoSellEnabled,
          mode: 'PAPER',
        );
      } else {
        updatedPositions.insert(0, Position(
          id: DateTime.now().millisecondsSinceEpoch,
          symbol: symbol.toUpperCase(),
          exchange: 'NSE',
          quantity: quantity,
          avgEntryPrice: effectivePrice,
          currentPrice: effectivePrice,
          stopLoss: stopLoss,
          target: target,
          unrealizedPnl: 0.0,
          realizedPnl: 0.0,
          fees: localTrade.fees,
          isOpen: true,
          holdingPeriodHours: holdingPeriodHours,
          autoSellEnabled: autoSellEnabled,
          mode: 'PAPER',
        ));
      }
    } else if (cleanAction == 'SELL' && existingPosIdx >= 0) {
      final cur = updatedPositions[existingPosIdx];
      if (cur.quantity <= quantity) {
        updatedPositions.removeAt(existingPosIdx);
      } else {
        final newQty = cur.quantity - quantity;
        updatedPositions[existingPosIdx] = Position(
          id: cur.id,
          symbol: cur.symbol,
          exchange: cur.exchange,
          quantity: newQty,
          avgEntryPrice: cur.avgEntryPrice,
          currentPrice: effectivePrice,
          stopLoss: cur.stopLoss,
          target: cur.target,
          unrealizedPnl: (effectivePrice - cur.avgEntryPrice) * newQty,
          realizedPnl: cur.realizedPnl + ((effectivePrice - cur.avgEntryPrice) * quantity),
          fees: cur.fees + localTrade.fees,
          isOpen: true,
          holdingPeriodHours: cur.holdingPeriodHours,
          autoSellEnabled: cur.autoSellEnabled,
          mode: 'PAPER',
        );
      }
    }

    final totalInv = updatedPositions.fold(0.0, (acc, p) => acc + (p.avgEntryPrice * p.quantity));
    final totalUnreal = updatedPositions.fold(0.0, (acc, p) => acc + p.unrealizedPnl);
    portfolio = PortfolioSummary(
      totalPortfolioValue: 1000.0 + totalUnreal,
      totalInvestedValue: totalInv,
      totalUnrealizedPnl: totalUnreal,
      totalRealizedPnl: portfolio?.totalRealizedPnl ?? 0.0,
      openPositionsCount: updatedPositions.length,
      portfolioExposurePct: totalInv > 0 ? (totalInv / 1000.0) * 100 : 0.0,
      positions: updatedPositions,
    );
    await StorageService.saveCachedPortfolio(portfolio!);
    notifyListeners();

    // 3. Sync with backend if available
    try {
      final success = await api.executePaperTrade(
        symbol: symbol,
        action: cleanAction,
        quantity: quantity,
        price: effectivePrice,
        stopLoss: stopLoss,
        target: target,
        holdingPeriodHours: holdingPeriodHours,
        autoSellEnabled: autoSellEnabled,
      );
      if (success) {
        try {
          final serverPf = await api.getPortfolioSummary();
          portfolio = serverPf;
          await StorageService.saveCachedPortfolio(portfolio!);
        } catch (_) {}
      }
    } catch (_) {}

    notifyListeners();
    return true;
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
      if (portfolio != null) {
        await StorageService.saveCachedPortfolio(portfolio!);
      }
      notifyListeners();
    } catch (e) {
      errorMessage = 'Failed to update position: $e';
      notifyListeners();
    }
  }

  Future<void> checkPositionMonitoring() async {
    try {
      await api.checkPositionMonitoring();
      await checkAndExecuteAutoSell();
      portfolio = await api.getPortfolioSummary();
      if (portfolio != null) {
        await StorageService.saveCachedPortfolio(portfolio!);
      }
      notifyListeners();
    } catch (e) {
      errorMessage = 'Position check note: $e';
      notifyListeners();
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
      await refreshGrowwStatus();
      await refreshTradingControl();
      return res['is_authenticated'] == true;
    } catch (e) {
      errorMessage = 'Groww login error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> respondToTradeAlert(int alertId, String action, {double? confirmedPrice}) async {
    try {
      final res = await api.respondToTradeAlert(alertId, action: action, confirmedPrice: confirmedPrice);
      await refreshTradingControl();
      await refreshAll();
      return res['success'] == true;
    } catch (e) {
      errorMessage = 'Trade alert response error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> recordFundTransaction(String type, double amount, {String? note}) async {
    try {
      await api.recordFundTransaction(type: type, amount: amount, note: note);
      await refreshTradingControl();
      return true;
    } catch (e) {
      errorMessage = 'Transaction error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> renewGrowwSession() async {
    try {
      final res = await api.renewGrowwSession();
      await refreshGrowwStatus();
      await refreshTradingControl();
      return res['success'] == true;
    } catch (e) {
      errorMessage = 'Session renewal failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnectGroww() async {
    try {
      await api.switchGrowwAccount();
      await refreshGrowwStatus();
      await refreshTradingControl();
    } catch (e) {
      errorMessage = 'Disconnect failed: $e';
      notifyListeners();
    }
  }

  void clearAutoSellMessage() {
    lastAutoSellMessage = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> triggerAutoSellCheck() async {
    try {
      final res = await api.triggerAutoSellCheck();
      await checkAndExecuteAutoSell();
      return res;
    } catch (e) {
      await checkAndExecuteAutoSell();
      return {'message': 'Local check completed: $e'};
    }
  }

  Future<void> setActiveAlgorithm(String algo) async {
    activeAlgorithm = algo;
    await StorageService.setActiveAlgorithm(algo);
    try {
      await updateTradingSettings(activeAlgorithm: algo);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setAutoTakeProfit(bool val) async {
    autoTakeProfit = val;
    await StorageService.setAutoTakeProfit(val);
    try {
      await updateTradingSettings(autoTakeProfit: val);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> startScheduleAnalysis({int? intervalMinutes}) async {
    try {
      isTogglingSchedule = true;
      notifyListeners();
      await api.startSchedule(intervalMinutes: intervalMinutes ?? scheduleIntervalMinutes);
      isScheduleActive = true;
      await refreshAll();
    } catch (e) {
      errorMessage = 'Failed to start analysis schedule: $e';
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
      await refreshAll();
    } catch (e) {
      errorMessage = 'Failed to stop analysis schedule: $e';
    } finally {
      isTogglingSchedule = false;
      notifyListeners();
    }
  }

  Future<void> syncBrokerFunds() async {
    try {
      funds = await api.syncFunds();
      await refreshTradingControl();
      notifyListeners();
    } catch (e) {
      errorMessage = 'Funds sync error: $e';
      notifyListeners();
    }
  }

  Future<void> markAlertRead(int alertId) async {
    try {
      await api.markAlertsRead([alertId]);
      for (final a in alerts) {
        if (a.id == alertId) a.isRead = true;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleEmergencyStop(bool enabled) async {
    try {
      await api.toggleEmergencyStop(enabled);
      safetyStatus = await api.getSafetyStatus();
      notifyListeners();
    } catch (e) {
      errorMessage = 'Emergency stop toggle failed: $e';
      notifyListeners();
    }
  }

  Future<void> updateSafetySettings({
    bool? emergencyStopEnabled,
    bool? autoSellEnabled,
    double? maxPositionRiskPct,
    double? maxSingleStockPct,
    double? maxPortfolioExposurePct,
  }) async {
    try {
      safetyStatus = await api.updateSafetySettings(
        emergencyStopEnabled: emergencyStopEnabled,
        autoSellEnabled: autoSellEnabled,
        maxPositionRiskPct: maxPositionRiskPct,
        maxSingleStockPct: maxSingleStockPct,
        maxPortfolioExposurePct: maxPortfolioExposurePct,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = 'Safety settings update failed: $e';
      notifyListeners();
    }
  }

  Future<void> logoutGroww() async {
    await disconnectGroww();
  }
}
