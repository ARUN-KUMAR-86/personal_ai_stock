import 'package:flutter/material.dart';
import '../../models/order.dart';

/// US Equity Investment & Risk Sizing Card.
/// Implements zero-commission US retail broker model with statutory SEC & FINRA TAF levies.
class UsOrderCalculationCard extends StatelessWidget {
  final double currentPrice;
  final TextEditingController amountController;
  final TextEditingController stopLossController;
  final TextEditingController targetController;
  final OrderCalculation? calculation;
  final VoidCallback onAmountChanged;
  final Function(int) onAdjustShares;
  final VoidCallback onBuyTapped;

  const UsOrderCalculationCard({
    super.key,
    required this.currentPrice,
    required this.amountController,
    required this.stopLossController,
    required this.targetController,
    required this.calculation,
    required this.onAmountChanged,
    required this.onAdjustShares,
    required this.onBuyTapped,
  });

  /// Calculates statutory US retail fees:
  /// - Commission: $0.00 (Zero-commission equity standard)
  /// - SEC Fee: $0.0000278 of gross sale proceeds (min $0.01)
  /// - FINRA Trading Activity Fee (TAF): $0.000166 per share (min $0.01, max $8.30)
  static Map<String, double> computeUsFees({
    required double investmentAmount,
    required double targetProceeds,
    required int sharesCount,
  }) {
    if (investmentAmount <= 0 || sharesCount <= 0) {
      return {'sec_fee': 0.0, 'finra_taf': 0.0, 'commission': 0.0, 'total': 0.0};
    }
    const commission = 0.0;
    final secFee = targetProceeds > 0 ? (targetProceeds * 0.0000278).clamp(0.01, 50.0) : 0.01;
    final finraTaf = (sharesCount * 0.000166).clamp(0.01, 8.30);
    final total = commission + secFee + finraTaf;
    return {
      'commission': commission,
      'sec_fee': secFee,
      'finra_taf': finraTaf,
      'total': total,
    };
  }

  @override
  Widget build(BuildContext context) {
    final enteredAmount = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
    final sharesCount = currentPrice > 0 ? (enteredAmount / currentPrice).floor() : 0;
    final isBelowMin = enteredAmount > 0 && sharesCount < 1;

    final targetVal = (double.tryParse(targetController.text) ?? (currentPrice * 1.05)) * (sharesCount > 0 ? sharesCount : 1);
    final usFees = computeUsFees(
      investmentAmount: enteredAmount,
      targetProceeds: targetVal,
      sharesCount: sharesCount > 0 ? sharesCount : 1,
    );

    final profitNet = calculation?.potentialProfitNet ?? (targetVal - enteredAmount - usFees['total']!);
    final profitPct = enteredAmount > 0 ? (profitNet / enteredAmount) * 100 : 0.0;
    final rrRatio = calculation?.riskRewardRatio ?? 2.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBelowMin ? Colors.amberAccent.withOpacity(0.5) : Colors.blueAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.monetization_on, color: Colors.greenAccent, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'US INVESTMENT & RISK SIZING',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                ),
                child: const Text(
                  'USD CASH / EQUITY',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Amount Field & Stepper
          const Text('Investment Amount (\$ USD):', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF131722),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isBelowMin ? Colors.amberAccent : Colors.white12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Stepper
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131722),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
                      onPressed: () => onAdjustShares(-1),
                      tooltip: 'Decrease 1 Share',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 46),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$sharesCount',
                            style: const TextStyle(color: Colors.tealAccent, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const Text('shares', style: TextStyle(color: Colors.grey, fontSize: 9)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.tealAccent, size: 18),
                      onPressed: () => onAdjustShares(1),
                      tooltip: 'Increase 1 Share',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 46),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Presets: $100, $500, $1000, $5000
          Wrap(
            spacing: 8,
            children: [100, 500, 1000, 5000].map((preset) {
              return ActionChip(
                backgroundColor: const Color(0xFF131722),
                side: const BorderSide(color: Colors.white12),
                label: Text('\$$preset', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                onPressed: () {
                  amountController.text = preset.toString();
                  onAmountChanged();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Stop Loss & Target fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stop-Loss (\$):', style: TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: stopLossController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: const TextStyle(color: Colors.redAccent, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF131722),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Target (\$):', style: TextStyle(color: Colors.greenAccent, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        prefixStyle: const TextStyle(color: Colors.greenAccent, fontSize: 14),
                        filled: true,
                        fillColor: const Color(0xFF131722),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // US Fee & Statutory Levies Breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131722),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('US Brokerage & Statutory Levies', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('Zero-Commission', style: TextStyle(color: Colors.tealAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white10, height: 16),
                _feeRow('Broker Commission', '\$0.00'),
                _feeRow('SEC Transaction Fee', '\$${usFees["sec_fee"]!.toStringAsFixed(3)}'),
                _feeRow('FINRA TAF Levy', '\$${usFees["finra_taf"]!.toStringAsFixed(3)}'),
                const Divider(color: Colors.white10, height: 16),
                _feeRow('Estimated Roundtrip Fees', '\$${usFees["total"]!.toStringAsFixed(2)}', isBold: true),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Projected Net Profit:', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      '+\$${profitNet.toStringAsFixed(2)} (+${profitPct.toStringAsFixed(1)}%)',
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Risk / Reward Ratio:', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(
                      '1 : ${rrRatio.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onBuyTapped,
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text(
                'I BOUGHT THIS STOCK (USD)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              color: isBold ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
