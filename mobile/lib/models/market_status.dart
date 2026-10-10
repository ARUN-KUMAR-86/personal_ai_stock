class MarketStatus {
  final String exchange;
  final String status;
  final String reason;
  final String serverTimeIst;
  final bool isOpen;
  final String marketOpenTime;
  final String marketCloseTime;

  MarketStatus({
    required this.exchange,
    required this.status,
    required this.reason,
    required this.serverTimeIst,
    required this.isOpen,
    required this.marketOpenTime,
    required this.marketCloseTime,
  });

  factory MarketStatus.fromJson(Map<String, dynamic> json) {
    return MarketStatus(
      exchange: json['exchange'] ?? 'NSE',
      status: json['status'] ?? 'CLOSED',
      reason: json['reason'] ?? '',
      serverTimeIst: json['server_time_ist'] ?? '',
      isOpen: json['is_open'] ?? false,
      marketOpenTime: json['market_open_time'] ?? '09:15 IST',
      marketCloseTime: json['market_close_time'] ?? '15:30 IST',
    );
  }
}
