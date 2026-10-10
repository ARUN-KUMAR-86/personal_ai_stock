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
  final String? entryCondition;
  final String? invalidationCondition;
  final Map<String, dynamic>? indicatorSummary;
  final String explanation;

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
    this.entryCondition,
    this.invalidationCondition,
    this.indicatorSummary,
    required this.explanation,
  });

  factory StockSignal.fromJson(Map<String, dynamic> json) {
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
      strength: (json['strength'] as num).toDouble(),
      entryCondition: json['entry_condition'],
      invalidationCondition: json['invalidation_condition'],
      indicatorSummary: json['indicator_summary'],
      explanation: json['explanation'] ?? '',
    );
  }
}
