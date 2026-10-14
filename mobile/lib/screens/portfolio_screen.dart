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
            icon: const Icon(Icons.bolt, color: Colors.amberAccent),
            tooltip: 'Run Auto Take Money Check',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking open positions for auto-take-money / auto-sell targets...'), duration: Duration(seconds: 1)),
              );
              final res = await state.triggerAutoSellCheck();
              await state.checkAndExecuteAutoSell();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Auto-sell check complete.'),
                    backgroundColor: Colors.teal,
                  ),
                );
              }
            },
          ),
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
            // UltraSync Low-Latency Live Status Bar
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: state.isUltraSyncActive ? Colors.tealAccent.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: state.isUltraSyncActive ? Colors.greenAccent : Colors.grey,
                      shape: BoxShape.circle,
                      boxShadow: state.isUltraSyncActive
                          ? [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.6),
                                blurRadius: 6,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    state.isUltraSyncActive ? 'ULTRASYNC 24/7' : 'SYNC PAUSED',
                    style: TextStyle(
                      color: state.isUltraSyncActive ? Colors.tealAccent : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (state.syncLatencyMs < 150 ? Colors.green : (state.syncLatencyMs < 400 ? Colors.orange : Colors.blue)).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '⚡ ${state.syncLatencyMs > 0 ? "${state.syncLatencyMs}ms" : "< 50ms"}',
                      style: TextStyle(
                        color: state.syncLatencyMs < 150 ? Colors.greenAccent : (state.syncLatencyMs < 400 ? Colors.orangeAccent : Colors.lightBlueAccent),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => state.executeUltraSync(silent: false),
                    child: const Tooltip(
                      message: 'Instant Force Sync',
                      child: Icon(Icons.flash_on, size: 16, color: Colors.amberAccent),
                    ),
                  ),
                ],
              ),
            ),

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL PORTFOLIO VALUE',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (state.safetyStatus?.executionMode == 'GROWW_LIVE' && state.isGrowwConnected)
                              ? Colors.green.withOpacity(0.15)
                              : Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (state.safetyStatus?.executionMode == 'GROWW_LIVE' && state.isGrowwConnected)
                                ? Colors.green.withOpacity(0.4)
                                : Colors.amber.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (state.safetyStatus?.executionMode == 'GROWW_LIVE' && state.isGrowwConnected)
                                  ? Icons.verified
                                  : Icons.science_outlined,
                              size: 11,
                              color: (state.safetyStatus?.executionMode == 'GROWW_LIVE' && state.isGrowwConnected)
                                  ? Colors.greenAccent
                                  : Colors.amberAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (state.safetyStatus?.executionMode == 'GROWW_LIVE' && state.isGrowwConnected)
                                  ? 'LIVE BROKER'
                                  : 'PAPER TRADING (SIMULATED)',
                              style: TextStyle(
                                color: (state.safetyStatus?.executionMode == 'GROWW_LIVE' && state.isGrowwConnected)
                                    ? Colors.greenAccent
                                    : Colors.amberAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                                  border: Border.all(
                                    color: pos.autoSellEnabled ? Colors.greenAccent.withOpacity(0.5) : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (pos.autoSellEnabled) ...[
                                      const Icon(Icons.bolt, size: 10, color: Colors.amberAccent),
                                      const SizedBox(width: 2),
                                    ],
                                    Text(
                                      pos.autoSellEnabled ? 'Auto Take Money' : 'Manual-Sell',
                                      style: TextStyle(
                                        color: pos.autoSellEnabled ? Colors.greenAccent : Colors.white70,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: pos.mode == 'PAPER'
                                      ? Colors.amber.withOpacity(0.18)
                                      : Colors.green.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pos.mode == 'PAPER' ? 'PAPER (SIMULATED)' : 'LIVE BROKER',
                                  style: TextStyle(
                                    color: pos.mode == 'PAPER' ? Colors.amberAccent : Colors.greenAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Hold: ${pos.holdingPeriodHours}h',
                                style: const TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                          if (pos.exitTriggered)
                            Flexible(
                              child: Text(
                                '⚠️ ${pos.exitReason ?? "Exit Triggered"}',
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),

            // Simulation Paper Trades Section (Always visible even if offline/restarted)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SIMULATION PAPER TRADES',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                Text(
                  '${state.paperTrades.length} Recorded',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (state.paperTrades.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off, size: 36, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'No simulation trades placed yet.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Place paper trades from any stock detail screen to test strategies risk-free.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...state.paperTrades.map((pt) {
                final isBuy = pt.action.toUpperCase() == 'BUY';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E222D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isBuy ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pt.action.toUpperCase(),
                                  style: TextStyle(
                                    color: isBuy ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                pt.symbol,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${pt.quantity} Shares',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            '₹${pt.price.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              if (pt.autoSellEnabled) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt, size: 10, color: Colors.amberAccent),
                                      SizedBox(width: 2),
                                      Text(
                                        'Auto Take Money',
                                        style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (pt.target != null)
                                Text('TP: ₹${pt.target!.toStringAsFixed(1)} ', style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
                              if (pt.stopLoss != null)
                                Text('SL: ₹${pt.stopLoss!.toStringAsFixed(1)}', style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                            ],
                          ),
                          Text(
                            '${pt.timestamp.day}/${pt.timestamp.month} ${pt.timestamp.hour.toString().padLeft(2, '0')}:${pt.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
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
