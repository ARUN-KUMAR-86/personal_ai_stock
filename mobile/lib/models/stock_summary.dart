class StockSummary {
  final String symbol;
  final String exchange;
  final String name;
  final String? sector;
  final double? latestPrice;
  final DateTime? latestTimestamp;
  final bool isLive;
  final String latestSignal;
  final double signalStrength;
  final String? explicitPriority;
  final double change;
  final double percentChange;
  final double? dayHigh;
  final double? dayLow;
  final double? volume;
  final String? predictedDirection;
  final double? predictedTarget;
  final double? predictedConfidence;

  StockSummary({
    required this.symbol,
    required this.exchange,
    required this.name,
    this.sector,
    this.latestPrice,
    this.latestTimestamp,
    required this.isLive,
    required this.latestSignal,
    required this.signalStrength,
    this.explicitPriority,
    this.change = 0.0,
    this.percentChange = 0.0,
    this.dayHigh,
    this.dayLow,
    this.volume,
    this.predictedDirection,
    this.predictedTarget,
    this.predictedConfidence,
  });

  String get priority {
    if (explicitPriority != null && explicitPriority!.isNotEmpty) {
      return explicitPriority!.toUpperCase();
    }
    if ((predictedConfidence ?? signalStrength) >= 75.0) return 'HIGH';
    if ((predictedConfidence ?? signalStrength) >= 50.0) return 'MEDIUM';
    return 'LOW';
  }

  bool get isHighPriority => priority == 'HIGH';
  bool get isMediumPriority => priority == 'MEDIUM';

  bool get isBullish => predictedDirection?.toUpperCase() == 'BULLISH';
  bool get isBearish => predictedDirection?.toUpperCase() == 'BEARISH';
  bool get hasPrediction => predictedDirection != null && predictedDirection!.isNotEmpty;

  factory StockSummary.fromJson(Map<String, dynamic> json) {
    return StockSummary(
      symbol: json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      name: json['name'] ?? '',
      sector: json['sector'],
      latestPrice: json['latest_price'] != null ? (json['latest_price'] as num).toDouble() : null,
      latestTimestamp: json['latest_timestamp'] != null ? DateTime.tryParse(json['latest_timestamp']) : null,
      isLive: json['is_live'] ?? false,
      latestSignal: json['latest_signal'] ?? 'NO TRADE',
      signalStrength: json['signal_strength'] != null ? (json['signal_strength'] as num).toDouble() : 0.0,
      explicitPriority: json['priority'] as String?,
      change: json['change'] != null ? (json['change'] as num).toDouble() : 0.0,
      percentChange: json['percent_change'] != null ? (json['percent_change'] as num).toDouble() : 0.0,
      dayHigh: json['day_high'] != null ? (json['day_high'] as num).toDouble() : null,
      dayLow: json['day_low'] != null ? (json['day_low'] as num).toDouble() : null,
      volume: json['volume'] != null ? (json['volume'] as num).toDouble() : null,
      predictedDirection: json['predicted_direction'] as String?,
      predictedTarget: json['predicted_target'] != null ? (json['predicted_target'] as num).toDouble() : null,
      predictedConfidence: json['predicted_confidence'] != null ? (json['predicted_confidence'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'exchange': exchange,
        'name': name,
        'sector': sector,
        'latest_price': latestPrice,
        'latest_timestamp': latestTimestamp?.toIso8601String(),
        'is_live': isLive,
        'latest_signal': latestSignal,
        'signal_strength': signalStrength,
        'priority': priority,
        'change': change,
        'percent_change': percentChange,
        'day_high': dayHigh,
        'day_low': dayLow,
        'volume': volume,
        'predicted_direction': predictedDirection,
        'predicted_target': predictedTarget,
        'predicted_confidence': predictedConfidence,
      };
}
