import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'us_stock/us_stock_detail_screen.dart';
import 'indian_stock/indian_stock_detail_screen.dart';

/// Central Stock Detail Screen Dispatcher.
/// Automatically routes to the dedicated US Stock or Indian Stock full details screen.
class StockDetailScreen extends StatelessWidget {
  final String symbol;
  final String exchange;

  const StockDetailScreen({
    super.key,
    required this.symbol,
    required this.exchange,
  });

  bool _isUsMarket(BuildContext context) {
    final ex = exchange.trim().toUpperCase();
    if (ex == 'US' || ex == 'NASDAQ' || ex == 'NYSE' || ex == 'AMEX') {
      return true;
    }
    if (ex == 'NSE' || ex == 'BSE') {
      return false;
    }
    return context.read<AppState>().isUSMarket;
  }

  @override
  Widget build(BuildContext context) {
    if (_isUsMarket(context)) {
      return UsStockDetailScreen(
        symbol: symbol,
        exchange: exchange.toUpperCase() == 'NSE' || exchange.toUpperCase() == 'BSE' ? 'NASDAQ' : exchange,
      );
    } else {
      return IndianStockDetailScreen(
        symbol: symbol,
        exchange: exchange.toUpperCase() == 'US' || exchange.toUpperCase() == 'NASDAQ' || exchange.toUpperCase() == 'NYSE' ? 'NSE' : exchange,
      );
    }
  }
}
