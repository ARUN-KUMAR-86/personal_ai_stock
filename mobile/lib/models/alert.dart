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
  });

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
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
