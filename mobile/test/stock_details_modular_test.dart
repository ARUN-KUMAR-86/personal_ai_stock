import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_stock/screens/us_stock/us_order_calculation_card.dart';
import 'package:personal_ai_stock/screens/us_stock/us_stock_metrics_card.dart';
import 'package:personal_ai_stock/screens/indian_stock/indian_order_calculation_card.dart';
import 'package:personal_ai_stock/screens/indian_stock/indian_stock_metrics_card.dart';

void main() {
  group('Modular US Stock Details Tests', () {
    test('US fee computation adheres to SEC & FINRA zero-commission standard', () {
      final fees = UsOrderCalculationCard.computeUsFees(
        investmentAmount: 1000.0,
        targetProceeds: 1100.0,
        sharesCount: 10,
      );

      expect(fees['commission'], equals(0.0));
      expect(fees['sec_fee']!, greaterThanOrEqualTo(0.01));
      expect(fees['finra_taf']!, greaterThanOrEqualTo(0.01));
      expect(fees['total']!, equals(fees['commission']! + fees['sec_fee']! + fees['finra_taf']!));
    });

    test('US Market Cap formatting in \$B and \$T', () {
      expect(UsStockMetricsCard.formatUsMarketCap(3.2e12), equals('\$3.20T'));
      expect(UsStockMetricsCard.formatUsMarketCap(850e9), equals('\$850.00B'));
      expect(UsStockMetricsCard.formatUsMarketCap(500e6), equals('\$500.00M'));
      expect(UsStockMetricsCard.formatUsMarketCap(null), equals('N/A'));
    });

    test('US Market Session status returns valid structure', () {
      final session = UsStockMetricsCard.getUsMarketSessionStatus();
      expect(session.containsKey('status'), isTrue);
      expect(session.containsKey('label'), isTrue);
      expect(session.containsKey('color'), isTrue);
    });
  });

  group('Modular Indian Stock Details Tests', () {
    test('Indian charges computation includes STT, DP charges (₹15.93), and brokerage', () {
      final charges = IndianOrderCalculationCard.computeIndianCharges(
        investmentAmount: 10000.0,
        targetProceeds: 11000.0,
        sharesCount: 50,
      );

      expect(charges['stt']!, equals(21.0)); // 10000*0.001 (10) + 11000*0.001 (11) = 21
      expect(charges['dp_charges'], equals(15.93));
      expect(charges['brokerage']!, greaterThan(0.0));
      expect(charges['total']!, greaterThan(36.93));
    });

    test('Indian Market Cap formatting in ₹ Crores', () {
      expect(IndianStockMetricsCard.formatIndianMarketCap(1.5e12), equals('₹1.50 Lakh Cr')); // 1.5 Lakh Crore
      expect(IndianStockMetricsCard.formatIndianMarketCap(500000000), equals('₹50 Cr'));
      expect(IndianStockMetricsCard.formatIndianMarketCap(null), equals('N/A'));
    });

    test('Indian Market Session status returns valid structure', () {
      final session = IndianStockMetricsCard.getIndianMarketSessionStatus();
      expect(session.containsKey('status'), isTrue);
      expect(session.containsKey('label'), isTrue);
      expect(session.containsKey('color'), isTrue);
    });
  });
}
