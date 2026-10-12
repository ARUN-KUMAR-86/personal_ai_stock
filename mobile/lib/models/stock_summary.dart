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
  });

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
      };
}
