import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../state/app_state.dart';
import '../../widgets/groww_login_dialog.dart';

/// Indian Equity Investment & Risk Sizing Card.
/// Implements Indian statutory and broker levies:
/// - STT: 0.1% on delivery buy/sell
/// - Brokerage: ₹20 or 0.05%
/// - Exchange/SEBI/Stamp: ~0.02%
/// - Depository Participant (DP) Charges: ₹15.93 on sell
/// - Full Groww broker login & available margin integration
class IndianOrderCalculationCard extends StatelessWidget {
  final double currentPrice;
  final TextEditingController amountController;
  final TextEditingController stopLossController;
  final TextEditingController targetController;
  final OrderCalculation? calculation;
  final VoidCallback onAmountChanged;
  final Function(int) onAdjustShares;
  final VoidCallback onBuyTapped;

  const IndianOrderCalculationCard({
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

  /// Computes granular Indian equity delivery charges
  static Map<String, double> computeIndianCharges({
    required double investmentAmount,
    required double targetProceeds,
    required int sharesCount,
  }) {
    if (investmentAmount <= 0 || sharesCount <= 0) {
      return {'brokerage': 0.0, 'stt': 0.0, 'dp_charges': 0.0, 'turnover_stamp': 0.0, 'total': 0.0};
    }
    // Brokerage: ₹20 max or 0.05%
    final buyBrokerage = (investmentAmount * 0.0005).clamp(0.0, 20.0);
    final sellBrokerage = (targetProceeds * 0.0005).clamp(0.0, 20.0);
    final totalBrokerage = buyBrokerage + sellBrokerage;

    // STT: 0.1% buy + 0.1% sell
    final buyStt = investmentAmount * 0.001;
    final sellStt = targetProceeds * 0.001;
    final totalStt = buyStt + sellStt;

    // DP charges: ₹15.93 flat per company on delivery sell
    const dpCharges = 15.93;

    // Stamp duty (0.015% buy) + Exchange turnover (0.003%) + GST
    final turnoverStamp = (investmentAmount * 0.0002) + (targetProceeds * 0.0001);

    final total = totalBrokerage + totalStt + dpCharges + turnoverStamp;
    return {
      'brokerage': totalBrokerage,
      'stt': totalStt,
      'dp_charges': dpCharges,
      'turnover_stamp': turnoverStamp,
      'total': total,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isGrowwConn = state.isGrowwConnected;
    final brokerMargin = state.funds?.availableFunds ?? 100000.0;

    final enteredAmount = double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
    final sharesCount = currentPrice > 0 ? (enteredAmount / currentPrice).floor() : 0;
    final isBelowMin = enteredAmount > 0 && sharesCount < 1;

    final targetVal = (double.tryParse(targetController.text) ?? (currentPrice * 1.05)) * (sharesCount > 0 ? sharesCount : 1);
    final inCharges = computeIndianCharges(
      investmentAmount: enteredAmount,
      targetProceeds: targetVal,
      sharesCount: sharesCount > 0 ? sharesCount : 1,
    );

    final profitNet = calculation?.potentialProfitNet ?? (targetVal - enteredAmount - inCharges['total']!);
    final profitPct = enteredAmount > 0 ? (profitNet / enteredAmount) * 100 : 0.0;
    final rrRatio = calculation?.riskRewardRatio ?? 2.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A202C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBelowMin ? Colors.amberAccent.withOpacity(0.5) : Colors.tealAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Groww Status / In-App Login Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, color: Colors.tealAccent, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'INDIAN INVESTMENT & RISK SIZING',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => GrowwLoginDialog.show(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGrowwConn ? Colors.teal.withOpacity(0.2) : Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isGrowwConn ? Colors.tealAccent.withOpacity(0.4) : Colors.lightBlueAccent.withOpacity(0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance,
                        size: 12,
                        color: isGrowwConn ? Colors.tealAccent : Colors.lightBlueAccent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isGrowwConn ? 'Groww: ₹${brokerMargin.toStringAsFixed(0)}' : 'Log In to Groww',
                        style: TextStyle(
                          color: isGrowwConn ? Colors.tealAccent : Colors.lightBlueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Amount Field & Stepper
          const Text('Investment Amount (₹ INR):', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold),
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

          // Quick Presets: ₹5000, ₹10000, ₹25000, ₹50000
          Wrap(
            spacing: 8,
            children: [5000, 10000, 25000, 50000].map((preset) {
              return ActionChip(
                backgroundColor: const Color(0xFF131722),
                side: const BorderSide(color: Colors.white12),
                label: Text('₹$preset', style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                    const Text('Stop-Loss (₹):', style: TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: stopLossController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
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
                    const Text('Target (₹):', style: TextStyle(color: Colors.greenAccent, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
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

          // Indian Statutory Charges Breakdown
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
                    Text('Indian Brokerage & Statutory Taxes', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('NSE Delivery', style: TextStyle(color: Colors.tealAccent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white10, height: 16),
                _feeRow('Brokerage (Buy + Sell max ₹40)', '₹${inCharges["brokerage"]!.toStringAsFixed(2)}'),
                _feeRow('Securities Transaction Tax (STT 0.1%)', '₹${inCharges["stt"]!.toStringAsFixed(2)}'),
                _feeRow('Depository Participant (DP) Levy', '₹${inCharges["dp_charges"]!.toStringAsFixed(2)}'),
                _feeRow('Stamp Duty & Exchange Turnover', '₹${inCharges["turnover_stamp"]!.toStringAsFixed(2)}'),
                const Divider(color: Colors.white10, height: 16),
                _feeRow('Estimated Roundtrip Taxes', '₹${inCharges["total"]!.toStringAsFixed(2)}', isBold: true),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Projected Net Profit:', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      '+₹${profitNet.toStringAsFixed(2)} (+${profitPct.toStringAsFixed(1)}%)',
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
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onBuyTapped,
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text(
                'I BOUGHT THIS STOCK (GROWW)',
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
