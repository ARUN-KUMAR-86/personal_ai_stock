class StockAlert {
  final int id;
  final String symbol;
  final String exchange;
  final String alertType;
  final String title;
  final String message;
  final double? price;
  bool isRead;
  final bool sentToFcm;
  final DateTime createdAt;

  // Trade Alert Approval Fields
  final String action;
  final double suggestedInvestment;
  final int estimatedQuantity;
  final double estimatedOrderValue;
  final String? reason;
  final String riskLevel;
  final double? stopLoss;
  final double? target;
  String status;
  final String? orderId;
  final bool brokerVerified;

  StockAlert({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.alertType,
    required this.title,
    required this.message,
    this.price,
    required this.isRead,
    required this.sentToFcm,
    required this.createdAt,
    this.action = 'BUY',
    this.suggestedInvestment = 100.0,
    this.estimatedQuantity = 1,
    this.estimatedOrderValue = 100.0,
    this.reason,
    this.riskLevel = 'Medium',
    this.stopLoss,
    this.target,
    this.status = 'PENDING_APPROVAL',
    this.orderId,
    this.brokerVerified = false,
  });

  bool get isTradeAlert => alertType == 'TRADE_ALERT';
  bool get isPendingApproval => isTradeAlert && status == 'PENDING_APPROVAL';

  factory StockAlert.fromJson(Map<String, dynamic> json) {
    return StockAlert(
      id: json['id'] ?? 0,
      symbol: json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      alertType: json['alert_type'] ?? 'INFO',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      isRead: json['is_read'] ?? false,
      sentToFcm: json['sent_to_fcm'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      action: json['action'] ?? 'BUY',
      suggestedInvestment: json['suggested_investment'] != null ? (json['suggested_investment'] as num).toDouble() : 100.0,
      estimatedQuantity: json['estimated_quantity'] ?? 1,
      estimatedOrderValue: json['estimated_order_value'] != null ? (json['estimated_order_value'] as num).toDouble() : 100.0,
      reason: json['reason'],
      riskLevel: json['risk_level'] ?? 'Medium',
      stopLoss: json['stop_loss'] != null ? (json['stop_loss'] as num).toDouble() : null,
      target: json['target'] != null ? (json['target'] as num).toDouble() : null,
      status: json['status'] ?? 'PENDING_APPROVAL',
      orderId: json['order_id'],
      brokerVerified: json['broker_verified'] ?? false,
    );
  }
}
