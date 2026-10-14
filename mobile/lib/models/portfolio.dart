class Position {
  final int id;
  final String symbol;
  final String exchange;
  final int quantity;
  final double avgEntryPrice;
  final double currentPrice;
  final double? stopLoss;
  final double? target;
  final double unrealizedPnl;
  final double realizedPnl;
  final double fees;
  final bool isOpen;
  final int holdingPeriodHours;
  final DateTime? exitDeadline;
  final bool autoSellEnabled;
  final String exitStrategy;
  final bool exitTriggered;
  final String? exitReason;
  final String mode;
  final String? orderId;

  Position({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.quantity,
    required this.avgEntryPrice,
    required this.currentPrice,
    this.stopLoss,
    this.target,
    required this.unrealizedPnl,
    required this.realizedPnl,
    required this.fees,
    required this.isOpen,
    this.holdingPeriodHours = 48,
    this.exitDeadline,
    this.autoSellEnabled = false,
    this.exitStrategy = 'TARGET_OR_STOPLOSS_OR_EXPIRY',
    this.exitTriggered = false,
    this.exitReason,
    this.mode = 'PAPER',
    this.orderId,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id'] ?? 0,
      symbol: json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      quantity: json['quantity'] ?? 0,
      avgEntryPrice: (json['avg_entry_price'] as num).toDouble(),
      currentPrice: (json['current_price'] as num).toDouble(),
      stopLoss: json['stop_loss'] != null ? (json['stop_loss'] as num).toDouble() : null,
      target: json['target'] != null ? (json['target'] as num).toDouble() : null,
      unrealizedPnl: (json['unrealized_pnl'] as num).toDouble(),
      realizedPnl: (json['realized_pnl'] as num).toDouble(),
      fees: (json['fees'] as num).toDouble(),
      isOpen: json['is_open'] ?? true,
      holdingPeriodHours: json['holding_period_hours'] ?? 48,
      exitDeadline: json['exit_deadline'] != null ? DateTime.tryParse(json['exit_deadline']) : null,
      autoSellEnabled: json['auto_sell_enabled'] ?? false,
      exitStrategy: json['exit_strategy'] ?? 'TARGET_OR_STOPLOSS_OR_EXPIRY',
      exitTriggered: json['exit_triggered'] ?? false,
      exitReason: json['exit_reason'],
      mode: json['mode'] ?? 'PAPER',
      orderId: json['order_id'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'exchange': exchange,
        'quantity': quantity,
        'avg_entry_price': avgEntryPrice,
        'current_price': currentPrice,
        'stop_loss': stopLoss,
        'target': target,
        'unrealized_pnl': unrealizedPnl,
        'realized_pnl': realizedPnl,
        'fees': fees,
        'is_open': isOpen,
        'holding_period_hours': holdingPeriodHours,
        'exit_deadline': exitDeadline?.toIso8601String(),
        'auto_sell_enabled': autoSellEnabled,
        'exit_strategy': exitStrategy,
        'exit_triggered': exitTriggered,
        'exit_reason': exitReason,
        'mode': mode,
        'order_id': orderId,
      };
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

