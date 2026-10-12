import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class GrowwLoginDialog extends StatefulWidget {
  const GrowwLoginDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const GrowwLoginDialog(),
    );
  }

  @override
  State<GrowwLoginDialog> createState() => _GrowwLoginDialogState();
}

class _GrowwLoginDialogState extends State<GrowwLoginDialog> {
  final _apiKeyController = TextEditingController();
  final _apiSecretController = TextEditingController();
  final _totpKeyController = TextEditingController();
  final _authTokenController = TextEditingController();
  bool _enableLiveTrading = false;
  bool _isLoading = false;
  bool _obscureSecret = true;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _totpKeyController.dispose();
    _authTokenController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final state = context.read<AppState>();
    final success = await state.loginGroww(
      apiKey: _apiKeyController.text.trim(),
      apiSecret: _apiSecretController.text.trim(),
      totpKey: _totpKeyController.text.trim(),
      authToken: _authTokenController.text.trim(),
      orderExecutionEnabled: _enableLiveTrading,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isSuccess = success;
        _statusMessage = success
            ? 'Successfully connected to Groww Trading API!'
            : state.errorMessage ?? 'Login failed. Please check your credentials.';
      });
      if (success) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    await context.read<AppState>().logoutGroww();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Disconnected. Reverted to safe paper trading.';
        _isSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isConnected = state.isGrowwConnected;
    final funds = state.funds;

    return Dialog(
      backgroundColor: const Color(0xFF1E222D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.account_balance, color: Colors.tealAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Groww Broker Login',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isConnected ? '● Connected & Active' : 'Official Trade API Integration',
                            style: TextStyle(
                              color: isConnected ? Colors.greenAccent : Colors.grey.shade400,
                              fontSize: 11,
                              fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Banner if connected
              if (isConnected) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Available Margin (Groww):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            '₹${funds?.availableFunds.toStringAsFixed(2) ?? "1,00,000.00"}',
                            style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Execution Mode:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(
                            state.safetyStatus?.executionMode ?? 'PAPER',
                            style: TextStyle(
                              color: state.safetyStatus?.executionMode == 'GROWW_LIVE' ? Colors.orangeAccent : Colors.lightBlueAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '✅ Official TOTP authentication active. Buy orders still require manual user approval.',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading ? null : _handleLogout,
                        icon: const Icon(Icons.link_off, size: 16),
                        label: const Text('Disconnect Broker'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() => _isLoading = true);
                                await state.api.refreshGrowwAuth();
                                await state.refreshGrowwStatus();
                                if (mounted) setState(() => _isLoading = false);
                              },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Refresh TOTP'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Credentials Input Form
                Text(
                  'Log in using your Groww Trading API credentials. Your keys and TOTP secret stay encrypted on your local backend server.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 14),

                // TOTP Key Field
                const Text('Groww TOTP Secret Key:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _totpKeyController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. JBSWY3DPEHPK3PXP',
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF131722),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),

                // API Key Field
                const Text('API Key / Client ID:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _apiKeyController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Your Groww Developer API Key',
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF131722),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 10),

                // API Secret Field
                const Text('API Secret:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _apiSecretController,
                  obscureText: _obscureSecret,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Groww API Secret',
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF131722),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureSecret ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 18),
                      onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Auth Token Option (Alternative)
                const Text('OR Direct API Auth Token (Optional):', style: TextStyle(color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 4),
                TextField(
                  controller: _authTokenController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Direct Bearer / Auth Token if generated externally',
                    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF131722),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),

                // Execution Mode Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131722),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Enable Live Broker Orders', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(
                            _enableLiveTrading ? 'Real-money execution' : 'Simulated Paper Trading (Safe)',
                            style: TextStyle(color: _enableLiveTrading ? Colors.amberAccent : Colors.lightBlueAccent, fontSize: 10),
                          ),
                        ],
                      ),
                      Switch(
                        value: _enableLiveTrading,
                        activeColor: Colors.tealAccent,
                        onChanged: (val) => setState(() => _enableLiveTrading = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Submit Login Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Log In & Authenticate Groww',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
              ],

              // Status feedback
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _isSuccess ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
