import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_stock/models/market_status.dart';
import 'package:personal_ai_stock/models/stock_summary.dart';
import 'package:personal_ai_stock/models/signal.dart';
import 'package:personal_ai_stock/models/portfolio.dart';
import 'package:personal_ai_stock/models/order.dart';
import 'package:personal_ai_stock/models/watchlist.dart';
import 'package:personal_ai_stock/models/trading_control.dart';
import 'package:personal_ai_stock/models/alert.dart';

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

    test('StockSignal with AI thesis and risk factors parses correctly', () {
      final json = {
        'id': 2,
        'symbol': 'RELIANCE',
        'exchange': 'NSE',
        'timestamp': '2026-10-10T09:30:00Z',
        'signal_type': 'BUY WATCH',
        'strategy_name': 'MomentumBreakout',
        'price': 2950.0,
        'stop_loss': 2890.0,
        'target': 3070.0,
        'strength': 85.0,
        'explanation': 'Old explanation',
        'ai_thesis': {
          'headline': 'RELIANCE: Bullish Momentum Breakout',
          'investment_thesis': 'Deep institutional accumulation thesis.',
          'catalysts': ['Surge in relative volume', 'Bullish moving average stack'],
          'risk_factors': ['Overhead resistance at ₹3010', 'ATR daily volatility ±₹42'],
          'technical_summary': {
            'trend': 'Strong Uptrend',
            'momentum': 'Bullish Acceleration',
            'volume_profile': 'Accumulation',
            'volatility': 'Moderate ATR',
          },
          'tactical_plan': {
            'entry_zone': '₹2940 - ₹2960',
            'stop_loss': '₹2890',
            'target_1': '₹3070',
            'time_horizon': '24 to 48 Hours',
          },
          'model_used': 'Gemini 1.5 Flash',
        },
      };
      final signal = StockSignal.fromJson(json);
      expect(signal.aiHeadline, 'RELIANCE: Bullish Momentum Breakout');
      expect(signal.aiInvestmentThesis, 'Deep institutional accumulation thesis.');
      expect(signal.aiCatalysts.length, 2);
      expect(signal.aiRiskFactors.length, 2);
      expect(signal.aiModelUsed, 'Gemini 1.5 Flash');
      expect(signal.aiTechnicalSummary!['trend'], 'Strong Uptrend');
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

    test('OrderCalculation parses correctly', () {
      final json = {
        'is_valid': true,
        'shares_quantity': 10,
        'verified_entry_price': 500.0,
        'estimated_investment': 5000.0,
        'total_outlay': 5025.5,
        'buy_charges': {'brokerage': 2.5, 'stt': 5.0},
        'roundtrip_target_charges': 35.0,
        'roundtrip_sl_charges': 34.0,
        'potential_profit_net': 165.0,
        'potential_profit_pct': 3.3,
        'potential_loss_net': -134.0,
        'potential_loss_pct': -2.68,
        'risk_reward_ratio': 1.23,
        'remaining_available_funds': 94974.5,
        'holding_period_hours': 48,
        'warnings': [],
      };
      final calc = OrderCalculation.fromJson(json);
      expect(calc.isValid, true);
      expect(calc.sharesQuantity, 10);
      expect(calc.verifiedEntryPrice, 500.0);
      expect(calc.estimatedInvestment, 5000.0);
      expect(calc.potentialProfitNet, 165.0);
      expect(calc.riskRewardRatio, 1.23);
      expect(calc.holdingPeriodHours, 48);
    });

    test('PreparedBuyOrder parses correctly', () {
      final json = {
        'symbol': 'TATAMOTORS',
        'exchange': 'NSE',
        'company_name': 'Tata Motors Limited',
        'verified_current_price': 980.0,
        'price_changed': false,
        'slippage_pct': 0.0,
        'slippage_warning': null,
        'shares_quantity': 5,
        'estimated_investment': 4900.0,
        'total_charges': 15.5,
        'total_outlay': 4915.5,
        'available_funds': 50000.0,
        'stop_loss': 960.0,
        'target': 1020.0,
        'holding_period_hours': 24,
        'risk_reward_ratio': 2.0,
        'client_order_id': 'ORD-UUID-1234',
        'mode': 'PAPER',
      };
      final prep = PreparedBuyOrder.fromJson(json);
      expect(prep.symbol, 'TATAMOTORS');
      expect(prep.companyName, 'Tata Motors Limited');
      expect(prep.sharesQuantity, 5);
      expect(prep.holdingPeriodHours, 24);
      expect(prep.clientOrderId, 'ORD-UUID-1234');
      expect(prep.mode, 'PAPER');
    });

    test('ConfirmedOrder parses correctly', () {
      final json = {
        'id': 10,
        'order_id': 'ORD-ORD123',
        'client_order_id': 'CLIENT-123',
        'symbol': 'RELIANCE',
        'exchange': 'NSE',
        'transaction_type': 'BUY',
        'order_type': 'MARKET',
        'status': 'FILLED',
        'requested_quantity': 2,
        'filled_quantity': 2,
        'requested_price': 2950.0,
        'executed_price': 2951.0,
        'stop_loss': 2900.0,
        'target': 3050.0,
        'holding_period_hours': 48,
        'total_charges': 22.5,
        'mode': 'PAPER',
        'user_confirmed': true,
        'auto_sell_enabled': false,
        'broker_order_id': 'GROWW-009',
        'user_confirmed_at': '2026-10-11T10:00:00Z',
        'executed_at': '2026-10-11T10:00:02Z',
      };
      final confirmed = ConfirmedOrder.fromJson(json);
      expect(confirmed.symbol, 'RELIANCE');
      expect(confirmed.status, 'FILLED');
      expect(confirmed.filledQuantity, 2);
      expect(confirmed.userConfirmed, true);
      expect(confirmed.autoSellEnabled, false);
    });

    test('SafetyStatus parses correctly with auto_buying_allowed strictly false', () {
      final json = {
        'emergency_stop_enabled': false,
        'auto_sell_enabled': false,
        'max_position_risk_pct': 2.0,
        'max_single_stock_pct': 10.0,
        'max_portfolio_exposure_pct': 25.0,
        'execution_mode': 'PAPER',
        'auto_buying_allowed': false,
      };
      final safety = SafetyStatus.fromJson(json);
      expect(safety.emergencyStopEnabled, false);
      expect(safety.autoSellEnabled, false);
      expect(safety.autoBuyingAllowed, false);
      expect(safety.executionMode, 'PAPER');
    });

    test('WatchlistItem parses and serializes correctly', () {
      final json = {
        'id': 42,
        'symbol': 'INFY',
        'exchange': 'NSE',
        'notes': 'High-conviction IT breakout',
        'created_at': '2026-10-11T12:00:00Z',
        'stock': {
          'symbol': 'INFY',
          'exchange': 'NSE',
          'name': 'Infosys Limited',
          'sector': 'Technology',
          'latest_price': 1950.0,
          'latest_timestamp': '2026-10-11T12:00:00Z',
          'is_live': true,
          'latest_signal': 'BUY WATCH',
          'signal_strength': 88.5,
        },
      };

      final item = WatchlistItem.fromJson(json);
      expect(item.id, 42);
      expect(item.symbol, 'INFY');
      expect(item.exchange, 'NSE');
      expect(item.notes, 'High-conviction IT breakout');
      expect(item.stock?.name, 'Infosys Limited');
      expect(item.stock?.latestPrice, 1950.0);
      expect(item.stock?.latestSignal, 'BUY WATCH');

      final serialized = item.toJson();
      expect(serialized['id'], 42);
      expect(serialized['symbol'], 'INFY');
      expect(serialized['stock']['symbol'], 'INFY');
      expect(serialized['stock']['signal_strength'], 88.5);
    });

    test('TradingControlSummary parses correctly matching wireframe', () {
      final json = {
        'groww_account_status': 'Connected*',
        'groww_account_id': 'GROWW-ARUN-PRIMARY',
        'groww_account_name': 'Arun Kumar',
        'token_expired': false,
        'account_balance': 1000.0,
        'available_funds': 1000.0,
        'trading_budget': 300.0,
        'amount_in_positions': 0.0,
        'todays_pnl': 0.0,
        'is_trading_active': true,
        'trading_mode': 'Notification + Approval',
        'max_amount_per_trade': 100.0,
        'daily_loss_limit': 50.0,
        'auto_withdraw_profits': false,
        'auto_withdraw_threshold': 100.0,
        'open_positions_count': 0,
        'pending_alerts_count': 1,
      };

      final tc = TradingControlSummary.fromJson(json);
      expect(tc.growwAccountStatus, 'Connected*');
      expect(tc.growwAccountId, 'GROWW-ARUN-PRIMARY');
      expect(tc.accountBalance, 1000.0);
      expect(tc.availableFunds, 1000.0);
      expect(tc.tradingBudget, 300.0);
      expect(tc.amountInPositions, 0.0);
      expect(tc.todaysPnl, 0.0);
      expect(tc.isTradingActive, true);
      expect(tc.tradingMode, 'Notification + Approval');
      expect(tc.maxAmountPerTrade, 100.0);
      expect(tc.dailyLossLimit, 50.0);
      expect(tc.autoWithdrawProfits, false);
    });

    test('FundTransaction parses correctly', () {
      final json = {
        'id': 1,
        'transaction_type': 'DEPOSIT',
        'amount': 500.0,
        'note': 'Added funds via UPI',
        'created_at': '2026-10-13T10:00:00Z',
      };

      final tx = FundTransaction.fromJson(json);
      expect(tx.id, 1);
      expect(tx.transactionType, 'DEPOSIT');
      expect(tx.amount, 500.0);
      expect(tx.note, 'Added funds via UPI');
    });

    test('StockAlert trade alert fields and pending approval status parse correctly', () {
      final json = {
        'id': 10,
        'symbol': 'TATASTEEL',
        'exchange': 'NSE',
        'alert_type': 'TRADE_ALERT',
        'title': 'AI Trade Alert: BUY TATASTEEL',
        'message': 'Suggested investment ₹100',
        'price': 155.0,
        'is_read': false,
        'sent_to_fcm': true,
        'created_at': '2026-10-13T11:00:00Z',
        'action': 'BUY',
        'suggested_investment': 100.0,
        'estimated_quantity': 1,
        'estimated_order_value': 100.0,
        'reason': 'AI breakout signal with 2.2 R:R',
        'risk_level': 'Medium',
        'stop_loss': 150.0,
        'target': 165.0,
        'status': 'PENDING_APPROVAL',
        'broker_verified': false,
      };

      final alert = StockAlert.fromJson(json);
      expect(alert.symbol, 'TATASTEEL');
      expect(alert.isTradeAlert, true);
      expect(alert.isPendingApproval, true);
      expect(alert.action, 'BUY');
      expect(alert.suggestedInvestment, 100.0);
      expect(alert.estimatedQuantity, 1);
      expect(alert.estimatedOrderValue, 100.0);
      expect(alert.stopLoss, 150.0);
      expect(alert.target, 165.0);
      expect(alert.status, 'PENDING_APPROVAL');
    });
  });
}
