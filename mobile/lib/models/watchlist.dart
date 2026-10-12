import 'stock_summary.dart';

class WatchlistItem {
  final int id;
  final String symbol;
  final String exchange;
  final String? notes;
  final DateTime createdAt;
  final StockSummary? stock;

  WatchlistItem({
    required this.id,
    required this.symbol,
    this.exchange = 'NSE',
    this.notes,
    required this.createdAt,
    this.stock,
  });

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      exchange: (json['exchange'] ?? 'NSE').toString().toUpperCase(),
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      stock: json['stock'] != null ? StockSummary.fromJson(json['stock']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'exchange': exchange,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        if (stock != null) 'stock': stock!.toJson(),
      };
}
