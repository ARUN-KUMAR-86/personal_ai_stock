import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/storage_service.dart';
import '../widgets/groww_login_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool isSaving = false;
  String? connectionStatus;
  bool isAuthenticatingGroww = false;
  String? _fcmToken;
  bool isTestingPush = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final url = await StorageService.getBaseUrl();
    final token = await StorageService.getFcmToken();
    if (!mounted) return;
    setState(() {
      _urlController.text = url;
      _fcmToken = token;
    });
  }

  Future<void> _autoDetectUrl() async {
    setState(() {
      isSaving = true;
      connectionStatus = 'Scanning for active backend (Cloud & Local)...';
    });

    final candidates = [
      StorageService.cloudProductionUrl,
      'http://10.246.109.77:8000',
      'http://192.168.1.77:8000',
      'http://localhost:8000',
    ];

    String? foundUrl;
    for (final candidate in candidates) {
      try {
        final res = await http
            .get(Uri.parse('$candidate/health'))
            .timeout(const Duration(milliseconds: 3000));
        if (res.statusCode == 200) {
          foundUrl = candidate;
          break;
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (foundUrl != null) {
      _urlController.text = foundUrl;
      await StorageService.setBaseUrl(foundUrl);
      setState(() {
        isSaving = false;
        connectionStatus = 'Connected to $foundUrl (Online)';
      });
      context.read<AppState>().refreshAll();
    } else {
      setState(() {
        isSaving = false;
        connectionStatus = 'Could not reach server. Verify internet or local PC backend.';
      });
    }
  }

  Future<void> _connectToCloud() async {
    setState(() {
      isSaving = true;
      connectionStatus = 'Connecting to 24/7 Cloud backend...';
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
        connectionStatus = 'Cloud waking up... Please wait 20s and test again.';
      }
    });
    if (ok) {
      context.read<AppState>().refreshAll();
    }
  }

  Future<void> _saveUrl() async {
    setState(() => isSaving = true);
    final inputUrl = _urlController.text.trim();
    await StorageService.setBaseUrl(inputUrl);
    if (!mounted) return;
    final api = context.read<AppState>().api;
    final ok = await api.checkHealth();
    if (!mounted) return;
    setState(() {
      isSaving = false;
      if (ok) {
        connectionStatus = 'Connected successfully! (Server online)';
      } else {
        if (inputUrl.contains('localhost') || inputUrl.contains('127.0.0.1')) {
          connectionStatus = 'Connection failed. On a physical phone, "localhost" points to the phone itself. Use your PC IP (e.g. http://10.246.109.77:8000).';
        } else if (inputUrl.contains('10.0.2.2')) {
          connectionStatus = '10.0.2.2 is an emulator IP. On your phone, use your PC Hotspot IP: http://10.246.109.77:8000.';
        } else {
          connectionStatus = 'Connection failed. Verify your phone is connected to the same hotspot/Wi-Fi.';
        }
      }
    });
    if (ok) {
      context.read<AppState>().refreshAll();
    }
  }

  Future<void> _refreshGrowwAuth() async {
    setState(() => isAuthenticatingGroww = true);
    try {
      final res = await context.read<AppState>().api.refreshGrowwAuth();
      if (!mounted) return;
      setState(() => isAuthenticatingGroww = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Groww auth updated.'),
          backgroundColor: res['authenticated'] == true ? Colors.green : Colors.amber.shade900,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isAuthenticatingGroww = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Groww auth error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendTestPush() async {
    setState(() => isTestingPush = true);
    final ok = await context.read<AppState>().api.sendTestPushAlert();
    if (!mounted) return;
    setState(() => isTestingPush = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Test notification dispatched to Android phone.'
            : 'Push notification queued in backend database.'),
        backgroundColor: ok ? Colors.green : Colors.amber.shade900,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final safety = state.safetyStatus;
    final isEmergencyStop = safety?.emergencyStopEnabled ?? false;
    final isAutoSell = safety?.autoSellEnabled ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: const Text('SETTINGS & SAFETY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. EMERGENCY KILL SWITCH (Trading Safety Control)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEmergencyStop ? Colors.red.shade900.withOpacity(0.3) : const Color(0xFF1E222D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isEmergencyStop ? Colors.redAccent : Colors.redAccent.withOpacity(0.3),
                width: isEmergencyStop ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text(
                          'EMERGENCY TRADING STOP',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: isEmergencyStop,
                      activeColor: Colors.redAccent,
                      onChanged: (val) => state.toggleEmergencyStop(val),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isEmergencyStop
                    ? '⚠️ EMERGENCY STOP ACTIVE: All new order placement is blocked immediately.'
                    : 'Emergency control. Toggle to halt all new order placement immediately in volatile market events.',
                  style: TextStyle(
                    color: isEmergencyStop ? Colors.redAccent.shade100 : Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. AUTOMATIC SELLING OPT-IN CONTROL
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AUTOMATIC SELLING (OPT-IN)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                    Switch(
                      value: isAutoSell,
                      activeColor: Colors.greenAccent,
                      onChanged: (val) => state.updateSafetySettings(autoSellEnabled: val),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Default operating mode is notification-first. When enabled, the app automatically submits sell orders when your configured Stop-loss, Target, or 24/48h holding period is reached.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131722),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '🔒 Note: Automatic buying remains STRICTLY DISABLED at all times. Every buy order requires explicit manual confirmation.',
                    style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. GROWW TRADING API & TOTP AUTHENTICATION
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: state.isGrowwConnected ? Colors.teal.withOpacity(0.4) : Colors.white.withOpacity(0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance,
                          color: state.isGrowwConnected ? Colors.tealAccent : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'GROWW BROKER INTEGRATION',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: safety?.executionMode == 'GROWW_LIVE'
                            ? Colors.green.withOpacity(0.2)
                            : (state.isGrowwConnected ? Colors.teal.withOpacity(0.2) : Colors.blue.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: safety?.executionMode == 'GROWW_LIVE'
                              ? Colors.greenAccent
                              : (state.isGrowwConnected ? Colors.tealAccent : Colors.lightBlueAccent),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        safety?.executionMode == 'GROWW_LIVE' ? 'LIVE' : (state.isGrowwConnected ? 'CONNECTED' : 'PAPER'),
                        style: TextStyle(
                          color: safety?.executionMode == 'GROWW_LIVE'
                              ? Colors.greenAccent
                              : (state.isGrowwConnected ? Colors.tealAccent : Colors.lightBlueAccent),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Uses official Groww Trade API with documented TOTP authentication flow. Manage credentials, TOTP key, and execution mode directly inside the app.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                ),
                if (state.isGrowwConnected) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131722),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Available Funds:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          '₹${state.funds?.availableFunds.toStringAsFixed(2) ?? "1,00,000.00"}',
                          style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => GrowwLoginDialog.show(context),
                    icon: const Icon(Icons.login, size: 16),
                    label: Text(
                      state.isGrowwConnected ? 'Manage Groww Broker & Credentials' : 'Log In to Groww Broker Account',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.lightBlueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isAuthenticatingGroww ? null : _refreshGrowwAuth,
                    icon: isAuthenticatingGroww
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('Fast Refresh Groww TOTP Session', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Backend Server Connection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BACKEND API URL (CLOUD / SERVER)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  'Production Cloud URL (e.g. https://stock-ai.onrender.com) or local network address. Note: Physical phones require HTTPS cloud or local Wi-Fi IP; "localhost" will not work on a real phone.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'https://your-app.onrender.com',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: const Color(0xFF131722),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      backgroundColor: Colors.teal.shade900.withOpacity(0.4),
                      side: const BorderSide(color: Colors.tealAccent),
                      label: const Text('☁️ 24/7 Cloud (Render)', style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _connectToCloud,
                    ),
                    ActionChip(
                      backgroundColor: const Color(0xFF131722),
                      side: BorderSide(color: Colors.tealAccent.withOpacity(0.4)),
                      label: const Text('🔍 Auto-Detect', style: TextStyle(color: Colors.tealAccent, fontSize: 11)),
                      onPressed: _autoDetectUrl,
                    ),
                    ActionChip(
                      backgroundColor: const Color(0xFF131722),
                      side: BorderSide(color: Colors.blueAccent.withOpacity(0.4)),
                      label: const Text('⚡ Local PC (Hotspot)', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
                      onPressed: () {
                        _urlController.text = 'http://10.246.109.77:8000';
                        _saveUrl();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: isSaving ? null : _saveUrl,
                      child: isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save & Test', style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    if (connectionStatus != null)
                      Expanded(
                        child: Text(
                          connectionStatus!,
                          style: TextStyle(
                            color: connectionStatus!.contains('success') ? Colors.greenAccent : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. PUSH NOTIFICATIONS & FIREBASE (FCM)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active, color: Colors.blueAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'FIREBASE PUSH ALERTS (FCM)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Delivers real-time breakout signals, risk warnings, and order updates to your Android phone even when the app is backgrounded or closed.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, height: 1.3),
                ),
                const SizedBox(height: 12),
                _buildSettingRow(
                  'Device FCM Status',
                  _fcmToken != null && _fcmToken!.isNotEmpty ? 'Token Registered' : 'Active (Local Notification Fallback)',
                ),
                if (_fcmToken != null && _fcmToken!.isNotEmpty)
                  _buildSettingRow(
                    'Device Token',
                    '${_fcmToken!.substring(0, 10)}...${_fcmToken!.substring(_fcmToken!.length - 6)}',
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF131722)),
                  onPressed: isTestingPush ? null : _sendTestPush,
                  icon: isTestingPush
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_to_mobile, size: 16, color: Colors.blueAccent),
                  label: const Text('Send Test Push Alert', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Market & Risk Parameters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONFIGURED RISK LIMITS',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _buildSettingRow('Primary Exchange', 'NSE (National Stock Exchange)'),
                _buildSettingRow('Trading Hours', '09:15 - 15:30 IST'),
                _buildSettingRow('Max Portfolio Exposure', '${safety?.maxPortfolioExposurePct ?? 25}% of total capital'),
                _buildSettingRow('Max Single Stock Cap', '${safety?.maxSingleStockPct ?? 10}% of total capital'),
                _buildSettingRow('Max Position Risk', '${safety?.maxPositionRiskPct ?? 2}% of capital'),
                _buildSettingRow('Minimum Risk/Reward', '1.5 : 1'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Security & Storage
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRIVACY & SECURITY',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Self-hosted deployment. Broker secrets, API tokens, and private keys remain securely on your Linux workstation.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: () async {
                    await StorageService.clearAuthToken();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cleared stored authentication tokens.')),
                    );
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Clear Cached Auth Tokens'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
