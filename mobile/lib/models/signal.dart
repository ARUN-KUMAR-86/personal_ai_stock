class StockSignal {
  final int id;
  final String symbol;
  final String exchange;
  final DateTime timestamp;
  final String signalType;
  final String strategyName;
  final double price;
  final double? stopLoss;
  final double? target;
  final double? riskReward;
  final double strength;
  final String priority;
  final String? companyName;
  final double? entryRangeLow;
  final double? entryRangeHigh;
  final int holdingPeriodHours;
  final String dataSource;
  final String dataFreshness;
  final String? entryCondition;
  final String? invalidationCondition;
  final Map<String, dynamic>? indicatorSummary;
  final String? liquiditySummary;
  final List<dynamic>? financialNews;
  final List<dynamic>? riskFactors;
  final Map<String, dynamic>? scoreBreakdown;
  final String explanation;
  final Map<String, dynamic>? aiThesis;

  StockSignal({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.timestamp,
    required this.signalType,
    required this.strategyName,
    required this.price,
    this.stopLoss,
    this.target,
    this.riskReward,
    required this.strength,
    this.priority = 'MEDIUM',
    this.companyName,
    this.entryRangeLow,
    this.entryRangeHigh,
    this.holdingPeriodHours = 48,
    this.dataSource = 'Verified Market Data',
    this.dataFreshness = 'Live',
    this.entryCondition,
    this.invalidationCondition,
    this.indicatorSummary,
    this.liquiditySummary,
    this.financialNews,
    this.riskFactors,
    this.scoreBreakdown,
    required this.explanation,
    this.aiThesis,
  });

  bool get isHighPriority => priority.toUpperCase() == 'HIGH' || strength >= 75.0;
  bool get isMediumPriority => priority.toUpperCase() == 'MEDIUM' || (strength >= 50.0 && strength < 75.0);

  // Structured AI thesis getters with safe fallbacks
  String? get aiHeadline => aiThesis?['headline'] as String?;
  String get aiInvestmentThesis => (aiThesis?['investment_thesis'] as String?) ?? explanation;
  List<String> get aiCatalysts {
    final raw = aiThesis?['catalysts'] as List?;
    if (raw != null) return raw.map((e) => e.toString()).toList();
    return [];
  }
  List<String> get aiRiskFactors {
    final raw = (aiThesis?['risk_factors'] as List?) ?? riskFactors;
    if (raw != null) return raw.map((e) => e.toString()).toList();
    return [];
  }
  Map<String, dynamic>? get aiTechnicalSummary => aiThesis?['technical_summary'] as Map<String, dynamic>?;
  Map<String, dynamic>? get aiTacticalPlan => aiThesis?['tactical_plan'] as Map<String, dynamic>?;
  String get aiModelUsed => (aiThesis?['model_used'] as String?) ?? 'Highest Gain Maximizer (Auto Take Money)';
  String? get aiInvalidationTrigger => (aiThesis?['invalidation_trigger'] as String?) ?? invalidationCondition;

  factory StockSignal.fromJson(Map<String, dynamic> json) {
    final strengthVal = (json['strength'] as num?)?.toDouble() ?? 50.0;
    String pri = json['priority'] as String? ?? '';
    if (pri.isEmpty) {
      if (strengthVal >= 75.0) {
        pri = 'HIGH';
      } else if (strengthVal >= 50.0) {
        pri = 'MEDIUM';
      } else {
        pri = 'LOW';
      }
    }

    return StockSignal(
      id: json['id'] ?? 0,
      symbol: json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      timestamp: DateTime.parse(json['timestamp']),
      signalType: json['signal_type'] ?? 'NO TRADE',
      strategyName: json['strategy_name'] ?? '',
      price: (json['price'] as num).toDouble(),
      stopLoss: json['stop_loss'] != null ? (json['stop_loss'] as num).toDouble() : null,
      target: json['target'] != null ? (json['target'] as num).toDouble() : null,
      riskReward: json['risk_reward'] != null ? (json['risk_reward'] as num).toDouble() : null,
      strength: strengthVal,
      priority: pri,
      companyName: json['company_name'],
      entryRangeLow: json['entry_range_low'] != null ? (json['entry_range_low'] as num).toDouble() : null,
      entryRangeHigh: json['entry_range_high'] != null ? (json['entry_range_high'] as num).toDouble() : null,
      holdingPeriodHours: json['holding_period_hours'] ?? 48,
      dataSource: json['data_source'] ?? 'Verified Market Data',
      dataFreshness: json['data_freshness'] ?? 'Live',
      entryCondition: json['entry_condition'],
      invalidationCondition: json['invalidation_condition'],
      indicatorSummary: json['indicator_summary'],
      liquiditySummary: json['liquidity_summary'],
      financialNews: json['financial_news'],
      riskFactors: json['risk_factors'],
      scoreBreakdown: json['score_breakdown'],
      explanation: json['explanation'] ?? '',
      aiThesis: json['ai_thesis'] != null ? Map<String, dynamic>.from(json['ai_thesis']) : null,
    );
  }
}
