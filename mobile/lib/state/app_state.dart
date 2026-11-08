import 'dart:async';
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
import '../models/prediction.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isLoading = false;
  bool isOnline = true;
  bool isWakingUpServer = false;
  String? errorMessage;
  String? lastAutoSellMessage;

  // UltraSync & Low Latency Engine
  bool isUltraSyncActive = true;
  int syncLatencyMs = 0;
  DateTime? lastUltraSyncTime;
  Timer? _ultraSyncTimer;
  bool _isUltraSyncing = false;

  // Background Auto-Reconnect Engine
  Timer? _reconnectTimer;
  bool _isAutoReconnecting = false;

  MarketStatus? marketStatus;
  List<StockSummary> stocks = [];
  List<StockSignal> latestSignals = [];
  List<StockAlert> alerts = [];
  List<StockAlert> tradeAlerts = [];
  final Set<int> _seenAlertIds = {};
  bool _hasInitialAlertsLoaded = false;
  PortfolioSummary? portfolio;
  List<PaperTrade> paperTrades = [];
  BrokerFunds? funds;
  SafetyStatus? safetyStatus;
  Map<String, dynamic>? growwStatus;
  TradingControlSummary? tradingControl;
  List<FundTransaction> fundTransactions = [];

  String activeAlgorithm = 'Highest Profit Maximizer (Auto Take Money)';
  bool autoTakeProfit = true;
  bool isDarkMode = false; // Default: White & Blue theme
  bool onlySellAlerts = true; // User preference: Strictly SELL alerts only for marked/bought stocks
  final Map<String, Set<String>> _clientTriggeredMilestones = {};

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

  // Real-Time Gemini AI Predictions & Live Market Feed
  List<StockPrediction> topPredictions = [];
  Map<String, dynamic> liveQuotes = {};
  bool isPredicting = false;
  String? lastPredictedSymbol;

  // ── Dual-Market Architecture (Indian & US Stock Markets) ──────
  String activeMarket = 'INDIA'; // 'INDIA' or 'US'
  Map<String, dynamic>? marketOverview;
  bool isLoadingMarketOverview = false;
  String selectedScannerHorizon = '1-DAY';

  Future<void> fetchUniverseForHorizon(String horizon) async {
    selectedScannerHorizon = horizon;
    try {
      final updated = await api.getStockUniverse(
        exchange: activeExchangeDefault,
        timeHorizon: horizon,
      );
      if (updated.isNotEmpty) {
        stocks = updated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching horizon universe: $e');
    }
  }
  List<Map<String, dynamic>> trendingStocks = [];
  List<Map<String, dynamic>> topGainers = [];
  List<Map<String, dynamic>> topLosers = [];
  List<Map<String, dynamic>> marketIndices = [];
  List<String> recentAnalyzedStocks = [];

  bool get isIndianMarket => activeMarket == 'INDIA';
  bool get isUSMarket => activeMarket == 'US';
  String get activeCurrency => isUSMarket ? 'USD' : 'INR';
  String get activeCurrencySymbol => isUSMarket ? '\$' : '₹';
  String get activeExchangeDefault => isUSMarket ? 'US' : 'NSE';

  // Live Monitoring Engine
  List<Map<String, dynamic>> liveFeed = [];
  Map<String, dynamic>? liveMonitoringStatus;
  bool isLiveMonitoringActive = true;
  bool isQuickScanning = false;
  DateTime? lastLiveFeedUpdate;
  int _syncCycleCounter = 0;

  AppState() {
    _initData();
  }

  Future<void> _initData() async {
    // 1. Immediately load cached paper trades & portfolio from device storage
    // This ensures trades are NEVER blank or lost when app is closed / reopened!
    await _loadCachedData();
    // 2. Fetch market overview for selected market (India or US)
    await fetchMarketOverview(silent: true);
    // 3. Refresh live data from backend for active market
    await refreshAll();
    // 4. Fetch initial live monitoring feed for active market
    await fetchLiveFeed(exchange: activeExchangeDefault);
    // 5. Start ultra-low latency continuous live sync loop (every 3s)
    startUltraSyncLoop();
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
      isDarkMode = await StorageService.getIsDarkMode();
      onlySellAlerts = await StorageService.getOnlySellAlerts();
      activeMarket = await StorageService.getActiveMarket();
      recentAnalyzedStocks = await StorageService.getRecentlyAnalyzed(activeMarket);
      final cachedWatch = await StorageService.getWatchlist();
      watchlistSymbols = cachedWatch.map((s) => s.toUpperCase()).toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> selectMarket(String market) async {
    final clean = market.toUpperCase().trim();
    if (activeMarket == clean) return;
    activeMarket = clean;
    await StorageService.setActiveMarket(clean);
    recentAnalyzedStocks = await StorageService.getRecentlyAnalyzed(clean);
    
    // Clear old market data so items from another market never linger
    stocks = [];
    liveFeed = [];
    trendingStocks = [];
    topGainers = [];
    topLosers = [];
    marketIndices = [];
    notifyListeners();

    // Fetch market-specific overview, live feed & stock universe
    await fetchMarketOverview();
    await fetchLiveFeed(exchange: activeExchangeDefault);
    await refreshAll();
  }

  Future<void> fetchMarketOverview({bool silent = false}) async {
    if (!silent) {
      isLoadingMarketOverview = true;
      notifyListeners();
    }
    try {
      final overview = await api.getMarketOverview(activeMarket);
      if (overview.isNotEmpty) {
        marketOverview = overview;
        final rawTrending = overview['trending'] ?? overview['trending_stocks'];
        if (rawTrending is List) {
          trendingStocks = List<Map<String, dynamic>>.from(rawTrending);
        }
        final rawGainers = overview['gainers'] ?? overview['top_gainers'];
        if (rawGainers is List) {
          topGainers = List<Map<String, dynamic>>.from(rawGainers);
        }
        final rawLosers = overview['losers'] ?? overview['top_losers'];
        if (rawLosers is List) {
          topLosers = List<Map<String, dynamic>>.from(rawLosers);
        }
        if (overview['indices'] is List) {
          marketIndices = List<Map<String, dynamic>>.from(overview['indices']);
        }
      }
    } catch (e) {
      debugPrint('fetchMarketOverview error: $e');
    } finally {
      isLoadingMarketOverview = false;
      notifyListeners();
    }
  }

  Future<void> addRecentlyAnalyzed(String symbol) async {
    final sym = symbol.toUpperCase().trim();
    await StorageService.addRecentlyAnalyzed(sym, activeMarket);
    recentAnalyzedStocks.remove(sym);
    recentAnalyzedStocks.insert(0, sym);
    if (recentAnalyzedStocks.length > 15) {
      recentAnalyzedStocks.removeRange(15, recentAnalyzedStocks.length);
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> getCompleteStockAnalysis(
    String symbol, {
    String? market,
    String? exchange,
    String timeHorizon = '1-DAY',
  }) async {
    final m = (market ?? activeMarket).toUpperCase();
    final ex = exchange ?? (m == 'US' ? 'US' : 'NSE');
    await addRecentlyAnalyzed(symbol);
    return await api.getCompleteStockAnalysis(symbol, market: m, exchange: ex, timeHorizon: timeHorizon);
  }

  Future<void> setOnlySellAlerts(bool enabled) async {
    onlySellAlerts = enabled;
    await StorageService.setOnlySellAlerts(enabled);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool enabled) async {
    isDarkMode = enabled;
    await StorageService.setIsDarkMode(enabled);
    notifyListeners();
  }

  void _scheduleAutoReconnect() {
    if (_isAutoReconnecting) return;
    _isAutoReconnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      final healthy = await api.checkHealth();
      if (healthy) {
        timer.cancel();
        _reconnectTimer = null;
        _isAutoReconnecting = false;
        isOnline = true;
        errorMessage = null;
        debugPrint('[Auto-Reconnect] Cloud server is online! Automatically loading market data...');
        await refreshAll(silent: true);
        await fetchLiveFeed(silent: true);
        notifyListeners();
      }
    });
  }

  Future<void> refreshAll({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      final healthy = await api.checkHealth();
      isOnline = healthy;
      if (!healthy) {
        // Automatically start background reconnection attempts so user never needs to manually click!
        errorMessage = 'Cloud server waking up... Auto-connecting in background.';
        isLoading = false;
        notifyListeners();
        _scheduleAutoReconnect();
        return;
      } else {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _isAutoReconnecting = false;
      }

      final results = await Future.wait([
        api.getMarketStatus(exchange: activeExchangeDefault).catchError((_) => MarketStatus(
              exchange: activeExchangeDefault,
              status: 'UNKNOWN',
              reason: 'Connection error',
              serverTimeIst: '',
              isOpen: false,
              marketOpenTime: '',
              marketCloseTime: '',
            )),
        api.getStockUniverse(exchange: activeExchangeDefault, timeHorizon: selectedScannerHorizon).catchError((_) => <StockSummary>[]),
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
      final fetchedAlerts = results[3] as List<StockAlert>;
      if (_hasInitialAlertsLoaded) {
        for (final alert in fetchedAlerts) {
          if (!_seenAlertIds.contains(alert.id)) {
            _seenAlertIds.add(alert.id);
            if (!alert.isRead) {
              final isSell = alert.action.toUpperCase() == 'SELL' ||
                  alert.title.toUpperCase().contains('SELL') ||
                  alert.message.toUpperCase().contains('SELL');
              if (onlySellAlerts && !isSell) {
                // Strictly SELL alerts only; suppress general BUY signal alerts
                continue;
              }
              NotificationService().showNotification(
                id: alert.id,
                title: alert.title,
                body: alert.message,
                data: {
                  'symbol': alert.symbol,
                  'exchange': alert.exchange,
                  'action': alert.action,
                },
                isCritical: isSell,
              );
            }
          }
        }
      } else {
        _hasInitialAlertsLoaded = true;
        _seenAlertIds.addAll(fetchedAlerts.map((a) => a.id));
      }
      alerts = fetchedAlerts;
      
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

      // Fetch Gemini AI Top Predictions & Live Quotes
      try {
        topPredictions = await api.getTopPredictions(limit: 12);
        final quotes = await api.getLiveQuotes();
        if (quotes.isNotEmpty) liveQuotes = quotes;
      } catch (_) {}

      // Check auto-selling on open positions!
      await checkAndExecuteAutoSell();

    } catch (e) {
      debugPrint('refreshAll error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Starts the ultra-low latency continuous live synchronization loop (every 3 seconds)
  void startUltraSyncLoop() {
    _ultraSyncTimer?.cancel();
    isUltraSyncActive = true;
    _ultraSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      executeUltraSync(silent: true);
    });
  }

  void stopUltraSyncLoop() {
    isUltraSyncActive = false;
    _ultraSyncTimer?.cancel();
    _ultraSyncTimer = null;
    notifyListeners();
  }

  /// Executes an ultra-low latency sync pass (< 50ms) consolidating portfolio, live PnL, trades, and funds
  Future<void> executeUltraSync({bool silent = true}) async {
    if (_isUltraSyncing) return;
    _isUltraSyncing = true;
    if (!silent) {
      notifyListeners();
    }

    try {
      final syncData = await api.ultraSync(runAutoSell: true);
      if (syncData != null) {
        syncLatencyMs = syncData.clientRoundtripMs;
        lastUltraSyncTime = DateTime.now();
        final wasOffline = !isOnline;
        isOnline = true;
        errorMessage = null;

        if (wasOffline || stocks.isEmpty || latestSignals.isEmpty) {
          refreshAll(silent: true);
        }

        portfolio = syncData.portfolio;
        await StorageService.saveCachedPortfolio(portfolio!);

        funds = BrokerFunds(
          brokerName: 'GROWW',
          isConnected: isGrowwConnected,
          availableFunds: syncData.availableFunds,
          unsettledFunds: 0.0,
          withdrawableFunds: syncData.withdrawableFunds,
          currency: 'INR',
        );

        if (syncData.recentTrades.isNotEmpty) {
          paperTrades = syncData.recentTrades;
          await StorageService.saveCachedPaperTrades(paperTrades);
        }

        if (syncData.autoSellActions.isNotEmpty) {
          final first = syncData.autoSellActions.first;
          final sym = first['symbol'] ?? 'STOCK';
          final reason = first['reason'] ?? 'Auto Take Profit / Stop Loss';
          lastAutoSellMessage = '⚡ Auto-Sell executed: $sym ($reason)';
          NotificationService().showNotification(
            title: '⚡ AUTO-SELL EXECUTED: $sym',
            body: '$reason | Live monitoring auto profit/loss lock executed.',
            data: {'symbol': sym, 'exchange': 'NSE', 'action': 'SELL'},
            isCritical: true,
          );
        }

        // Secondary client-side verification
        await checkAndExecuteAutoSell();

        // Refresh live monitoring feed every second UltraSync cycle (approx 6s)
        _syncCycleCounter++;
        if (_syncCycleCounter % 2 == 0) {
          fetchLiveFeed(silent: true);
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('UltraSync error: $e');
    } finally {
      _isUltraSyncing = false;
    }
  }

  /// Refreshes the real-time live monitoring tick feed
  Future<void> fetchLiveFeed({String? exchange, bool silent = false}) async {
    try {
      final targetExchange = exchange ?? activeExchangeDefault;
      final feed = await api.getLiveMonitoringFeed(exchange: targetExchange);
      if (feed['items'] is List) {
        liveFeed = List<Map<String, dynamic>>.from(feed['items']);
        lastLiveFeedUpdate = DateTime.now();
      }
      final status = await api.getLiveMonitoringStatus(exchange: targetExchange);
      liveMonitoringStatus = status;
      if (!silent) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchLiveFeed error: $e');
    }
  }

  /// Triggers an immediate high-speed priority scan of monitored universe
  Future<void> executeQuickScan() async {
    isQuickScanning = true;
    notifyListeners();
    try {
      await api.triggerQuickScan();
      await fetchLiveFeed(exchange: activeExchangeDefault);
      await refreshAll();
    } catch (e) {
      debugPrint('executeQuickScan error: $e');
    } finally {
      isQuickScanning = false;
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

    // 2. Client-Side Evaluation & Stepped Sell Notifications (+30 Profit / -30 Loss):
    // Evaluates every marked position and dispatches heads-up SELL alerts with Buy Amount, Sell Amount, and PnL
    final positionsCopy = List<Position>.from(portfolio!.positions);
    for (final pos in positionsCopy) {
      if (!pos.isOpen) continue;
      final buyPrice = pos.avgEntryPrice;
      final currPrice = pos.currentPrice > 0 ? pos.currentPrice : buyPrice;
      final qty = pos.quantity > 0 ? pos.quantity : 1;
      final pnlVal = pos.unrealizedPnl != 0.0 ? pos.unrealizedPnl : (currPrice - buyPrice) * qty;
      final pnlPct = buyPrice > 0 ? ((currPrice - buyPrice) / buyPrice) * 100.0 : 0.0;
      final symCur = pos.currencySymbol;
      final tag = pos.marketTag;

      final posKey = '${pos.symbol}_${pos.id}';
      final milestones = _clientTriggeredMilestones.putIfAbsent(posKey, () => <String>{});

      // Stepping logic: Every +30 profit milestone (+30, +60, +90, +120...)
      if (pnlVal > 0) {
        milestones.removeWhere((k) => k.startsWith('LOSS_'));
        final stepProfit = (pnlVal ~/ 30) * 30;
        if (stepProfit >= 30) {
          for (int milestone = 30; milestone <= stepProfit; milestone += 30) {
            final tKey = 'PROFIT_${pos.currency}_$milestone';
            if (!milestones.contains(tKey)) {
              milestones.add(tKey);
              final totalBuy = buyPrice * qty;
              final totalSell = currPrice * qty;
              final title = '🔴 SELL ALERT (+$symCur$milestone PROFIT): $tag @ $symCur${currPrice.toStringAsFixed(2)}';
              final body = '🔴 SELL ALERT: $tag reached +$symCur$milestone Profit Target!\n'
                  '• Market: $tag\n'
                  '• Buy Price: $symCur${buyPrice.toStringAsFixed(2)} | Total Buy Amount: $symCur${totalBuy.toStringAsFixed(2)} (Qty: $qty)\n'
                  '• Sell Price: $symCur${currPrice.toStringAsFixed(2)} | Total Sell Amount: $symCur${totalSell.toStringAsFixed(2)}\n'
                  '• Profit / Loss: +$symCur${pnlVal.toStringAsFixed(2)} (+${pnlPct.toStringAsFixed(2)}%)\n'
                  '• Milestone: +$symCur$milestone Profit Target Reached\n'
                  'Action: Execute SELL order to lock in your profit!';
              NotificationService().showNotification(
                title: title,
                body: body,
                data: {'symbol': pos.symbol, 'exchange': pos.exchange, 'action': 'SELL'},
                isCritical: true,
              );
              debugPrint('Dispatched stepped profit SELL alert for ${pos.symbol}: +$symCur$milestone');
            }
          }
        }
      } else if (pnlVal < 0) {
        milestones.removeWhere((k) => k.startsWith('PROFIT_'));
        final absLoss = pnlVal.abs();
        final stepLoss = (absLoss ~/ 30) * 30;
        if (stepLoss >= 30) {
          for (int milestone = 30; milestone <= stepLoss; milestone += 30) {
            final tKey = 'LOSS_${pos.currency}_$milestone';
            if (!milestones.contains(tKey)) {
              milestones.add(tKey);
              final totalBuy = buyPrice * qty;
              final totalSell = currPrice * qty;
              final title = '🔴 SELL ALERT (-$symCur$milestone LOSS): $tag @ $symCur${currPrice.toStringAsFixed(2)}';
              final body = '🔴 SELL ALERT: $tag reached -$symCur$milestone Stop-Loss Milestone!\n'
                  '• Market: $tag\n'
                  '• Buy Price: $symCur${buyPrice.toStringAsFixed(2)} | Total Buy Amount: $symCur${totalBuy.toStringAsFixed(2)} (Qty: $qty)\n'
                  '• Sell Price: $symCur${currPrice.toStringAsFixed(2)} | Total Sell Amount: $symCur${totalSell.toStringAsFixed(2)}\n'
                  '• Profit / Loss: -$symCur${absLoss.toStringAsFixed(2)} (-${pnlPct.abs().toStringAsFixed(2)}%)\n'
                  '• Milestone: -$symCur$milestone Loss Stop-Loss Milestone\n'
                  'Action: Execute SELL order to protect your capital!';
              NotificationService().showNotification(
                title: title,
                body: body,
                data: {'symbol': pos.symbol, 'exchange': pos.exchange, 'action': 'SELL'},
                isCritical: true,
              );
              debugPrint('Dispatched stepped loss SELL alert for ${pos.symbol}: -$symCur$milestone');
            }
          }
        }
      }

      final price = currPrice;
      bool shouldAutoSell = false;
      String reason = '';

      if (pos.target != null && price >= pos.target! && (pos.autoSellEnabled || autoTakeProfit)) {
        shouldAutoSell = true;
        reason = 'AUTO TAKE PROFIT: Target $symCur${pos.target!.toStringAsFixed(2)} reached';
      } else if (pos.stopLoss != null && price <= pos.stopLoss! && pos.autoSellEnabled) {
        shouldAutoSell = true;
        reason = 'AUTO STOP-LOSS: Stop-loss $symCur${pos.stopLoss!.toStringAsFixed(2)} hit';
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

  // Gemini AI Stock Prediction & Dynamic Search Methods
  Future<StockPrediction?> runGeminiPrediction(String symbol, {String timeframe = '1-DAY', String exchange = 'NSE'}) async {
    isPredicting = true;
    lastPredictedSymbol = symbol;
    notifyListeners();
    try {
      final pred = await api.predictStock(symbol, timeframe: timeframe, exchange: exchange);
      final isMonth = timeframe.toUpperCase().contains('MONTH');
      topPredictions.removeWhere((p) =>
        p.symbol.toUpperCase() == symbol.toUpperCase() &&
        (isMonth ? p.timeHorizon.toUpperCase().contains('MONTH') : !p.timeHorizon.toUpperCase().contains('MONTH'))
      );
      topPredictions.insert(0, pred);
      for (int i = 0; i < stocks.length; i++) {
        if (stocks[i].symbol.toUpperCase() == symbol.toUpperCase()) {
          final s = stocks[i];
          stocks[i] = StockSummary(
            symbol: s.symbol,
            exchange: s.exchange,
            name: s.name,
            sector: s.sector,
            latestPrice: pred.priceAtPrediction > 0 ? pred.priceAtPrediction : s.latestPrice,
            latestTimestamp: DateTime.now(),
            isLive: s.isLive,
            latestSignal: pred.isBullish ? 'BUY WATCH' : (pred.isBearish ? 'SELL/EXIT WATCH' : 'HOLD'),
            signalStrength: pred.confidenceScore,
            explicitPriority: pred.isHighConfidence ? 'HIGH' : 'MEDIUM',
            change: s.change,
            percentChange: s.percentChange,
            dayHigh: s.dayHigh,
            dayLow: s.dayLow,
            volume: s.volume,
            predictedDirection: pred.predictedDirection,
            predictedTarget: pred.targetPrice,
            predictedConfidence: pred.confidenceScore,
          );
        }
      }
      return pred;
    } catch (e) {
      errorMessage = 'Prediction error: $e';
      return null;
    } finally {
      isPredicting = false;
      notifyListeners();
    }
  }

  Future<StockPrediction?> getOrFetchPrediction(String symbol, {String timeframe = '1-DAY', String exchange = 'NSE'}) async {
    final isMonth = timeframe.toUpperCase().contains('MONTH');
    final existing = topPredictions.where((p) =>
      p.symbol.toUpperCase() == symbol.toUpperCase() &&
      (isMonth ? p.timeHorizon.toUpperCase().contains('MONTH') : !p.timeHorizon.toUpperCase().contains('MONTH'))
    ).firstOrNull;
    if (existing != null) return existing;
    return await api.getStockPrediction(symbol, timeframe: timeframe, exchange: exchange);
  }

  Future<List<Map<String, dynamic>>> searchOnlineStocks(String query, {String? exchange}) async {
    try {
      final targetExchange = exchange ?? activeExchangeDefault;
      return await api.searchStocksByMarket(query, market: activeMarket, exchange: targetExchange);
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  Future<bool> addStockToUniverse(String symbol, {String exchange = 'NSE', String? name, String? sector}) async {
    try {
      final added = await api.addStockToUniverse(symbol, exchange: exchange, name: name, sector: sector);
      stocks.removeWhere((s) => s.symbol.toUpperCase() == symbol.toUpperCase());
      stocks.insert(0, added);
      runGeminiPrediction(symbol, exchange: exchange);
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not add stock $symbol: $e';
      notifyListeners();
      return false;
    }
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
    String? exchange,
  }) async {
    final cleanAction = action.toUpperCase().trim();
    final effectivePrice = price ?? 100.0;
    final totalAmount = effectivePrice * quantity;
    final effectiveExchange = exchange ?? (activeMarket == 'US' ? 'US' : 'NSE');

    // 1. Create a local PaperTrade record immediately
    final localTrade = PaperTrade(
      id: DateTime.now().millisecondsSinceEpoch,
      symbol: symbol.toUpperCase(),
      exchange: effectiveExchange,
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
          exchange: effectiveExchange,
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

    // 3. Ultra-low latency backend execution & instant sync
    try {
      final ultraRes = await api.executeUltraTrade(
        symbol: symbol,
        action: cleanAction,
        quantity: quantity,
        price: effectivePrice,
        stopLoss: stopLoss,
        target: target,
        holdingPeriodHours: holdingPeriodHours,
        autoSellEnabled: autoSellEnabled,
      );
      if (ultraRes != null && ultraRes['portfolio'] != null) {
        portfolio = PortfolioSummary.fromJson(ultraRes['portfolio']);
        await StorageService.saveCachedPortfolio(portfolio!);
      } else {
        await api.executePaperTrade(
          symbol: symbol,
          action: cleanAction,
          quantity: quantity,
          price: effectivePrice,
          stopLoss: stopLoss,
          target: target,
          holdingPeriodHours: holdingPeriodHours,
          autoSellEnabled: autoSellEnabled,
        );
      }
      // Instant synchronization
      await executeUltraSync(silent: true);
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

  Future<Map<String, dynamic>> recordManualPurchase({
    required String symbol,
    String? exchange,
    required double actualPrice,
    required int quantity,
    String? purchaseDate,
    String? purchaseTime,
    double charges = 0.0,
    double? customTarget,
    double? customStopLoss,
    String? companyName,
  }) async {
    final effectiveExchange = exchange ?? activeExchangeDefault;
    final result = await api.recordManualPurchase(
      symbol: symbol,
      exchange: effectiveExchange,
      actualPrice: actualPrice,
      quantity: quantity,
      purchaseDate: purchaseDate,
      purchaseTime: purchaseTime,
      charges: charges,
      customTarget: customTarget,
      customStopLoss: customStopLoss,
      companyName: companyName,
    );
    try {
      portfolio = await api.getPortfolioSummary();
      if (portfolio != null) {
        await StorageService.saveCachedPortfolio(portfolio!);
      }
    } catch (_) {}
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> recordManualSale({
    required String symbol,
    String exchange = 'NSE',
    required double sellingPrice,
    required int quantitySold,
    String? sellingDate,
    String? sellingTime,
    double charges = 0.0,
  }) async {
    final result = await api.recordManualSale(
      symbol: symbol,
      exchange: exchange,
      sellingPrice: sellingPrice,
      quantitySold: quantitySold,
      sellingDate: sellingDate,
      sellingTime: sellingTime,
      charges: charges,
    );
    try {
      portfolio = await api.getPortfolioSummary();
      if (portfolio != null) {
        await StorageService.saveCachedPortfolio(portfolio!);
      }
    } catch (_) {}
    notifyListeners();
    return result;
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

  Future<void> markAlertsRead(List<int> alertIds) async {
    try {
      await api.markAlertsRead(alertIds);
      final idSet = alertIds.toSet();
      for (final a in alerts) {
        if (idSet.contains(a.id)) a.isRead = true;
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

  @override
  void dispose() {
    _ultraSyncTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

