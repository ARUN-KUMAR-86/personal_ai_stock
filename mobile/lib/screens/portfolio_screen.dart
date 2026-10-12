import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/portfolio.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  void _showPositionEditDialog(BuildContext context, Position pos) {
    final slController = TextEditingController(text: pos.stopLoss?.toStringAsFixed(2) ?? '');
    final tpController = TextEditingController(text: pos.target?.toStringAsFixed(2) ?? '');
    int holdingHours = pos.holdingPeriodHours;
    bool autoSell = pos.autoSellEnabled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monitor Settings: ${pos.symbol}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: slController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Stop-Loss (₹)',
                            labelStyle: TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF131722),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: tpController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Target (₹)',
                            labelStyle: TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: Color(0xFF131722),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Holding Period:', style: TextStyle(color: Colors.white70)),
                      Row(
                        children: [24, 48].map((h) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text('${h}h'),
                              selected: holdingHours == h,
                              selectedColor: Colors.blueAccent.withOpacity(0.3),
                              onSelected: (val) {
                                if (val) setModalState(() => holdingHours = h);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Automatic Selling on Exit', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Submits sell order automatically when criteria are triggered.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    value: autoSell,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => setModalState(() => autoSell = val),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final sl = double.tryParse(slController.text);
                        final tp = double.tryParse(tpController.text);
                        await context.read<AppState>().updatePositionMonitoring(
                              pos.id,
                              stopLoss: sl,
                              target: tp,
                              holdingPeriodHours: holdingHours,
                              autoSellEnabled: autoSell,
                            );
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Monitoring Parameters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final portfolio = state.portfolio;

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: const Text('PORTFOLIO & RISK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_alt),
            tooltip: 'Run Position Monitor Check',
            onPressed: () async {
              await state.checkPositionMonitoring();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Position monitor pass executed.'), duration: Duration(seconds: 2)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => state.refreshAll(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Portfolio Summary Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E222D), Color(0xFF161923)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL PORTFOLIO VALUE',
                      style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(
                    '₹${portfolio?.totalPortfolioValue.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Invested Capital', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(
                            '₹${portfolio?.totalInvestedValue.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Unrealized P&L', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(
                            '${(portfolio?.totalUnrealizedPnl ?? 0) >= 0 ? '+' : ''}₹${portfolio?.totalUnrealizedPnl.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                              color: (portfolio?.totalUnrealizedPnl ?? 0) >= 0 ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Portfolio Exposure', style: TextStyle(color: Colors.grey, fontSize: 10)),
                          const SizedBox(height: 2),
                          Text(
                            '${portfolio?.portfolioExposurePct.toStringAsFixed(1) ?? '0.0'}%',
                            style: TextStyle(
                              color: (portfolio?.portfolioExposurePct ?? 0) > 25.0 ? Colors.orangeAccent : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Positions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ACTIVE MONITORED POSITIONS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                Text(
                  '${portfolio?.positions.length ?? 0} Open',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (portfolio == null || portfolio.positions.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade600),
                    const SizedBox(height: 12),
                    Text(
                      'No open monitored positions.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confirm a stock recommendation to automatically register positions for monitoring.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...portfolio.positions.map((pos) {
                final isProfit = pos.unrealizedPnl >= 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E222D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: pos.exitTriggered
                          ? Colors.orangeAccent
                          : Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                pos.symbol,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${pos.quantity} Qty',
                                    style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pos.autoSellEnabled ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pos.autoSellEnabled ? 'Auto-Sell' : 'Manual-Sell',
                                  style: TextStyle(
                                    color: pos.autoSellEnabled ? Colors.greenAccent : Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                '${isProfit ? '+' : ''}₹${pos.unrealizedPnl.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isProfit ? Colors.greenAccent : Colors.redAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings, size: 18, color: Colors.grey),
                                onPressed: () => _showPositionEditDialog(context, pos),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPosMetric('Avg Price', '₹${pos.avgEntryPrice.toStringAsFixed(2)}'),
                          _buildPosMetric('Current Price', '₹${pos.currentPrice.toStringAsFixed(2)}'),
                          _buildPosMetric('Stop Loss', pos.stopLoss != null ? '₹${pos.stopLoss}' : 'None', color: Colors.redAccent),
                          _buildPosMetric('Target', pos.target != null ? '₹${pos.target}' : 'None', color: Colors.greenAccent),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hold: ${pos.holdingPeriodHours}h | Mode: ${pos.mode}',
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                          if (pos.exitTriggered)
                            Text(
                              '⚠️ ${pos.exitReason ?? "Exit Triggered"}',
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildPosMetric(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color ?? Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
