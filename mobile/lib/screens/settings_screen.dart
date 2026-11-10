import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/zed_logo.dart';
import 'trading_control_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool isSaving = false;
  String? connectionStatus;
  bool isTestingPush = false;

  String preferredHorizon = '1-DAY'; // '1-DAY', '1-MONTH', 'ALL'
  String preferredMarket = 'ALL';    // 'NSE', 'US', 'ALL'

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _autoCheckCloudStatus();
  }

  Future<void> _autoCheckCloudStatus() async {
    final state = context.read<AppState>();
    if (state.isOnline) {
      if (mounted) {
        setState(() {
          connectionStatus = '🟢 Connected to 24/7 Cloud (Online • Always Active)';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          connectionStatus = 'Cloud waking up... Auto-connecting in background.';
        });
      }
      final healthy = await state.api.checkHealth();
      if (!mounted) return;
      setState(() {
        connectionStatus = healthy
            ? '🟢 Connected to 24/7 Cloud (Online • Always Active)'
            : 'Cloud waking up... Auto-connecting in background.';
      });
      if (healthy) {
        state.refreshAll();
      }
    }
  }

  Future<void> _loadSettings() async {
    final url = await StorageService.getBaseUrl();
    final savedMarket = await StorageService.getActiveMarket();
    if (!mounted) return;
    final state = context.read<AppState>();
    setState(() {
      _urlController.text = url;
      if (state.isUSMarket || savedMarket == 'US') {
        preferredMarket = 'US';
      } else if (state.isIndianMarket || savedMarket == 'INDIA') {
        preferredMarket = 'NSE';
      }
    });
    _fetchCloudSettings();
  }

  Future<void> _fetchCloudSettings() async {
    try {
      final baseUrl = await StorageService.getBaseUrl();
      final res = await http.get(Uri.parse('$baseUrl/api/v1/settings')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = res.body;
        if (data.contains('PREFERRED_HORIZON')) {
          if (data.contains('"PREFERRED_HORIZON":"1-MONTH"')) {
            setState(() => preferredHorizon = '1-MONTH');
          } else if (data.contains('"PREFERRED_HORIZON":"ALL"')) {
            setState(() => preferredHorizon = 'ALL');
          } else {
            setState(() => preferredHorizon = '1-DAY');
          }
        }
        if (data.contains('PREFERRED_MARKET')) {
          String? serverMarket;
          if (data.contains('"PREFERRED_MARKET":"NSE"')) {
            serverMarket = 'NSE';
          } else if (data.contains('"PREFERRED_MARKET":"US"')) {
            serverMarket = 'US';
          } else if (data.contains('"PREFERRED_MARKET":"ALL"')) {
            serverMarket = 'ALL';
          }
          if (serverMarket != null && mounted) {
            setState(() => preferredMarket = serverMarket!);
            final targetMarket = (serverMarket == 'US') ? 'US' : 'INDIA';
            await StorageService.setActiveMarket(targetMarket);
            if (mounted && context.read<AppState>().activeMarket != targetMarket) {
              await context.read<AppState>().selectMarket(targetMarket);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveHorizonPreference(String horizon) async {
    setState(() => preferredHorizon = horizon);
    try {
      final baseUrl = await StorageService.getBaseUrl();
      await http.post(
        Uri.parse('$baseUrl/api/v1/settings'),
        headers: {'Content-Type': 'application/json'},
        body: '{"key":"PREFERRED_HORIZON","value":"$horizon"}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preference updated: ${horizon == "1-DAY" ? "1-Day Short Term" : (horizon == "1-MONTH" ? "1-Month Long Term" : "All Horizons")}'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    } catch (_) {}
  }

  Future<void> _saveMarketPreference(String market) async {
    setState(() => preferredMarket = market);
    final targetMarket = (market == 'US') ? 'US' : 'INDIA';
    await StorageService.setActiveMarket(targetMarket);

    if (mounted) {
      final appState = context.read<AppState>();
      if (appState.activeMarket != targetMarket) {
        await appState.selectMarket(targetMarket);
      }
    }

    try {
      final baseUrl = await StorageService.getBaseUrl();
      await http.post(
        Uri.parse('$baseUrl/api/v1/settings'),
        headers: {'Content-Type': 'application/json'},
        body: '{"key":"PREFERRED_MARKET","value":"$market"}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Market updated: ${market == "ALL" ? "All Markets (NSE + US)" : (market == "US" ? "US Stocks Only" : "Indian NSE Only")}'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    } catch (_) {}
  }

  Future<void> _sendTestAlert(String action) async {
    setState(() => isTestingPush = true);
    final isBuy = action.toUpperCase() == 'BUY';
    final isUS = context.read<AppState>().isUSMarket;
    final sym = isUS ? 'NVDA' : 'RELIANCE';
    final ex = isUS ? 'US' : 'NSE';
    final priceStr = isUS ? '\$186.50' : '₹1,196.20';
    final targetStr = isUS ? '\$205.00' : '₹1,260.00';
    final slStr = isUS ? '\$178.00' : '₹1,165.00';

    final title = '${isBuy ? "🟢" : "🔴"} $action ALERT: $sym @ $priceStr [TEST]';
    final body = isBuy
        ? 'BUY BREAKOUT: $sym triggered entry confirmation. Target: $targetStr | Stop-Loss: $slStr.\nPull down notification bar to view full details.'
        : 'SELL SIGNAL: $sym reached profit target / stop. Recommended exit @ $priceStr.\nPull down notification bar to view full details.';

    // 1. Immediately post a real Android notification to the notification bar
    try {
      await NotificationService().showNotification(
        title: title,
        body: body,
        data: {
          'symbol': sym,
          'exchange': ex,
          'action': action,
        },
        isCritical: !isBuy,
      );
    } catch (e) {
      debugPrint('Local test notification show error: $e');
    }

    // 2. Also register alert in cloud backend / FCM
    if (mounted) {
      try {
        await context.read<AppState>().api.sendTestPushAlert(action: action);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => isTestingPush = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🟢 Test $action Alert posted to your notification bar! Pull down the top bar to inspect.'),
        backgroundColor: isBuy ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _sendTestSellMilestone({required bool isProfit, double milestoneAmount = 30.0}) async {
    setState(() => isTestingPush = true);
    final isUS = context.read<AppState>().isUSMarket;
    final curr = isUS ? '\$' : '₹';
    final symbol = isUS ? (isProfit ? 'NVDA' : 'TSLA') : (isProfit ? 'RELIANCE' : 'TATASTEEL');
    final ex = isUS ? 'US' : 'NSE';
    const qty = 10;
    final buyPrice = isUS ? (isProfit ? 180.00 : 250.00) : (isProfit ? 1200.00 : 150.00);
    final totalBuy = buyPrice * qty;
    final pnl = isProfit ? milestoneAmount : -milestoneAmount;
    final sellPrice = buyPrice + (pnl / qty);
    final totalSell = sellPrice * qty;
    final pnlPct = (pnl / totalBuy) * 100.0;

    final pnlStr = isProfit ? '+$curr${milestoneAmount.toStringAsFixed(2)}' : '-$curr${milestoneAmount.toStringAsFixed(2)}';
    final pnlPctStr = isProfit ? '+${pnlPct.toStringAsFixed(2)}%' : '-${pnlPct.abs().toStringAsFixed(2)}%';
    final statusTag = isProfit ? '+$curr${milestoneAmount.toInt()} PROFIT' : '-$curr${milestoneAmount.toInt()} LOSS';

    final title = '🔴 SELL ALERT ($statusTag): $symbol @ $curr${sellPrice.toStringAsFixed(2)}';
    final body = '🔴 SELL ALERT: $symbol reached ${isProfit ? "+$curr${milestoneAmount.toInt()} Profit Sell Target" : "-$curr${milestoneAmount.toInt()} Loss Stop-Loss Alert"}!\n'
        '• Buy Price: $curr${buyPrice.toStringAsFixed(2)} | Total Buy Amount: $curr${totalBuy.toStringAsFixed(2)} (Qty: $qty)\n'
        '• Sell Price: $curr${sellPrice.toStringAsFixed(2)} | Total Sell Amount: $curr${totalSell.toStringAsFixed(2)}\n'
        '• Profit / Loss: $pnlStr ($pnlPctStr)\n'
        '• Milestone: ${isProfit ? "+$curr${milestoneAmount.toInt()} Profit Milestone" : "-$curr${milestoneAmount.toInt()} Stop-Loss Milestone"}\n'
        'Action: Execute SELL order in Groww to ${isProfit ? "lock in your profit" : "protect your capital"}!';

    try {
      await NotificationService().showNotification(
        title: title,
        body: body,
        data: {
          'symbol': symbol,
          'exchange': ex,
          'action': 'SELL',
          'buy_amount': totalBuy,
          'sell_amount': totalSell,
          'pnl_inr': pnl,
          'pnl_pct': pnlPct,
        },
        isCritical: true,
      );
    } catch (e) {
      debugPrint('Local test notification show error: $e');
    }

    if (mounted) {
      try {
        await context.read<AppState>().api.sendTestPushAlert(action: 'SELL');
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => isTestingPush = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔴 Test $statusTag Sell Alert posted to notification bar! Pull down top bar to view.'),
        backgroundColor: isProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _connectToCloud() async {
    setState(() {
      isSaving = true;
      connectionStatus = 'Connecting to Render Cloud 24/7 backend...';
    });
    _urlController.text = StorageService.cloudProductionUrl;
    await StorageService.setBaseUrl(StorageService.cloudProductionUrl);
    if (!mounted) return;
    final api = context.read<AppState>().api;
    final ok = await api.checkHealth();
    if (!mounted) return;
    setState(() {
      isSaving = false;
      if (ok) {
        connectionStatus = 'Connected to 24/7 Cloud (Online)';
      } else {
        connectionStatus = 'Cloud waking up... Please wait 15s and test again.';
      }
    });
    if (ok) {
      context.read<AppState>().refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final isDark = state.isDarkMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const ZedLogo(size: 24),
            const SizedBox(width: 8),
            Text(
              'ZED SETTINGS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. APPEARANCE & THEME (White & Blue vs Dark Mode)
          _buildCard(
            context,
            title: 'THEME & APPEARANCE',
            icon: Icons.palette_outlined,
            iconColor: const Color(0xFF2563EB),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDark ? 'Dark Mode' : 'White & Blue Theme',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              isDark ? 'OLED / Slate contrast' : 'Clean crisp white & royal blue',
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: isDark,
                      activeColor: const Color(0xFF38BDF8),
                      activeTrackColor: const Color(0xFF0369A1),
                      inactiveThumbColor: const Color(0xFF2563EB),
                      inactiveTrackColor: const Color(0xFFDBEAFE),
                      onChanged: (val) => state.toggleDarkMode(val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // TRADING CONTROL & GROWW BROKER SESSION
          _buildCard(
            context,
            title: 'TRADING CONTROLS & GROWW SESSION',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF10B981),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage trading budget, Option B Hybrid Guard (Auto Stop-Loss), daily loss limits, and 1-tap Groww TOTP session renewal:',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text(
                      'Open Trading Controls & Budget',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TradingControlScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. TIME HORIZON PREFERENCE
          _buildCard(
            context,
            title: 'TIME HORIZON PREFERENCE',
            icon: Icons.hourglass_top_rounded,
            iconColor: const Color(0xFFD97706),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select your preferred trade duration for stock notifications:',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                _buildHorizonOption(
                  context,
                  title: '⚡ 1-Day Short Term (Preferred)',
                  subtitle: 'Intraday & swing breakouts (24-48 hours, quick +4% to +8% targets)',
                  key: '1-DAY',
                  selectedKey: preferredHorizon,
                  onSelect: () => _saveHorizonPreference('1-DAY'),
                ),
                const SizedBox(height: 8),
                _buildHorizonOption(
                  context,
                  title: '📅 1-Month Long Term',
                  subtitle: 'Positional multi-week trend holdings (~30 days, +15% to +25% targets)',
                  key: '1-MONTH',
                  selectedKey: preferredHorizon,
                  onSelect: () => _saveHorizonPreference('1-MONTH'),
                ),
                const SizedBox(height: 8),
                _buildHorizonOption(
                  context,
                  title: '🌐 Both Horizons (All Notifications)',
                  subtitle: 'Receive both 1-Day momentum surges and 1-Month positional setups',
                  key: 'ALL',
                  selectedKey: preferredHorizon,
                  onSelect: () => _saveHorizonPreference('ALL'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. MARKET UNIVERSE (Indian NSE + Foreign US Stocks)
          _buildCard(
            context,
            title: 'MARKET UNIVERSE (INTERNET SCANNER)',
            icon: Icons.public,
            iconColor: const Color(0xFF0284C7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose which global stock universe to scan daily:',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMarketChip(
                  context,
                  title: '🌍 All Markets (Indian NSE + US Stocks)',
                  subtitle: 'Monitors Nifty 50 and US Mega-Caps (NVDA, AAPL, MSFT...)',
                  key: 'ALL',
                  selectedKey: preferredMarket,
                  onSelect: () => _saveMarketPreference('ALL'),
                ),
                const SizedBox(height: 8),
                _buildMarketChip(
                  context,
                  title: '🇮🇳 Indian NSE Only',
                  subtitle: 'Reliance, TCS, HDFC Bank, Infosys, and top NSE leaders',
                  key: 'NSE',
                  selectedKey: preferredMarket,
                  onSelect: () => _saveMarketPreference('NSE'),
                ),
                const SizedBox(height: 8),
                _buildMarketChip(
                  context,
                  title: '🌐 US Global Stocks Only',
                  subtitle: 'Nvidia, Apple, Microsoft, Tesla, Amazon, Meta, Palantir',
                  key: 'US',
                  selectedKey: preferredMarket,
                  onSelect: () => _saveMarketPreference('US'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. GEMINI PRO AI RESEARCH ENGINE
          _buildCard(
            context,
            title: 'GEMINI PRO AI RESEARCH ENGINE',
            icon: Icons.psychology_outlined,
            iconColor: const Color(0xFF7C3AED),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI Research Engine',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            'ACTIVE & VERIFIED',
                            style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Model: Gemini 3.5 Flash-Lite (Google AI Studio)\nInstitutional 5-Dimension Research automatically attached to every BUY and SELL alert.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4B. SELL ALERTS PREFERENCE (STRICTLY SELL ALERTS ONLY)
          _buildCard(
            context,
            title: 'ALERT NOTIFICATIONS: STRICTLY SELL ALERTS ONLY',
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFFDC2626),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Only Sell Alerts for Marked / Bought Stocks',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Suppresses general buy recommendations. You will ONLY receive sell notifications for stocks you mark/buy when they hit stepped profit or loss milestones.',
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: state.onlySellAlerts,
                      activeColor: const Color(0xFFDC2626),
                      onChanged: (val) {
                        state.setOnlySellAlerts(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161C2E) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notification displays Buy Amount, Sell Amount, exact Profit/Loss, and triggers for every +₹30 profit (or +\$30 US) and -₹30 loss (or -\$30 US).',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. TEST REALTIME NOTIFICATIONS
          _buildCard(
            context,
            title: 'NOTIFICATION TEST (STEPPED PROFIT & LOSS)',
            icon: Icons.notifications_active_outlined,
            iconColor: const Color(0xFF16A34A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap below to dispatch a test notification directly into your Android notification bar with Buy Amount, Sell Amount, and Profit/Loss:',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        label: Text(
                          '+${state.isUSMarket ? "\$30" : "₹30"} Profit Sell Alert',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        onPressed: isTestingPush ? null : () => _sendTestSellMilestone(isProfit: true, milestoneAmount: 30.0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        label: Text(
                          '-${state.isUSMarket ? "\$30" : "₹30"} Loss Sell Alert',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        onPressed: isTestingPush ? null : () => _sendTestSellMilestone(isProfit: false, milestoneAmount: 30.0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    ),
                    icon: const Icon(Icons.notification_add_outlined, size: 14),
                    label: const Text('Send Standard Buy Alert (Test)', style: TextStyle(fontSize: 11)),
                    onPressed: isTestingPush ? null : () => _sendTestAlert('BUY'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 24/7 CLOUD BACKEND (RENDER)
          _buildCard(
            context,
            title: 'CLOUD BACKEND (NO LAPTOP NEEDED)',
            icon: Icons.cloud_done_outlined,
            iconColor: const Color(0xFF2563EB),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected to Render Cloud 24/7 Service:',
                  style: TextStyle(color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bolt, color: Color(0xFF16A34A), size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'https://personal-ai-stock-backend.onrender.com',
                          style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (connectionStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    connectionStatus!,
                    style: TextStyle(
                      color: connectionStatus!.contains('Online') ? const Color(0xFF16A34A) : Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Re-Check Connection (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: isSaving ? null : _connectToCloud,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '⚡ Auto-Connect is active: The app always connects to the cloud automatically on launch and self-heals in the background. Clicking is 100% optional.',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // 6. ZED SYSTEM & APP INFORMATION
          const SizedBox(height: 16),
          _buildCard(
            context,
            title: 'ZED SYSTEM INFORMATION',
            icon: Icons.info_outline,
            iconColor: const Color(0xFF38BDF8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ZedLogo(size: 38),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zed AI Stock Intelligence',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        Text(
                          'Version 2.1.0 • Institutional Confluence',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 6),
                _buildSystemStatRow('Live Monitoring', '24/7 Tick Active', Colors.green),
                _buildSystemStatRow('Confluence Engine', 'Supertrend + ADX + BB + RSI', const Color(0xFF2563EB)),
                _buildSystemStatRow('AI Model', 'Gemini Pro / Flash Confluence', Colors.teal),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSystemStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0x0A0F172A),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildHorizonOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String key,
    required String selectedKey,
    required VoidCallback onSelect,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = key == selectedKey;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : theme.dividerColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? const Color(0xFF2563EB) : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
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

  Widget _buildMarketChip(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String key,
    required String selectedKey,
    required VoidCallback onSelect,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = key == selectedKey;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : theme.dividerColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? const Color(0xFF0284C7) : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? const Color(0xFF0284C7) : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : const Color(0xFF64748B),
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
}
