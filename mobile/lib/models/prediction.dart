class StockPrediction {
  final int? id;
  final String symbol;
  final String exchange;
  final String? companyName;
  final double priceAtPrediction;
  final String predictedDirection; // BULLISH, BEARISH, NEUTRAL
  final String predictedAction;    // STRONG BUY, BUY, HOLD, SELL
  final double targetPrice;
  final double expectedGainPct;
  final double? stopLoss;
  final double confidenceScore;
  final String timeHorizon;
  final String algorithmName;
  final String? workingAlgorithm;
  final Map<String, dynamic>? algorithmMetrics;
  final String? aiPredictionSummary;
  final List<String> keyCatalysts;
  final List<String> riskAssessment;
  final String? invalidationTrigger;
  final String? modelUsed;
  final DateTime? createdAt;

  StockPrediction({
    this.id,
    required this.symbol,
    this.exchange = 'NSE',
    this.companyName,
    required this.priceAtPrediction,
    required this.predictedDirection,
    required this.predictedAction,
    required this.targetPrice,
    required this.expectedGainPct,
    this.stopLoss,
    required this.confidenceScore,
    required this.timeHorizon,
    required this.algorithmName,
    this.workingAlgorithm,
    this.algorithmMetrics,
    this.aiPredictionSummary,
    this.keyCatalysts = const [],
    this.riskAssessment = const [],
    this.invalidationTrigger,
    this.modelUsed,
    this.createdAt,
  });

  bool get isBullish => predictedDirection.toUpperCase() == 'BULLISH';
  bool get isBearish => predictedDirection.toUpperCase() == 'BEARISH';
  bool get isHighConfidence => confidenceScore >= 75.0;

  factory StockPrediction.fromJson(Map<String, dynamic> json) {
    return StockPrediction(
      id: json['id'] as int?,
      symbol: json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      companyName: json['company_name'] as String?,
      priceAtPrediction: (json['price_at_prediction'] as num?)?.toDouble() ?? 0.0,
      predictedDirection: json['predicted_direction'] ?? 'BULLISH',
      predictedAction: json['predicted_action'] ?? 'BUY',
      targetPrice: (json['target_price'] as num?)?.toDouble() ?? 0.0,
      expectedGainPct: (json['expected_gain_pct'] as num?)?.toDouble() ?? 0.0,
      stopLoss: (json['stop_loss'] as num?)?.toDouble(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 70.0,
      timeHorizon: json['time_horizon'] ?? '1-DAY (Swing)',
      algorithmName: json['algorithm_name'] ?? 'Gemini Predictive AI Confluence',
      workingAlgorithm: json['working_algorithm'] as String?,
      algorithmMetrics: json['algorithm_metrics'] is Map<String, dynamic> ? json['algorithm_metrics'] : null,
      aiPredictionSummary: json['ai_prediction_summary'] as String?,
      keyCatalysts: (json['key_catalysts'] as List?)?.map((e) => e.toString()).toList() ?? [],
      riskAssessment: (json['risk_assessment'] as List?)?.map((e) => e.toString()).toList() ?? [],
      invalidationTrigger: json['invalidation_trigger'] as String?,
      modelUsed: json['model_used'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'exchange': exchange,
        'company_name': companyName,
        'price_at_prediction': priceAtPrediction,
        'predicted_direction': predictedDirection,
        'predicted_action': predictedAction,
        'target_price': targetPrice,
        'expected_gain_pct': expectedGainPct,
        'stop_loss': stopLoss,
        'confidence_score': confidenceScore,
        'time_horizon': timeHorizon,
        'algorithm_name': algorithmName,
        'working_algorithm': workingAlgorithm,
        'algorithm_metrics': algorithmMetrics,
        'ai_prediction_summary': aiPredictionSummary,
        'key_catalysts': keyCatalysts,
        'risk_assessment': riskAssessment,
        'invalidation_trigger': invalidationTrigger,
        'model_used': modelUsed,
        'created_at': createdAt?.toIso8601String(),
      };
}
