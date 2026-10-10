import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_stock/models/market_status.dart';
import 'package:personal_ai_stock/models/stock_summary.dart';
import 'package:personal_ai_stock/models/signal.dart';
import 'package:personal_ai_stock/models/portfolio.dart';

void main() {
  group('Dart Models JSON Parsing Tests', () {
    test('MarketStatus parses correctly', () {
      final json = {
        'exchange': 'NSE',
        'status': 'OPEN',
        'reason': 'Regular trading session',
        'server_time_ist': '2026-10-10 10:15:00 IST',
        'is_open': true,
        'market_open_time': '09:15 IST',
        'market_close_time': '15:30 IST',
      };
      final status = MarketStatus.fromJson(json);
      expect(status.exchange, 'NSE');
      expect(status.status, 'OPEN');
      expect(status.isOpen, true);
    });

    test('StockSummary parses correctly', () {
      final json = {
        'symbol': 'RELIANCE',
        'exchange': 'NSE',
        'name': 'Reliance Industries Ltd',
        'sector': 'Energy',
        'latest_price': 2950.5,
        'latest_timestamp': '2026-10-10T09:30:00Z',
        'is_live': false,
        'latest_signal': 'BUY WATCH',
        'signal_strength': 85.0,
      };
      final stock = StockSummary.fromJson(json);
      expect(stock.symbol, 'RELIANCE');
      expect(stock.latestPrice, 2950.5);
      expect(stock.latestSignal, 'BUY WATCH');
      expect(stock.signalStrength, 85.0);
    });

    test('StockSignal parses correctly', () {
      final json = {
        'id': 1,
        'symbol': 'TCS',
        'exchange': 'NSE',
        'timestamp': '2026-10-10T09:30:00Z',
        'signal_type': 'BUY WATCH',
        'strategy_name': 'MomentumBreakout',
        'price': 4120.0,
        'stop_loss': 4050.0,
        'target': 4260.0,
        'risk_reward': 2.0,
        'strength': 90.0,
        'explanation': 'Test breakout explanation',
      };
      final signal = StockSignal.fromJson(json);
      expect(signal.symbol, 'TCS');
      expect(signal.stopLoss, 4050.0);
      expect(signal.target, 4260.0);
      expect(signal.riskReward, 2.0);
    });

    test('PortfolioSummary parses correctly', () {
      final json = {
        'total_portfolio_value': 100000.0,
        'total_invested_value': 80000.0,
        'total_unrealized_pnl': 20000.0,
        'total_realized_pnl': 5000.0,
        'open_positions_count': 1,
        'portfolio_exposure_pct': 16.0,
        'positions': [
          {
            'id': 1,
            'symbol': 'INFY',
            'exchange': 'NSE',
            'quantity': 50,
            'avg_entry_price': 1600.0,
            'current_price': 1800.0,
            'unrealized_pnl': 10000.0,
            'realized_pnl': 0.0,
            'fees': 40.0,
            'is_open': true,
          }
        ]
      };
      final summary = PortfolioSummary.fromJson(json);
      expect(summary.totalPortfolioValue, 100000.0);
      expect(summary.positions.length, 1);
      expect(summary.positions.first.symbol, 'INFY');
      expect(summary.positions.first.quantity, 50);
    });
  });
}
