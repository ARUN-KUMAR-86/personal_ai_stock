class Position {
  final int id;
  final String symbol;
  final String companyName;
  final String exchange;
  final int quantity;
  final double avgEntryPrice;
  final double currentPrice;
  final double? stopLoss;
  final double? target;
  final double unrealizedPnl;
  final double realizedPnl;
  final double fees;
  final double charges;
  final bool isOpen;
  final String status;
  final String priority;
  final double pnlPct;
  final double investedAmount;
  final double currentValue;
  final int holdingPeriodHours;
  final DateTime? exitDeadline;
  final DateTime? purchaseDate;
  final bool autoSellEnabled;
  final String exitStrategy;
  final bool exitTriggered;
  final String? exitReason;
  final String mode;
  final String? orderId;
  final List<String> triggeredThresholds;

  Position({
    required this.id,
    required this.symbol,
    this.companyName = '',
    required this.exchange,
    required this.quantity,
    required this.avgEntryPrice,
    required this.currentPrice,
    this.stopLoss,
    this.target,
    required this.unrealizedPnl,
    required this.realizedPnl,
    required this.fees,
    this.charges = 0.0,
    required this.isOpen,
    this.status = 'ACTIVE',
    this.priority = 'P2',
    this.pnlPct = 0.0,
    this.investedAmount = 0.0,
    this.currentValue = 0.0,
    this.holdingPeriodHours = 48,
    this.exitDeadline,
    this.purchaseDate,
    this.autoSellEnabled = false,
    this.exitStrategy = 'MANUAL_GROWW_MONITOR',
    this.exitTriggered = false,
    this.exitReason,
    this.mode = 'GROWW_MANUAL',
    this.orderId,
    this.triggeredThresholds = const [],
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    final avgPrice = (json['avg_entry_price'] as num?)?.toDouble() ?? 0.0;
    final currPrice = (json['current_price'] as num?)?.toDouble() ?? 0.0;
    final qty = json['quantity'] ?? 0;
    final unPnl = (json['unrealized_pnl'] as num?)?.toDouble() ?? ((currPrice - avgPrice) * qty);
    final calculatedPct = avgPrice > 0 ? ((currPrice - avgPrice) / avgPrice * 100) : 0.0;

    return Position(
      id: json['id'] ?? 0,
      symbol: json['symbol'] ?? '',
      companyName: json['company_name'] ?? json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      quantity: qty,
      avgEntryPrice: avgPrice,
      currentPrice: currPrice,
      stopLoss: json['stop_loss'] != null ? (json['stop_loss'] as num).toDouble() : null,
      target: json['target'] != null ? (json['target'] as num).toDouble() : null,
      unrealizedPnl: unPnl,
      realizedPnl: (json['realized_pnl'] as num?)?.toDouble() ?? 0.0,
      fees: (json['fees'] as num?)?.toDouble() ?? 0.0,
      charges: (json['charges'] as num?)?.toDouble() ?? 0.0,
      isOpen: json['is_open'] ?? (json['status'] == 'ACTIVE'),
      status: json['status'] ?? 'ACTIVE',
      priority: json['priority'] ?? 'P2',
      pnlPct: (json['pnl_pct'] as num?)?.toDouble() ?? calculatedPct,
      investedAmount: (json['invested_amount'] as num?)?.toDouble() ?? (avgPrice * qty),
      currentValue: (json['current_value'] as num?)?.toDouble() ?? (currPrice * qty),
      holdingPeriodHours: json['holding_period_hours'] ?? 48,
      exitDeadline: json['exit_deadline'] != null ? DateTime.tryParse(json['exit_deadline']) : null,
      purchaseDate: json['purchase_date'] != null ? DateTime.tryParse(json['purchase_date']) : null,
      autoSellEnabled: json['auto_sell_enabled'] ?? false,
      exitStrategy: json['exit_strategy'] ?? 'MANUAL_GROWW_MONITOR',
      exitTriggered: json['exit_triggered'] ?? false,
      exitReason: json['exit_reason'],
      mode: json['mode'] ?? 'GROWW_MANUAL',
      orderId: json['order_id'],
      triggeredThresholds: (json['triggered_thresholds'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'company_name': companyName,
        'exchange': exchange,
        'quantity': quantity,
        'avg_entry_price': avgEntryPrice,
        'current_price': currentPrice,
        'stop_loss': stopLoss,
        'target': target,
        'unrealized_pnl': unrealizedPnl,
        'realized_pnl': realizedPnl,
        'fees': fees,
        'charges': charges,
        'is_open': isOpen,
        'status': status,
        'priority': priority,
        'pnl_pct': pnlPct,
        'invested_amount': investedAmount,
        'current_value': currentValue,
        'holding_period_hours': holdingPeriodHours,
        'exit_deadline': exitDeadline?.toIso8601String(),
        'purchase_date': purchaseDate?.toIso8601String(),
        'auto_sell_enabled': autoSellEnabled,
        'exit_strategy': exitStrategy,
        'exit_triggered': exitTriggered,
        'exit_reason': exitReason,
        'mode': mode,
        'order_id': orderId,
        'triggered_thresholds': triggeredThresholds,
      };

  Position copyWith({
    int? id,
    String? symbol,
    String? companyName,
    String? exchange,
    int? quantity,
    double? avgEntryPrice,
    double? currentPrice,
    double? stopLoss,
    double? target,
    double? unrealizedPnl,
    double? realizedPnl,
    double? fees,
    double? charges,
    bool? isOpen,
    String? status,
    String? priority,
    double? pnlPct,
    double? investedAmount,
    double? currentValue,
    int? holdingPeriodHours,
    DateTime? exitDeadline,
    DateTime? purchaseDate,
    bool? autoSellEnabled,
    String? exitStrategy,
    bool? exitTriggered,
    String? exitReason,
    String? mode,
    String? orderId,
    List<String>? triggeredThresholds,
  }) {
    return Position(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      companyName: companyName ?? this.companyName,
      exchange: exchange ?? this.exchange,
      quantity: quantity ?? this.quantity,
      avgEntryPrice: avgEntryPrice ?? this.avgEntryPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      stopLoss: stopLoss ?? this.stopLoss,
      target: target ?? this.target,
      unrealizedPnl: unrealizedPnl ?? this.unrealizedPnl,
      realizedPnl: realizedPnl ?? this.realizedPnl,
      fees: fees ?? this.fees,
      charges: charges ?? this.charges,
      isOpen: isOpen ?? this.isOpen,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      pnlPct: pnlPct ?? this.pnlPct,
      investedAmount: investedAmount ?? this.investedAmount,
      currentValue: currentValue ?? this.currentValue,
      holdingPeriodHours: holdingPeriodHours ?? this.holdingPeriodHours,
      exitDeadline: exitDeadline ?? this.exitDeadline,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      autoSellEnabled: autoSellEnabled ?? this.autoSellEnabled,
      exitStrategy: exitStrategy ?? this.exitStrategy,
      exitTriggered: exitTriggered ?? this.exitTriggered,
      exitReason: exitReason ?? this.exitReason,
      mode: mode ?? this.mode,
      orderId: orderId ?? this.orderId,
      triggeredThresholds: triggeredThresholds ?? this.triggeredThresholds,
    );
  }

  bool get isUS => (exchange.toUpperCase() == 'US' || exchange.toUpperCase() == 'NASDAQ' || exchange.toUpperCase() == 'NYSE');
  String get currency => isUS ? 'USD' : 'INR';
  String get currencySymbol => isUS ? '\$' : '₹';
  String get marketTag => '$symbol – ${exchange.toUpperCase()} – $currency';
}

class PaperTrade {
  final int id;
  final String symbol;
  final String exchange;
  final String action;
  final int quantity;
  final double price;
  final double fees;
  final double totalAmount;
  final double pnl;
  final String? reason;
  final DateTime timestamp;
  final double? stopLoss;
  final double? target;
  final int holdingPeriodHours;
  final bool autoSellEnabled;

  PaperTrade({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.action,
    required this.quantity,
    required this.price,
    required this.fees,
    required this.totalAmount,
    required this.pnl,
    this.reason,
    required this.timestamp,
    this.stopLoss,
    this.target,
    this.holdingPeriodHours = 48,
    this.autoSellEnabled = true,
  });

  factory PaperTrade.fromJson(Map<String, dynamic> json) {
    return PaperTrade(
      id: json['id'] ?? 0,
      symbol: json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      action: json['action'] ?? 'BUY',
      quantity: json['quantity'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      fees: (json['fees'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'],
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      stopLoss: (json['stop_loss'] as num?)?.toDouble(),
      target: (json['target'] as num?)?.toDouble(),
      holdingPeriodHours: json['holding_period_hours'] ?? 48,
      autoSellEnabled: json['auto_sell_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'exchange': exchange,
        'action': action,
        'quantity': quantity,
        'price': price,
        'fees': fees,
        'total_amount': totalAmount,
        'pnl': pnl,
        'reason': reason,
        'timestamp': timestamp.toIso8601String(),
        'stop_loss': stopLoss,
        'target': target,
        'holding_period_hours': holdingPeriodHours,
        'auto_sell_enabled': autoSellEnabled,
      };

  bool get isUS => (exchange.toUpperCase() == 'US' || exchange.toUpperCase() == 'NASDAQ' || exchange.toUpperCase() == 'NYSE');
  String get currency => isUS ? 'USD' : 'INR';
  String get currencySymbol => isUS ? '\$' : '₹';
  String get marketTag => '$symbol – ${exchange.toUpperCase()} – $currency';
}

class PortfolioSummary {
  final double totalPortfolioValue;
  final double totalInvestedValue;
  final double totalUnrealizedPnl;
  final double totalRealizedPnl;
  final int openPositionsCount;
  final double portfolioExposurePct;
  final List<Position> positions;

  PortfolioSummary({
    required this.totalPortfolioValue,
    required this.totalInvestedValue,
    required this.totalUnrealizedPnl,
    required this.totalRealizedPnl,
    required this.openPositionsCount,
    required this.portfolioExposurePct,
    required this.positions,
  });

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    var posList = (json['positions'] as List?)?.map((p) => Position.fromJson(p)).toList() ?? [];
    return PortfolioSummary(
      totalPortfolioValue: (json['total_portfolio_value'] as num?)?.toDouble() ?? 0.0,
      totalInvestedValue: (json['total_invested_value'] as num?)?.toDouble() ?? 0.0,
      totalUnrealizedPnl: (json['total_unrealized_pnl'] as num?)?.toDouble() ?? 0.0,
      totalRealizedPnl: (json['total_realized_pnl'] as num?)?.toDouble() ?? 0.0,
      openPositionsCount: json['open_positions_count'] ?? 0,
      portfolioExposurePct: (json['portfolio_exposure_pct'] as num?)?.toDouble() ?? 0.0,
      positions: posList,
    );
  }

  Map<String, dynamic> toJson() => {
        'total_portfolio_value': totalPortfolioValue,
        'total_invested_value': totalInvestedValue,
        'total_unrealized_pnl': totalUnrealizedPnl,
        'total_realized_pnl': totalRealizedPnl,
        'open_positions_count': openPositionsCount,
        'portfolio_exposure_pct': portfolioExposurePct,
        'positions': positions.map((p) => p.toJson()).toList(),
      };
}

class UltraSyncData {
  final String timestamp;
  final double latencyBenchmarkMs;
  final int clientRoundtripMs;
  final bool marketOpen;
  final PortfolioSummary portfolio;
  final double availableFunds;
  final double accountBalance;
  final double tradingBudget;
  final double withdrawableFunds;
  final bool isTradingActive;
  final String tradingMode;
  final String activeAlgorithm;
  final bool autoTakeProfit;
  final List<PaperTrade> recentTrades;
  final List<dynamic> autoSellActions;

  UltraSyncData({
    required this.timestamp,
    required this.latencyBenchmarkMs,
    required this.clientRoundtripMs,
    required this.marketOpen,
    required this.portfolio,
    required this.availableFunds,
    required this.accountBalance,
    required this.tradingBudget,
    required this.withdrawableFunds,
    required this.isTradingActive,
    required this.tradingMode,
    required this.activeAlgorithm,
    required this.autoTakeProfit,
    required this.recentTrades,
    required this.autoSellActions,
  });

  factory UltraSyncData.fromJson(Map<String, dynamic> json, int clientRoundtripMs) {
    final trades = (json['recent_trades'] as List?)
            ?.map((t) => PaperTrade.fromJson(t))
            .toList() ??
        [];
    return UltraSyncData(
      timestamp: json['timestamp'] ?? '',
      latencyBenchmarkMs: (json['latency_benchmark_ms'] as num?)?.toDouble() ?? 0.0,
      clientRoundtripMs: clientRoundtripMs,
      marketOpen: json['market_open'] ?? false,
      portfolio: PortfolioSummary.fromJson(json['portfolio'] ?? {}),
      availableFunds: (json['available_funds'] as num?)?.toDouble() ?? 1000.0,
      accountBalance: (json['account_balance'] as num?)?.toDouble() ?? 1000.0,
      tradingBudget: (json['trading_budget'] as num?)?.toDouble() ?? 300.0,
      withdrawableFunds: (json['withdrawable_funds'] as num?)?.toDouble() ?? 1000.0,
      isTradingActive: json['is_trading_active'] ?? true,
      tradingMode: json['trading_mode'] ?? 'Option B: Hybrid Guard (Auto Stop-Loss)',
      activeAlgorithm: json['active_algorithm'] ?? 'Breakout Momentum',
      autoTakeProfit: json['auto_take_profit'] ?? true,
      recentTrades: trades,
      autoSellActions: json['auto_sell_actions'] ?? [],
    );
  }
}

