class BrokerFunds {
  final String brokerName;
  final bool isConnected;
  final double availableFunds;
  final double unsettledFunds;
  final double withdrawableFunds;
  final String currency;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  BrokerFunds({
    required this.brokerName,
    required this.isConnected,
    required this.availableFunds,
    required this.unsettledFunds,
    required this.withdrawableFunds,
    required this.currency,
    this.lastSyncedAt,
    this.errorMessage,
  });

  factory BrokerFunds.fromJson(Map<String, dynamic> json) {
    return BrokerFunds(
      brokerName: json['broker_name'] ?? 'GROWW',
      isConnected: json['is_connected'] ?? false,
      availableFunds: (json['available_funds'] as num?)?.toDouble() ?? 0.0,
      unsettledFunds: (json['unsettled_funds'] as num?)?.toDouble() ?? 0.0,
      withdrawableFunds: (json['withdrawable_funds'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'INR',
      lastSyncedAt: json['last_synced_at'] != null ? DateTime.tryParse(json['last_synced_at']) : null,
      errorMessage: json['error_message'],
    );
  }
}
