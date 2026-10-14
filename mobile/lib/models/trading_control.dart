class TradingControlSummary {
  final String growwAccountStatus;
  final String? growwAccountId;
  final String? growwAccountName;
  final double accountBalance;
  final double availableFunds;
  final double tradingBudget;
  final double amountInPositions;
  final double todaysPnl;
  final double todaysRealizedPnl;
  final double todaysUnrealizedPnl;
  final bool isTradingActive;
  final String tradingMode;
  final double maxAmountPerTrade;
  final double dailyLossLimit;
  final bool autoWithdrawProfits;
  final double autoWithdrawThreshold;
  final DateTime? tokenExpiry;
  final DateTime? lastVerifiedAt;
  final bool isBrokerVerified;
  final String activeAlgorithm;
  final bool autoTakeProfit;

  TradingControlSummary({
    required this.growwAccountStatus,
    this.growwAccountId,
    this.growwAccountName,
    required this.accountBalance,
    required this.availableFunds,
    required this.tradingBudget,
    required this.amountInPositions,
    required this.todaysPnl,
    required this.todaysRealizedPnl,
    required this.todaysUnrealizedPnl,
    required this.isTradingActive,
    required this.tradingMode,
    required this.maxAmountPerTrade,
    required this.dailyLossLimit,
    required this.autoWithdrawProfits,
    required this.autoWithdrawThreshold,
    this.tokenExpiry,
    this.lastVerifiedAt,
    required this.isBrokerVerified,
    this.activeAlgorithm = 'Highest Profit Maximizer (Auto Take Money)',
    this.autoTakeProfit = true,
  });

  factory TradingControlSummary.fromJson(Map<String, dynamic> json) {
    return TradingControlSummary(
      growwAccountStatus: json['groww_account_status'] ?? 'Disconnected',
      growwAccountId: json['groww_account_id'],
      growwAccountName: json['groww_account_name'],
      accountBalance: (json['account_balance'] as num?)?.toDouble() ?? 1000.0,
      availableFunds: (json['available_funds'] as num?)?.toDouble() ?? 1000.0,
      tradingBudget: (json['trading_budget'] as num?)?.toDouble() ?? 300.0,
      amountInPositions: (json['amount_in_positions'] as num?)?.toDouble() ?? 0.0,
      todaysPnl: (json['todays_pnl'] as num?)?.toDouble() ?? 0.0,
      todaysRealizedPnl: (json['todays_realized_pnl'] as num?)?.toDouble() ?? 0.0,
      todaysUnrealizedPnl: (json['todays_unrealized_pnl'] as num?)?.toDouble() ?? 0.0,
      isTradingActive: json['is_trading_active'] ?? true,
      tradingMode: json['trading_mode'] ?? 'Option B: Hybrid Guard (Auto Stop-Loss)',
      maxAmountPerTrade: (json['max_amount_per_trade'] as num?)?.toDouble() ?? 100.0,
      dailyLossLimit: (json['daily_loss_limit'] as num?)?.toDouble() ?? 50.0,
      autoWithdrawProfits: json['auto_withdraw_profits'] ?? false,
      autoWithdrawThreshold: (json['auto_withdraw_threshold'] as num?)?.toDouble() ?? 100.0,
      tokenExpiry: json['token_expiry'] != null ? DateTime.parse(json['token_expiry']) : null,
      lastVerifiedAt: json['last_verified_at'] != null ? DateTime.parse(json['last_verified_at']) : null,
      isBrokerVerified: json['is_broker_verified'] ?? true,
      activeAlgorithm: json['active_algorithm'] ?? 'Highest Profit Maximizer (Auto Take Money)',
      autoTakeProfit: json['auto_take_profit'] ?? true,
    );
  }
}

class FundTransaction {
  final int id;
  final String transactionType;
  final double amount;
  final String status;
  final String? note;
  final String? brokerRefId;
  final DateTime createdAt;

  FundTransaction({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.status,
    this.note,
    this.brokerRefId,
    required this.createdAt,
  });

  factory FundTransaction.fromJson(Map<String, dynamic> json) {
    return FundTransaction(
      id: json['id'] ?? 0,
      transactionType: json['transaction_type'] ?? 'DEPOSIT',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'CONFIRMED',
      note: json['note'],
      brokerRefId: json['broker_ref_id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}
