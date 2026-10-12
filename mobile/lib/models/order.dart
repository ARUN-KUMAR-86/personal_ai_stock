class OrderCalculation {
  final bool isValid;
  final int sharesQuantity;
  final double verifiedEntryPrice;
  final double estimatedInvestment;
  final double totalOutlay;
  final Map<String, dynamic> buyCharges;
  final double roundtripTargetCharges;
  final double roundtripSlCharges;
  final double potentialProfitNet;
  final double potentialProfitPct;
  final double potentialLossNet;
  final double potentialLossPct;
  final double riskRewardRatio;
  final double remainingAvailableFunds;
  final int holdingPeriodHours;
  final List<String> warnings;

  OrderCalculation({
    required this.isValid,
    required this.sharesQuantity,
    required this.verifiedEntryPrice,
    required this.estimatedInvestment,
    required this.totalOutlay,
    required this.buyCharges,
    required this.roundtripTargetCharges,
    required this.roundtripSlCharges,
    required this.potentialProfitNet,
    required this.potentialProfitPct,
    required this.potentialLossNet,
    required this.potentialLossPct,
    required this.riskRewardRatio,
    required this.remainingAvailableFunds,
    required this.holdingPeriodHours,
    required this.warnings,
  });

  factory OrderCalculation.fromJson(Map<String, dynamic> json) {
    return OrderCalculation(
      isValid: json['is_valid'] ?? false,
      sharesQuantity: json['shares_quantity'] ?? 0,
      verifiedEntryPrice: (json['verified_entry_price'] as num?)?.toDouble() ?? 0.0,
      estimatedInvestment: (json['estimated_investment'] as num?)?.toDouble() ?? 0.0,
      totalOutlay: (json['total_outlay'] as num?)?.toDouble() ?? 0.0,
      buyCharges: json['buy_charges'] ?? {},
      roundtripTargetCharges: (json['roundtrip_target_charges'] as num?)?.toDouble() ?? 0.0,
      roundtripSlCharges: (json['roundtrip_sl_charges'] as num?)?.toDouble() ?? 0.0,
      potentialProfitNet: (json['potential_profit_net'] as num?)?.toDouble() ?? 0.0,
      potentialProfitPct: (json['potential_profit_pct'] as num?)?.toDouble() ?? 0.0,
      potentialLossNet: (json['potential_loss_net'] as num?)?.toDouble() ?? 0.0,
      potentialLossPct: (json['potential_loss_pct'] as num?)?.toDouble() ?? 0.0,
      riskRewardRatio: (json['risk_reward_ratio'] as num?)?.toDouble() ?? 0.0,
      remainingAvailableFunds: (json['remaining_available_funds'] as num?)?.toDouble() ?? 0.0,
      holdingPeriodHours: json['holding_period_hours'] ?? 48,
      warnings: (json['warnings'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class PreparedBuyOrder {
  final String symbol;
  final String exchange;
  final String companyName;
  final double verifiedCurrentPrice;
  final bool priceChanged;
  final double slippagePct;
  final String? slippageWarning;
  final int sharesQuantity;
  final double estimatedInvestment;
  final double totalCharges;
  final double totalOutlay;
  final double availableFunds;
  final double stopLoss;
  final double target;
  final int holdingPeriodHours;
  final double riskRewardRatio;
  final String clientOrderId;
  final String mode;

  PreparedBuyOrder({
    required this.symbol,
    required this.exchange,
    required this.companyName,
    required this.verifiedCurrentPrice,
    required this.priceChanged,
    required this.slippagePct,
    this.slippageWarning,
    required this.sharesQuantity,
    required this.estimatedInvestment,
    required this.totalCharges,
    required this.totalOutlay,
    required this.availableFunds,
    required this.stopLoss,
    required this.target,
    required this.holdingPeriodHours,
    required this.riskRewardRatio,
    required this.clientOrderId,
    required this.mode,
  });

  factory PreparedBuyOrder.fromJson(Map<String, dynamic> json) {
    return PreparedBuyOrder(
      symbol: json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      companyName: json['company_name'] ?? json['symbol'] ?? '',
      verifiedCurrentPrice: (json['verified_current_price'] as num).toDouble(),
      priceChanged: json['price_changed'] ?? false,
      slippagePct: (json['slippage_pct'] as num?)?.toDouble() ?? 0.0,
      slippageWarning: json['slippage_warning'],
      sharesQuantity: json['shares_quantity'] ?? 0,
      estimatedInvestment: (json['estimated_investment'] as num).toDouble(),
      totalCharges: (json['total_charges'] as num).toDouble(),
      totalOutlay: (json['total_outlay'] as num).toDouble(),
      availableFunds: (json['available_funds'] as num).toDouble(),
      stopLoss: (json['stop_loss'] as num).toDouble(),
      target: (json['target'] as num).toDouble(),
      holdingPeriodHours: json['holding_period_hours'] ?? 48,
      riskRewardRatio: (json['risk_reward_ratio'] as num).toDouble(),
      clientOrderId: json['client_order_id'] ?? '',
      mode: json['mode'] ?? 'PAPER',
    );
  }
}

class ConfirmedOrder {
  final int id;
  final String orderId;
  final String clientOrderId;
  final String symbol;
  final String exchange;
  final String transactionType;
  final String orderType;
  final String status;
  final int requestedQuantity;
  final int filledQuantity;
  final double requestedPrice;
  final double? executedPrice;
  final double? stopLoss;
  final double? target;
  final int holdingPeriodHours;
  final double totalCharges;
  final String mode;
  final bool userConfirmed;
  final bool autoSellEnabled;
  final String? brokerOrderId;
  final String? errorMessage;
  final DateTime userConfirmedAt;
  final DateTime? executedAt;

  ConfirmedOrder({
    required this.id,
    required this.orderId,
    required this.clientOrderId,
    required this.symbol,
    required this.exchange,
    required this.transactionType,
    required this.orderType,
    required this.status,
    required this.requestedQuantity,
    required this.filledQuantity,
    required this.requestedPrice,
    this.executedPrice,
    this.stopLoss,
    this.target,
    required this.holdingPeriodHours,
    required this.totalCharges,
    required this.mode,
    required this.userConfirmed,
    required this.autoSellEnabled,
    this.brokerOrderId,
    this.errorMessage,
    required this.userConfirmedAt,
    this.executedAt,
  });

  factory ConfirmedOrder.fromJson(Map<String, dynamic> json) {
    return ConfirmedOrder(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? '',
      clientOrderId: json['client_order_id'] ?? '',
      symbol: json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      transactionType: json['transaction_type'] ?? 'BUY',
      orderType: json['order_type'] ?? 'MARKET',
      status: json['status'] ?? 'SUBMITTED',
      requestedQuantity: json['requested_quantity'] ?? 0,
      filledQuantity: json['filled_quantity'] ?? 0,
      requestedPrice: (json['requested_price'] as num).toDouble(),
      executedPrice: json['executed_price'] != null ? (json['executed_price'] as num).toDouble() : null,
      stopLoss: json['stop_loss'] != null ? (json['stop_loss'] as num).toDouble() : null,
      target: json['target'] != null ? (json['target'] as num).toDouble() : null,
      holdingPeriodHours: json['holding_period_hours'] ?? 48,
      totalCharges: (json['total_charges'] as num?)?.toDouble() ?? 0.0,
      mode: json['mode'] ?? 'PAPER',
      userConfirmed: json['user_confirmed'] ?? true,
      autoSellEnabled: json['auto_sell_enabled'] ?? false,
      brokerOrderId: json['broker_order_id'],
      errorMessage: json['error_message'],
      userConfirmedAt: DateTime.parse(json['user_confirmed_at']),
      executedAt: json['executed_at'] != null ? DateTime.parse(json['executed_at']) : null,
    );
  }
}

class SafetyStatus {
  final bool emergencyStopEnabled;
  final bool autoSellEnabled;
  final double maxPositionRiskPct;
  final double maxSingleStockPct;
  final double maxPortfolioExposurePct;
  final String executionMode;
  final bool autoBuyingAllowed;

  SafetyStatus({
    required this.emergencyStopEnabled,
    required this.autoSellEnabled,
    required this.maxPositionRiskPct,
    required this.maxSingleStockPct,
    required this.maxPortfolioExposurePct,
    required this.executionMode,
    this.autoBuyingAllowed = false,
  });

  factory SafetyStatus.fromJson(Map<String, dynamic> json) {
    return SafetyStatus(
      emergencyStopEnabled: json['emergency_stop_enabled'] ?? false,
      autoSellEnabled: json['auto_sell_enabled'] ?? false,
      maxPositionRiskPct: (json['max_position_risk_pct'] as num?)?.toDouble() ?? 2.0,
      maxSingleStockPct: (json['max_single_stock_pct'] as num?)?.toDouble() ?? 10.0,
      maxPortfolioExposurePct: (json['max_portfolio_exposure_pct'] as num?)?.toDouble() ?? 25.0,
      executionMode: json['execution_mode'] ?? 'PAPER',
      autoBuyingAllowed: json['auto_buying_allowed'] ?? false,
    );
  }
}
