import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trading_control.dart';
import '../state/app_state.dart';
import '../widgets/trade_alert_card.dart';
import '../widgets/groww_login_dialog.dart';

class TradingControlScreen extends StatefulWidget {
  const TradingControlScreen({super.key});

  @override
  State<TradingControlScreen> createState() => _TradingControlScreenState();
}

class _TradingControlScreenState extends State<TradingControlScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshTradingControl();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tc = state.tradingControl;
    final isTradingActive = tc?.isTradingActive ?? true;
    final isLiveBroker = state.isGrowwConnected;
    final accountStatusText = tc?.growwAccountStatus ?? (isLiveBroker ? 'Connected' : 'Not Connected (Paper Mode)');

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: const Text(
          'PERSONAL AI STOCK',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            letterSpacing: 0.8,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Sync Trading Controls',
            onPressed: () => state.refreshTradingControl(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshTradingControl(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ──────────────────────────
            // Trading Control Main Card
            // ──────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Header
                  const Center(
                    child: Text(
                      'PERSONAL AI STOCK',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24, thickness: 1),
                  const SizedBox(height: 12),

                  // 1. Groww Account Status Row
                  _buildControlRow(
                    label: 'Groww Account',
                    child: InkWell(
                      onTap: () => _showAccountDetailsSheet(context, tc),
                      borderRadius: BorderRadius.circular(6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getAccountStatusColor(accountStatusText),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            accountStatusText,
                            style: TextStyle(
                              color: _getAccountStatusColor(accountStatusText),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Account Balance
                  _buildControlRow(
                    label: 'Account Balance',
                    value: '₹${(tc?.accountBalance ?? 1000.0).toStringAsFixed(2)}',
                    valueColor: Colors.white,
                  ),
                  const SizedBox(height: 10),

                  // 3. Available Funds
                  _buildControlRow(
                    label: 'Available Funds',
                    value: '₹${(tc?.availableFunds ?? 1000.0).toStringAsFixed(2)}',
                    valueColor: Colors.white,
                  ),
                  const SizedBox(height: 10),

                  // 4. Trading Budget
                  _buildControlRow(
                    label: 'Trading Budget',
                    child: InkWell(
                      onTap: () => _showBudgetSelectionDialog(context, tc?.tradingBudget ?? 300.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${(tc?.tradingBudget ?? 300.0).toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 13, color: Colors.lightBlueAccent),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 5. Amount in Positions
                  _buildControlRow(
                    label: 'Amount in Positions',
                    value: '₹${(tc?.amountInPositions ?? 0.0).toStringAsFixed(2)}',
                    valueColor: (tc?.amountInPositions ?? 0) > 0 ? Colors.amberAccent : Colors.white70,
                  ),
                  const SizedBox(height: 10),

                  // 6. Today's P/L
                  _buildControlRow(
                    label: "Today's P/L",
                    value: '${(tc?.todaysPnl ?? 0) >= 0 ? "+" : ""}₹${(tc?.todaysPnl ?? 0.0).toStringAsFixed(2)}',
                    valueColor: (tc?.todaysPnl ?? 0) >= 0 ? Colors.greenAccent : Colors.redAccent,
                    isBold: true,
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),

                  // ──────────────────────────
                  // Start / Stop Trading Buttons
                  // ──────────────────────────
                  Row(
                    children: [
                      // Start Trading
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isTradingActive ? Colors.green.shade700 : const Color(0xFF2A2E39),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: isTradingActive ? 4 : 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isTradingActive ? Colors.greenAccent : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onPressed: state.isTradingToggling || isTradingActive
                              ? null
                              : () async {
                                  await state.startTrading();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Trading started! AI market monitoring is now ACTIVE.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                          icon: isTradingActive
                              ? const Icon(Icons.play_circle_fill, size: 18, color: Colors.greenAccent)
                              : const Icon(Icons.play_arrow, size: 18),
                          label: const Text(
                            'Start Trading',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Stop Trading
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !isTradingActive ? Colors.red.shade800 : const Color(0xFF2A2E39),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: !isTradingActive ? 4 : 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: !isTradingActive ? Colors.redAccent : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onPressed: state.isTradingToggling || !isTradingActive
                              ? null
                              : () async {
                                  await state.stopTrading();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Trading stopped. No new orders will be generated.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                },
                          icon: !isTradingActive
                              ? const Icon(Icons.pause_circle_filled, size: 18, color: Colors.redAccent)
                              : const Icon(Icons.pause, size: 18),
                          label: const Text(
                            'Stop Trading',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      isTradingActive
                          ? '● Market monitoring active: Scanning for opportunities'
                          : '○ Trading paused: Existing positions safely monitored',
                      style: TextStyle(
                        color: isTradingActive ? Colors.greenAccent : Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 14),

                  // ──────────────────────────
                  // Trading Mode & Risk Limits
                  // ──────────────────────────
                  // Trading Mode
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Trading Mode:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showTradingModeSelector(
                          context,
                          tc?.tradingMode ?? 'Option B: Hybrid Guard (Auto Stop-Loss)',
                        ),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.tealAccent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tc?.tradingMode ?? 'Option B: Hybrid Guard',
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Maximum Amount Per Trade
                  _buildControlRow(
                    label: 'Maximum Amount Per Trade:',
                    child: InkWell(
                      onTap: () => _showEditTradeLimitDialog(context, tc?.maxAmountPerTrade ?? 100.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${(tc?.maxAmountPerTrade ?? 100.0).toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 12, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Daily Loss Limit
                  _buildControlRow(
                    label: 'Daily Loss Limit:',
                    child: InkWell(
                      onTap: () => _showEditLossLimitDialog(context, tc?.dailyLossLimit ?? 50.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${(tc?.dailyLossLimit ?? 50.0).toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 12, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // AI Strategy Algorithm Selection
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI Algorithm:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const Spacer(),
                      InkWell(
                        onTap: () => _showAlgorithmSelectorDialog(context, state.activeAlgorithm),
                        borderRadius: BorderRadius.circular(6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amberAccent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getAlgorithmDisplayName(state.activeAlgorithm),
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit, size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Auto Take Money & Auto-Sell Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bolt, color: Colors.amberAccent, size: 14),
                              SizedBox(width: 4),
                              Text('Auto Take Money & Auto-Sell:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          Text(
                            'Liquidates at Target (+5% to +15%) or Stop-Loss',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 10),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            state.autoTakeProfit ? 'ON' : 'OFF',
                            style: TextStyle(
                              color: state.autoTakeProfit ? Colors.greenAccent : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: state.autoTakeProfit,
                            activeColor: Colors.greenAccent,
                            onChanged: (val) {
                              state.setAutoTakeProfit(val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Auto-Withdraw Profits Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Auto-Withdraw Profits:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          if (tc?.autoWithdrawProfits == true)
                            Text(
                              'Threshold: > ₹${(tc?.autoWithdrawThreshold ?? 100.0).toStringAsFixed(0)}',
                              style: const TextStyle(color: Colors.tealAccent, fontSize: 10),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            (tc?.autoWithdrawProfits == true) ? 'ON' : 'OFF',
                            style: TextStyle(
                              color: (tc?.autoWithdrawProfits == true) ? Colors.tealAccent : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: tc?.autoWithdrawProfits ?? false,
                            activeColor: Colors.tealAccent,
                            onChanged: (val) {
                              state.updateTradingSettings(autoWithdrawProfits: val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Run Auto Take Money / Auto-Sell Check Button
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        side: BorderSide(color: Colors.amberAccent.withOpacity(0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Checking open positions for auto-take-money targets...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        final res = await state.triggerAutoSellCheck();
                        await state.checkAndExecuteAutoSell();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res['message'] ?? 'Auto-sell check complete. Target & stop-loss checked.'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.bolt, size: 16),
                      label: const Text(
                        'Run Auto Take Money Check Now',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),

                  // ──────────────────────────
                  // Three Bottom Action Buttons
                  // ──────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showAccountActivitySheet(context),
                          child: const Text('Account Activity', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.lightBlueAccent,
                            side: BorderSide(color: Colors.lightBlueAccent.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showTradeAlertsSheet(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Buy/Sell Notifications', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              if (state.tradeAlerts.where((a) => a.isPendingApproval).isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.amber,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${state.tradeAlerts.where((a) => a.isPendingApproval).length}',
                                    style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showDepositWithdrawSheet(context),
                          child: const Text('Deposit/Withdrawal History', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Explanatory Note on Trading Budget vs Groww Balance
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.lightBlueAccent, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Important: Choosing ₹300 as your trading budget does not deposit ₹300 into Groww. '
                      'It only sets a limit on how much the app is allowed to allocate to trades. '
                      'Your actual Groww balance and money invested in open positions are tracked separately.',
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow({
    required String label,
    String? value,
    Widget? child,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        child ??
            Text(
              value ?? '',
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
      ],
    );
  }

  Color _getAccountStatusColor(String status) {
    if (status.startsWith('Connected') && !status.contains('Not')) return Colors.greenAccent;
    if (status.contains('Expired')) return Colors.amberAccent;
    return Colors.grey.shade400;
  }

  // ──────────────────────────
  // AI Algorithm Helper & Selector Dialog
  // ──────────────────────────

  String _getAlgorithmDisplayName(String key) {
    final clean = key.toLowerCase();
    if (clean.contains('gain') || clean.contains('maximizer')) {
      return '⚡ Highest Gain Maximizer';
    }
    if (clean.contains('momentum')) {
      return '🚀 Momentum Breakout';
    }
    if (clean.contains('reversion')) {
      return '🔁 Mean Reversion';
    }
    if (clean.contains('macd')) {
      return '📊 MACD Crossover';
    }
    return key.isEmpty ? '⚡ Highest Gain Maximizer' : key;
  }

  void _showAlgorithmSelectorDialog(BuildContext context, String currentAlgo) {
    final algorithms = [
      {
        'key': 'HighestGainMaximizer',
        'title': '⚡ Highest Gain Maximizer (Auto Take Money)',
        'badge': 'RECOMMENDED',
        'desc': 'Scans for highest percentage upside opportunities (+5% to +15% targets), enforces 1:3+ Risk/Reward, assigns RED for High Priority and GREEN for Medium Priority, and automatically sells at target to lock in maximum gains.',
        'highlight': true,
      },
      {
        'key': 'MomentumBreakout',
        'title': '🚀 Momentum Breakout',
        'badge': 'TREND',
        'desc': 'Identifies 20-day high breakouts with 2x+ volume expansion for strong continuation momentum.',
        'highlight': false,
      },
      {
        'key': 'MeanReversion',
        'title': '🔁 Mean Reversion (RSI Oversold)',
        'badge': 'SWING',
        'desc': 'Detects oversold RSI bounces (<30) consolidating near major support levels.',
        'highlight': false,
      },
      {
        'key': 'MACDCrossover',
        'title': '📊 MACD Bullish Crossover',
        'badge': 'MOMENTUM',
        'desc': 'Trades bullish MACD line crossovers above signal line with positive histogram slope.',
        'highlight': false,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select AI Trading Algorithm',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose the algorithm used by the market scanner to detect opportunities, rank priorities (Red = High, Green = Medium), and calculate auto-sell targets.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ...algorithms.map((algo) {
                    final key = algo['key'] as String;
                    final isSelected = currentAlgo.toLowerCase().contains(key.toLowerCase()) ||
                        (key == 'HighestGainMaximizer' && (currentAlgo.isEmpty || currentAlgo.toLowerCase().contains('gain')));
                    return InkWell(
                      onTap: () async {
                        await context.read<AppState>().setActiveAlgorithm(key);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Algorithm switched to ${algo['title']}! Scanner will prioritize high gain setups.'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF182838) : const Color(0xFF131722),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.amberAccent
                                : (algo['highlight'] as bool ? Colors.amberAccent.withOpacity(0.3) : Colors.white10),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    algo['title'] as String,
                                    style: TextStyle(
                                      color: isSelected ? Colors.amberAccent : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (algo['highlight'] as bool)
                                        ? Colors.amberAccent.withOpacity(0.2)
                                        : Colors.blueAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    algo['badge'] as String,
                                    style: TextStyle(
                                      color: (algo['highlight'] as bool) ? Colors.amberAccent : Colors.lightBlueAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              algo['desc'] as String,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────────
  // Dialogs & Sheets
  // ──────────────────────────

  void _showBudgetSelectionDialog(BuildContext context, double currentBudget) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Trading Budget',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sets the maximum capital allocated to trades. Does not deposit money to broker.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [100.0, 300.0, 400.0, 500.0].map((amt) {
                    final isSelected = (currentBudget - amt).abs() < 1.0;
                    return ActionChip(
                      backgroundColor: isSelected ? Colors.blueAccent : const Color(0xFF131722),
                      side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.white24),
                      label: Text(
                        '₹${amt.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onPressed: () {
                        context.read<AppState>().updateTradingBudget(amt);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.tune, color: Colors.lightBlueAccent),
                  title: const Text('Custom Budget Amount', style: TextStyle(color: Colors.white, fontSize: 13)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showCustomBudgetPrompt(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomBudgetPrompt(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        title: const Text('Set Custom Budget (₹)', style: TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. 750',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                context.read<AppState>().updateTradingBudget(val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTradingModeSelector(BuildContext context, String currentMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Live Trading Automation Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildModeTile(
                  ctx: ctx,
                  title: 'Option B: Hybrid Guard (Selected)',
                  subtitle: 'Manual 1-Tap Buy Approval + Auto Stop-Loss Exit if market drops when away from phone.',
                  modeKey: 'Option B: Hybrid Guard (Auto Stop-Loss)',
                  isSelected: currentMode.contains('Hybrid Guard') || currentMode.contains('Option B'),
                  isActiveBadge: true,
                ),
                const SizedBox(height: 8),
                _buildModeTile(
                  ctx: ctx,
                  title: 'Option A: Notification + 1-Tap Approval',
                  subtitle: '100% manual control. Every buy and sell order requires your explicit button tap.',
                  modeKey: 'Option A: Notification + 1-Tap Approval',
                  isSelected: currentMode.contains('Option A') || currentMode == 'Notification + Approval',
                  isActiveBadge: false,
                ),
                const SizedBox(height: 8),
                _buildModeTile(
                  ctx: ctx,
                  title: 'Option C: Advisory Alert Only',
                  subtitle: 'Signal notifications and thesis only. Place orders manually in Groww app.',
                  modeKey: 'Option C: Advisory Alert Only',
                  isSelected: currentMode.contains('Option C'),
                  isActiveBadge: false,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeTile({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required String modeKey,
    required bool isSelected,
    required bool isActiveBadge,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        context.read<AppState>().updateTradingSettings(tradingMode: modeKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trading Mode updated to: $title'),
            backgroundColor: Colors.teal.shade800,
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal.withOpacity(0.15) : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.tealAccent : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.tealAccent : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? Colors.tealAccent : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isActiveBadge) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTradeLimitDialog(BuildContext context, double currentLimit) {
    final controller = TextEditingController(text: currentLimit.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        title: const Text('Maximum Amount Per Trade (₹)', style: TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'e.g. 100'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                context.read<AppState>().updateTradingSettings(maxAmountPerTrade: val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditLossLimitDialog(BuildContext context, double currentLimit) {
    final controller = TextEditingController(text: currentLimit.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        title: const Text('Daily Loss Limit (₹)', style: TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'e.g. 50'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                context.read<AppState>().updateTradingSettings(dailyLossLimit: val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAccountDetailsSheet(BuildContext context, TradingControlSummary? tc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Groww Account Security & Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Authorized Account: ${tc?.growwAccountId ?? "GROWW-ARUN-PRIMARY"} (${tc?.growwAccountName ?? "Arun Kumar"})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                const Text('Daily Expiry Policy: Groww access tokens expire daily for security. Permanent unauthorized access is prohibited.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final ok = await context.read<AppState>().renewGrowwSession();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Groww daily session renewed successfully!' : 'Session renewal failed. Please check credentials.'),
                                backgroundColor: ok ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Renew Session', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<AppState>().disconnectGroww();
                        },
                        icon: const Icon(Icons.switch_account, size: 16),
                        label: const Text('Switch Account', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      GrowwLoginDialog.show(context);
                    },
                    icon: const Icon(Icons.security, size: 16),
                    label: const Text('Update Groww Credentials / Connect Account', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTradeAlertsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final state = context.watch<AppState>();
        final alerts = state.tradeAlerts;
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1E222D),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BUY / SELL NOTIFICATIONS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: alerts.isEmpty
                      ? const Center(child: Text('No trade notifications recorded yet.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: alerts.length,
                          itemBuilder: (context, idx) {
                            return TradeAlertCard(
                              alert: alerts[idx],
                              onResponded: () => state.refreshTradingControl(),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAccountActivitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final state = context.watch<AppState>();
        final positions = state.portfolio?.positions ?? [];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Activity & Open Positions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                if (positions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No active open positions.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ...positions.map((p) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${p.symbol} (${p.quantity} shares)', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('Avg: ₹${p.avgEntryPrice.toStringAsFixed(2)} | Current: ₹${p.currentPrice.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        trailing: Text(
                          '${p.unrealizedPnl >= 0 ? "+" : ""}₹${p.unrealizedPnl.toStringAsFixed(2)}',
                          style: TextStyle(color: p.unrealizedPnl >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDepositWithdrawSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131722),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final state = context.watch<AppState>();
        final txs = state.fundTransactions;
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1E222D),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DEPOSIT & WITHDRAWAL HISTORY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Record', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showRecordTransactionPrompt(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: txs.isEmpty
                      ? const Center(child: Text('No confirmed deposits or withdrawals yet.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: txs.length,
                          itemBuilder: (context, idx) {
                            final t = txs[idx];
                            final isDep = t.transactionType == 'DEPOSIT';
                            return ListTile(
                              leading: Icon(
                                isDep ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isDep ? Colors.greenAccent : Colors.orangeAccent,
                              ),
                              title: Text(
                                '${t.transactionType}: ₹${t.amount.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${t.note ?? "Confirmed"} • ${t.createdAt.toLocal().toString().substring(0, 16)}',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                              ),
                              trailing: Text(
                                t.status,
                                style: TextStyle(color: isDep ? Colors.greenAccent : Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordTransactionPrompt(BuildContext context) {
    String type = 'DEPOSIT';
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1E222D),
          title: const Text('Record Fund Transaction', style: TextStyle(color: Colors.white, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Deposit (Money In)'),
                      selected: type == 'DEPOSIT',
                      selectedColor: Colors.green.shade800,
                      onSelected: (_) => setLocal(() => type = 'DEPOSIT'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Withdraw (Money Out)'),
                      selected: type == 'WITHDRAWAL',
                      selectedColor: Colors.orange.shade800,
                      onSelected: (_) => setLocal(() => type = 'WITHDRAWAL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Amount (₹)', hintStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Note (e.g. Bank UPI Ref)', hintStyle: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text.trim());
                if (amt != null && amt > 0) {
                  context.read<AppState>().recordFundTransaction(type, amt, note: noteController.text.trim());
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save & Notify'),
            ),
          ],
        ),
      ),
    );
  }
}
