import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../models/portfolio.dart';
import '../widgets/priority_badge.dart';
import '../widgets/manual_purchase_dialog.dart';
import '../widgets/manual_sale_dialog.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  String _selectedMarket = 'ALL'; // 'ALL', 'INDIA', 'US'

  void _confirmDeletePosition(BuildContext context, Position pos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Remove ${pos.symbol}?',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${pos.symbol} (${pos.quantity} shares @ ${pos.currencySymbol}${pos.avgEntryPrice.toStringAsFixed(2)}) from your portfolio?\n\nThis will remove the holding from active tracking immediately.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().deletePosition(pos.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red.shade800,
                    content: Text('Removed ${pos.symbol} from portfolio.'),
                  ),
                );
              }
            },
            child: const Text('Remove Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

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
                          decoration: InputDecoration(
                            labelText: 'Stop-Loss (${pos.currencySymbol})',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF131722),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: tpController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Target (${pos.currencySymbol})',
                            labelStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF131722),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove Stock from Portfolio', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDeletePosition(context, pos);
                      },
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

  Widget _buildMarketTab({
    required String key,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedMarket = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? Colors.grey.shade400 : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required String currencySymbol,
    required double totalVal,
    required double invested,
    required double unrealized,
    required double realized,
    required int holdingsCount,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardBox(
        isDark,
        borderCol: unrealized >= 0
            ? AppTheme.profit(isDark).withOpacity(0.3)
            : AppTheme.loss(isDark).withOpacity(0.3),
        glow: true,
        glowColor: unrealized >= 0 ? AppTheme.profit(isDark) : AppTheme.loss(isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textMuted(isDark),
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (unrealized >= 0 ? Colors.green : Colors.red).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${unrealized >= 0 ? '+' : ''}$currencySymbol${unrealized.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: unrealized >= 0 ? AppTheme.profit(isDark) : AppTheme.loss(isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$currencySymbol${totalVal.toStringAsFixed(2)}',
            style: AppTheme.mono(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invested', style: TextStyle(color: AppTheme.textMuted(isDark), fontSize: 10.5)),
                  const SizedBox(height: 2),
                  Text(
                    '$currencySymbol${invested.toStringAsFixed(2)}',
                    style: AppTheme.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(isDark),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unrealized P&L', style: TextStyle(color: AppTheme.textMuted(isDark), fontSize: 10.5)),
                  const SizedBox(height: 2),
                  Text(
                    '${unrealized >= 0 ? '+' : ''}$currencySymbol${unrealized.toStringAsFixed(2)}',
                    style: AppTheme.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: unrealized >= 0 ? AppTheme.profit(isDark) : AppTheme.loss(isDark),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Realized P&L', style: TextStyle(color: AppTheme.textMuted(isDark), fontSize: 10.5)),
                  const SizedBox(height: 2),
                  Text(
                    '${realized >= 0 ? '+' : ''}$currencySymbol${realized.toStringAsFixed(2)}',
                    style: AppTheme.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: realized >= 0 ? AppTheme.profit(isDark) : AppTheme.loss(isDark),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Holdings', style: TextStyle(color: AppTheme.textMuted(isDark), fontSize: 10.5)),
                  const SizedBox(height: 2),
                  Text(
                    '$holdingsCount Stocks',
                    style: AppTheme.mono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary(isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDarkMode;
    final portfolio = state.portfolio;

    // Segment Positions between Indian NSE & US Markets
    final allPositions = portfolio?.positions ?? [];
    final indianPositions = allPositions.where((p) => !p.isUS).toList();
    final usPositions = allPositions.where((p) => p.isUS).toList();

    List<Position> displayedPositions;
    if (_selectedMarket == 'INDIA') {
      displayedPositions = indianPositions;
    } else if (_selectedMarket == 'US') {
      displayedPositions = usPositions;
    } else {
      displayedPositions = allPositions;
    }

    // Segment Trades between Indian NSE & US Markets
    final allTrades = state.paperTrades;
    final indianTrades = allTrades.where((t) => !t.isUS).toList();
    final usTrades = allTrades.where((t) => t.isUS).toList();

    List<PaperTrade> displayedTrades;
    if (_selectedMarket == 'INDIA') {
      displayedTrades = indianTrades;
    } else if (_selectedMarket == 'US') {
      displayedTrades = usTrades;
    } else {
      displayedTrades = allTrades;
    }

    // Indian Totals (INR)
    final inrInvested = indianPositions.fold<double>(0.0, (sum, p) => sum + (p.avgEntryPrice * p.quantity));
    final inrUnrealized = indianPositions.fold<double>(0.0, (sum, p) => sum + p.unrealizedPnl);
    final inrTotalVal = inrInvested + inrUnrealized;
    final inrRealized = indianPositions.fold<double>(0.0, (sum, p) => sum + p.realizedPnl);

    // US Totals (USD)
    final usdInvested = usPositions.fold<double>(0.0, (sum, p) => sum + (p.avgEntryPrice * p.quantity));
    final usdUnrealized = usPositions.fold<double>(0.0, (sum, p) => sum + p.unrealizedPnl);
    final usdTotalVal = usdInvested + usdUnrealized;
    final usdRealized = usPositions.fold<double>(0.0, (sum, p) => sum + p.realizedPnl);

    return Scaffold(
      backgroundColor: AppTheme.scaffold(isDark),
      appBar: AppBar(
        backgroundColor: AppTheme.card(isDark),
        elevation: 0,
        title: const Text('PORTFOLIO & TRADES', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: Colors.amberAccent),
            tooltip: 'Run Auto Take Money Check',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking open positions for profit targets...'), duration: Duration(seconds: 1)),
              );
              final res = await state.triggerAutoSellCheck();
              await state.checkAndExecuteAutoSell();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Check complete.'),
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
            // Market Universe Tabs (All Markets, Indian NSE, US Stocks)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMarketTab(
                      key: 'ALL',
                      label: '🌍 All (${allPositions.length})',
                      isSelected: _selectedMarket == 'ALL',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMarketTab(
                      key: 'INDIA',
                      label: '🇮🇳 India (${indianPositions.length})',
                      isSelected: _selectedMarket == 'INDIA',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMarketTab(
                      key: 'US',
                      label: '🌐 US (${usPositions.length})',
                      isSelected: _selectedMarket == 'US',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            // UltraSync Low-Latency Live Status Bar
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppTheme.cardBox(
                isDark,
                borderCol: state.isUltraSyncActive ? Colors.tealAccent.withOpacity(0.3) : null,
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
                      color: state.isUltraSyncActive ? (isDark ? Colors.tealAccent : const Color(0xFF0D9488)) : Colors.grey,
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
                        color: state.syncLatencyMs < 150 ? (isDark ? Colors.greenAccent : const Color(0xFF15803D)) : (state.syncLatencyMs < 400 ? Colors.orangeAccent : Colors.blue),
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

            // Segmented Portfolio Summary Display
            if (_selectedMarket == 'INDIA')
              _buildSummaryCard(
                context: context,
                title: 'INDIAN NSE PORTFOLIO VALUE',
                currencySymbol: '₹',
                totalVal: inrTotalVal,
                invested: inrInvested,
                unrealized: inrUnrealized,
                realized: inrRealized,
                holdingsCount: indianPositions.length,
                isDark: isDark,
              )
            else if (_selectedMarket == 'US')
              _buildSummaryCard(
                context: context,
                title: 'US STOCKS PORTFOLIO VALUE',
                currencySymbol: r'$',
                totalVal: usdTotalVal,
                invested: usdInvested,
                unrealized: usdUnrealized,
                realized: usdRealized,
                holdingsCount: usPositions.length,
                isDark: isDark,
              )
            else ...[
              // Dual currency displays for All Markets mode
              _buildSummaryCard(
                context: context,
                title: 'INDIAN NSE HOLDINGS',
                currencySymbol: '₹',
                totalVal: inrTotalVal,
                invested: inrInvested,
                unrealized: inrUnrealized,
                realized: inrRealized,
                holdingsCount: indianPositions.length,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildSummaryCard(
                context: context,
                title: 'US STOCKS HOLDINGS',
                currencySymbol: r'$',
                totalVal: usdTotalVal,
                invested: usdInvested,
                unrealized: usdUnrealized,
                realized: usdRealized,
                holdingsCount: usPositions.length,
                isDark: isDark,
              ),
            ],
            const SizedBox(height: 12),

            // Prominent "I BOUGHT THIS STOCK" Manual Purchase Action
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 3,
                ),
                icon: const Icon(Icons.add_shopping_cart, size: 20),
                label: Text(
                  _selectedMarket == 'US' ? 'I BOUGHT THIS STOCK (US BROKER)' : 'I BOUGHT THIS STOCK (GROWW)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.6),
                ),
                onPressed: () {
                  ManualPurchaseDialog.show(
                    context,
                    symbol: '',
                    exchange: _selectedMarket == 'US' ? 'US' : 'NSE',
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Positions Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedMarket == 'US'
                      ? 'ACTIVE US POSITIONS'
                      : (_selectedMarket == 'INDIA' ? 'ACTIVE INDIAN NSE POSITIONS' : 'ACTIVE MONITORED POSITIONS'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                Text(
                  '${displayedPositions.length} Open',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (displayedPositions.isEmpty)
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
                      'No open monitored positions in ${_selectedMarket == "US" ? "US Stocks" : (_selectedMarket == "INDIA" ? "Indian NSE" : "your portfolio")}.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "I BOUGHT THIS STOCK" above to record your broker trades and initiate continuous AI monitoring.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...displayedPositions.map((pos) {
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                            pos.autoSellEnabled ? 'Auto' : 'Manual',
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
                                const SizedBox(height: 2),
                                Text(
                                  pos.marketTag,
                                  style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w600, fontSize: 9.5),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isProfit ? '+' : ''}${pos.currencySymbol}${pos.unrealizedPnl.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isProfit ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPosMetric('Avg Price', '${pos.currencySymbol}${pos.avgEntryPrice.toStringAsFixed(2)}'),
                          _buildPosMetric('Current Price', '${pos.currencySymbol}${pos.currentPrice.toStringAsFixed(2)}'),
                          _buildPosMetric('Stop Loss', pos.stopLoss != null ? '${pos.currencySymbol}${pos.stopLoss}' : 'None', color: Colors.redAccent),
                          _buildPosMetric('Target', pos.target != null ? '${pos.currencySymbol}${pos.target}' : 'None', color: Colors.greenAccent),
                        ],
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              PriorityBadge(priority: pos.priority, fontSize: 10),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pos.isUS ? 'US BROKER' : 'GROWW MANUAL',
                                  style: const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (pos.pnlPct != 0.0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(${isProfit ? '+' : ''}${pos.pnlPct.toStringAsFixed(2)}%)',
                                  style: TextStyle(
                                    color: isProfit ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, size: 18, color: Colors.grey),
                            tooltip: 'Monitoring Settings',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.only(left: 4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => _showPositionEditDialog(context, pos),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: BorderSide(color: Colors.redAccent.withOpacity(0.6)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 14),
                              label: const Text(
                                'REMOVE STOCK',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              onPressed: () => _confirmDeletePosition(context, pos),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.sell_outlined, size: 14),
                              label: const Text(
                                'I SOLD THIS',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                              onPressed: () {
                                ManualSaleDialog.show(context, pos);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (pos.triggeredThresholds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: pos.triggeredThresholds.reversed.take(3).map((t) {
                            final isProfitAlert = t.contains('+') || t.contains('PROFIT');
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isProfitAlert ? Colors.green : Colors.red).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (isProfitAlert ? Colors.greenAccent : Colors.redAccent).withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                'ALERT: $t',
                                style: TextStyle(
                                  color: isProfitAlert ? Colors.greenAccent : Colors.redAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),

            // Trade History Section (Purchases & Sales across Indian & US markets)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedMarket == 'US'
                      ? 'MY US TRADE HISTORY'
                      : (_selectedMarket == 'INDIA' ? 'MY INDIAN TRADE HISTORY' : 'MY TRADE HISTORY (PURCHASES & SALES)'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                Text(
                  '${displayedTrades.length} Recorded',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (displayedTrades.isEmpty)
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
                      'No trades recorded yet in ${_selectedMarket == "US" ? "US Stocks" : (_selectedMarket == "INDIA" ? "Indian NSE" : "your portfolio")}.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "I BOUGHT THIS STOCK" to log your Groww or US broker trades and receive 24/7 sell alerts.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...displayedTrades.map((pt) {
                final isBuy = pt.action.toUpperCase().contains('BUY');
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
                                  isBuy ? 'BUY' : 'SELL',
                                  style: TextStyle(
                                    color: isBuy ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pt.symbol,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    pt.marketTag,
                                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w600, fontSize: 9.5),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${pt.quantity} Shares',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            '${pt.currencySymbol}${pt.price.toStringAsFixed(2)}',
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
                              if (pt.target != null)
                                Text('TP: ${pt.currencySymbol}${pt.target!.toStringAsFixed(1)} ', style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
                              if (pt.stopLoss != null)
                                Text('SL: ${pt.currencySymbol}${pt.stopLoss!.toStringAsFixed(1)}', style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                              if (pt.pnl != 0.0)
                                Text('P/L: ${pt.pnl >= 0 ? '+' : ''}${pt.currencySymbol}${pt.pnl.toStringAsFixed(2)}', style: TextStyle(color: pt.pnl >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
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
