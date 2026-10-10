class Position {
  final int id;
  final String symbol;
  final String exchange;
  final int quantity;
  final double avgEntryPrice;
  final double currentPrice;
  final double? stopLoss;
  final double? target;
  final double unrealizedPnl;
  final double realizedPnl;
  final double fees;
  final bool isOpen;

  Position({
    required this.id,
    required this.symbol,
    required this.exchange,
    required this.quantity,
    required this.avgEntryPrice,
    required this.currentPrice,
    this.stopLoss,
    this.target,
    required this.unrealizedPnl,
    required this.realizedPnl,
    required this.fees,
    required this.isOpen,
  });

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id'] ?? 0,
      symbol: json['symbol'] ?? '',
      exchange: json['exchange'] ?? 'NSE',
      quantity: json['quantity'] ?? 0,
      avgEntryPrice: (json['avg_entry_price'] as num).toDouble(),
      currentPrice: (json['current_price'] as num).toDouble(),
      stopLoss: json['stop_loss'] != null ? (json['stop_loss'] as num).toDouble() : null,
      target: json['target'] != null ? (json['target'] as num).toDouble() : null,
      unrealizedPnl: (json['unrealized_pnl'] as num).toDouble(),
      realizedPnl: (json['realized_pnl'] as num).toDouble(),
      fees: (json['fees'] as num).toDouble(),
      isOpen: json['is_open'] ?? true,
    );
  }
}

class PortfolioSummary {
  final double totalPortfolioValue;
  final double totalInvestedValue;
  final double totalUnrealizedPnl;
  final double totalRealizedPnl;
  final int openPositionsCount;
  final double portfolioExposurePct;
  final List<Position> positions;

  PortfolioSummary({
    required this.totalPortfolioValue,
    required this.totalInvestedValue,
    required this.totalUnrealizedPnl,
    required this.totalRealizedPnl,
    required this.openPositionsCount,
    required this.portfolioExposurePct,
    required this.positions,
  });

  factory PortfolioSummary.fromJson(Map<String, dynamic> json) {
    var rawPositions = json['positions'] as List? ?? [];
    return PortfolioSummary(
      totalPortfolioValue: (json['total_portfolio_value'] as num).toDouble(),
      totalInvestedValue: (json['total_invested_value'] as num).toDouble(),
      totalUnrealizedPnl: (json['total_unrealized_pnl'] as num).toDouble(),
      totalRealizedPnl: (json['total_realized_pnl'] as num).toDouble(),
      openPositionsCount: json['open_positions_count'] ?? 0,
      portfolioExposurePct: (json['portfolio_exposure_pct'] as num).toDouble(),
      positions: rawPositions.map((p) => Position.fromJson(p)).toList(),
    );
  }
}
