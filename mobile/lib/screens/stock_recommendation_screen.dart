import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/signal.dart';
import 'us_stock/us_stock_detail_screen.dart';
import 'indian_stock/indian_stock_detail_screen.dart';

/// Central Stock Recommendation & Full Details Screen Router.
///
/// Seamlessly dispatches to:
/// - [UsStockDetailScreen] in `screens/us_stock/` for NASDAQ / NYSE / US equities.
/// - [IndianStockDetailScreen] in `screens/indian_stock/` for NSE / BSE equities.
///
/// This modular router allows developers to edit US stock details in `screens/us_stock/`
/// and Indian stock details in `screens/indian_stock/` independently during Zed Dev development,
/// while guaranteeing 100% backward compatibility for all navigation callers across the app.
class StockRecommendationScreen extends StatelessWidget {
  final String symbol;
  final String exchange;
  final StockSignal? initialSignal;
  final String? initialHorizon;

  const StockRecommendationScreen({
    super.key,
    required this.symbol,
    this.exchange = 'NSE',
    this.initialSignal,
    this.initialHorizon,
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
        initialSignal: initialSignal,
        initialHorizon: initialHorizon,
      );
    } else {
      return IndianStockDetailScreen(
        symbol: symbol,
        exchange: exchange.toUpperCase() == 'US' || exchange.toUpperCase() == 'NASDAQ' || exchange.toUpperCase() == 'NYSE' ? 'NSE' : exchange,
        initialSignal: initialSignal,
        initialHorizon: initialHorizon,
      );
    }
  }
}
