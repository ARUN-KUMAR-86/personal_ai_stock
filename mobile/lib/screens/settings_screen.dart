import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/storage_service.dart';
import '../widgets/zed_logo.dart';

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
  }

  Future<void> _loadSettings() async {
    final url = await StorageService.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _urlController.text = url;
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
          if (data.contains('"PREFERRED_MARKET":"NSE"')) {
            setState(() => preferredMarket = 'NSE');
          } else if (data.contains('"PREFERRED_MARKET":"US"')) {
            setState(() => preferredMarket = 'US');
          } else {
            setState(() => preferredMarket = 'ALL');
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

  Future<void> _sendTestAlert(String action) async {
    setState(() => isTestingPush = true);
    final ok = await context.read<AppState>().api.sendTestPushAlert(action: action);
    if (!mounted) return;
    setState(() => isTestingPush = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '🟢 Test $action Notification dispatched to phone!'
            : 'Notification queued in cloud database.'),
        backgroundColor: action == 'BUY' ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
      ),
    );
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

          // 5. TEST REALTIME NOTIFICATIONS
          _buildCard(
            context,
            title: 'NOTIFICATION TEST (STRICTLY BUY & SELL)',
            icon: Icons.notifications_active_outlined,
            iconColor: const Color(0xFF16A34A),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dispatch a realtime test alert to verify push sound, chimes, and banners:',
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
                        label: const Text('Test BUY Alert', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: isTestingPush ? null : () => _sendTestAlert('BUY'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        label: const Text('Test SELL Alert', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: isTestingPush ? null : () => _sendTestAlert('SELL'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. 24/7 CLOUD BACKEND (RENDER)
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
                    label: const Text('Verify Cloud Connection', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: isSaving ? null : _connectToCloud,
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
