import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../state/app_state.dart';
import '../models/signal.dart';
import '../models/order.dart';
import '../models/prediction.dart';
import '../widgets/signal_pill.dart';
import '../widgets/priority_badge.dart';
import '../widgets/groww_login_dialog.dart';

class StockRecommendationScreen extends StatefulWidget {
  final String symbol;
  final String exchange;
  final StockSignal? initialSignal;

  const StockRecommendationScreen({
    super.key,
    required this.symbol,
    this.exchange = 'NSE',
    this.initialSignal,
  });

  @override
  State<StockRecommendationScreen> createState() => _StockRecommendationScreenState();
}

class _StockRecommendationScreenState extends State<StockRecommendationScreen> {
  StockSignal? signal;
  StockPrediction? prediction;
  List<Map<String, dynamic>> candles = [];
  bool isLoading = true;
  bool isRegeneratingThesis = false;
  bool isPredictingLive = false;
  bool showAlgorithmDetails = true;
  String? error;

  // Investment Amount & Risk Input State
  final TextEditingController _amountController = TextEditingController(text: '5000');
  late TextEditingController _stopLossController;
  late TextEditingController _targetController;
  int _holdingPeriodHours = 48;
  bool _autoSellEnabled = true;

  // Live Calculated Metrics
  OrderCalculation? calculation;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    signal = widget.initialSignal;
    _stopLossController = TextEditingController(
      text: signal?.stopLoss?.toStringAsFixed(2) ?? '',
    );
    _targetController = TextEditingController(
      text: signal?.target?.toStringAsFixed(2) ?? '',
    );
    _holdingPeriodHours = signal?.holdingPeriodHours ?? 48;

    _amountController.addListener(_onInputsChanged);
    _stopLossController.addListener(_onInputsChanged);
    _targetController.addListener(_onInputsChanged);

    _fetchDetails();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _amountController.dispose();
    _stopLossController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _onInputsChanged() {
    _updateInstantClientCalculation();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _recalculateMetrics();
    });
  }

  OrderCalculation _computeClientCalculation({
    required double price,
    required double inputAmount,
    required double? stopLoss,
    required double? target,
    required int holdingHours,
    required double availableFunds,
  }) {
    final sl = stopLoss ?? (price * 0.97);
    final tp = target ?? (price * 1.05);
    final shares = (price > 0 && inputAmount > 0) ? (inputAmount / price).floor() : 0;
    final isAmountEnough = shares >= 1;
    final displayShares = isAmountEnough ? shares : 1;
    final estInvestment = isAmountEnough ? (shares * price) : (1 * price);

    // Approximate delivery charges for instant feedback
    final buyBrokerage = (estInvestment * 0.0005).clamp(0.0, 20.0);
    final buyStt = estInvestment * 0.001;
    final buyOther = estInvestment * 0.0002;
    final buyChargesTotal = buyBrokerage + buyStt + buyOther;

    final targetVal = displayShares * tp;
    final targetCharges = (targetVal * 0.0005).clamp(0.0, 20.0) + (targetVal * 0.001) + 15.93;
    final roundtripCharges = buyChargesTotal + targetCharges;

    final profitNet = (targetVal - estInvestment) - roundtripCharges;
    final profitPct = estInvestment > 0 ? (profitNet / estInvestment) * 100 : 0.0;

    final slVal = displayShares * sl;
    final lossNet = (estInvestment - slVal) + roundtripCharges;
    final lossPct = estInvestment > 0 ? (lossNet / estInvestment) * 100 : 0.0;

    final risk = price - sl;
    final reward = tp - price;
    final rr = (risk > 0 && reward > 0) ? reward / risk : 0.0;

    final warnings = <String>[];
    if (inputAmount > 0 && !isAmountEnough) {
      warnings.add('Entered ₹${inputAmount.toStringAsFixed(0)} is below 1 share price ₹${price.toStringAsFixed(2)}. Need at least ₹${price.ceil()} for 1 whole share.');
    }
    if (estInvestment > availableFunds) {
      warnings.add('Estimated investment ₹${estInvestment.toStringAsFixed(2)} exceeds available broker margin ₹${availableFunds.toStringAsFixed(2)}.');
    }
    if (sl >= price) {
      warnings.add('Stop-loss (₹${sl.toStringAsFixed(2)}) must be below entry price (₹${price.toStringAsFixed(2)}).');
    }
    if (tp <= price) {
      warnings.add('Target (₹${tp.toStringAsFixed(2)}) must be above entry price (₹${price.toStringAsFixed(2)}).');
    }

    return OrderCalculation(
      isValid: isAmountEnough && sl < price && tp > price,
      sharesQuantity: isAmountEnough ? shares : 0,
      verifiedEntryPrice: price,
      estimatedInvestment: isAmountEnough ? estInvestment : 0.0,
      totalOutlay: isAmountEnough ? (estInvestment + buyChargesTotal) : 0.0,
      buyCharges: {'total_charges': buyChargesTotal},
      roundtripTargetCharges: roundtripCharges,
      roundtripSlCharges: roundtripCharges,
      potentialProfitNet: profitNet,
      potentialProfitPct: profitPct,
      potentialLossNet: lossNet,
      potentialLossPct: lossPct,
      riskRewardRatio: rr,
      remainingAvailableFunds: (availableFunds - (isAmountEnough ? estInvestment : 0)).clamp(0.0, double.infinity),
      holdingPeriodHours: holdingHours,
      warnings: warnings,
    );
  }

  void _updateInstantClientCalculation() {
    if (signal == null) return;
    final price = signal!.price;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final sl = double.tryParse(_stopLossController.text);
    final tp = double.tryParse(_targetController.text);
    final funds = context.read<AppState>().funds?.availableFunds ?? 100000.0;

    final clientCalc = _computeClientCalculation(
      price: price,
      inputAmount: amount,
      stopLoss: sl,
      target: tp,
      holdingHours: _holdingPeriodHours,
      availableFunds: funds,
    );
    if (mounted) {
      setState(() {
        calculation = clientCalc;
      });
    }
  }

  void _adjustShares(int delta) {
    if (signal == null || signal!.price <= 0) return;
    final price = signal!.price;
    final currentAmount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    int currentShares = (currentAmount / price).floor();
    if (currentShares < 1 && delta > 0) {
      currentShares = 0;
    }
    int newShares = currentShares + delta;
    if (newShares < 1) newShares = 1;
    final newAmount = (newShares * price).round();
    _amountController.text = newAmount.toString();
  }

  void _setSharesQuantity(int shares) {
    if (signal == null || signal!.price <= 0) return;
    final price = signal!.price;
    final qty = shares < 1 ? 1 : shares;
    final newAmount = (qty * price).round();
    _amountController.text = newAmount.toString();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    final api = context.read<AppState>().api;
    try {
      final sigFuture = (signal != null && signal!.aiThesis != null)
          ? Future.value(signal!)
          : api.getStockRecommendation(widget.symbol, exchange: widget.exchange);
      final candleFuture = api.getStockCandles(widget.symbol);
      final predFuture = context.read<AppState>().getOrFetchPrediction(widget.symbol, exchange: widget.exchange);

      final results = await Future.wait([sigFuture, candleFuture, predFuture]);
      final fetchedSignal = results[0] as StockSignal;
      final fetchedPred = results[2] as StockPrediction?;

      setState(() {
        signal = fetchedSignal;
        candles = results[1] as List<Map<String, dynamic>>;
        prediction = fetchedPred;
        if (_stopLossController.text.isEmpty && (fetchedPred?.stopLoss != null || fetchedSignal.stopLoss != null)) {
          _stopLossController.text = (fetchedPred?.stopLoss ?? fetchedSignal.stopLoss!).toStringAsFixed(2);
        }
        if (_targetController.text.isEmpty && (fetchedPred?.targetPrice != null || fetchedSignal.target != null)) {
          _targetController.text = (fetchedPred?.targetPrice ?? fetchedSignal.target!).toStringAsFixed(2);
        }
        _holdingPeriodHours = fetchedSignal.holdingPeriodHours;

        // Ensure default amount is at least 1 or 2 shares
        final currentAmount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
        if (currentAmount < fetchedSignal.price) {
          final defShares = fetchedSignal.price > 5000 ? 1 : (5000 / fetchedSignal.price).ceil();
          _amountController.text = (defShares * fetchedSignal.price).round().toString();
        }

        isLoading = false;
      });

      _updateInstantClientCalculation();
      _recalculateMetrics();
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _runGeminiPrediction() async {
    setState(() => isPredictingLive = true);
    try {
      final p = await context.read<AppState>().runGeminiPrediction(widget.symbol, exchange: widget.exchange);
      if (mounted) {
        setState(() {
          prediction = p;
          isPredictingLive = false;
          if (p != null) {
            _targetController.text = p.targetPrice.toStringAsFixed(2);
            if (p.stopLoss != null) {
              _stopLossController.text = p.stopLoss!.toStringAsFixed(2);
            }
          }
        });
        _updateInstantClientCalculation();
        _recalculateMetrics();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Gemini predicted: ${p?.predictedDirection ?? 'Setup'} target ₹${p?.targetPrice.toStringAsFixed(2)} (${p?.confidenceScore.toStringAsFixed(0)}% confidence)!'),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isPredictingLive = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prediction error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _regenerateThesis() async {
    if (signal == null) return;
    setState(() => isRegeneratingThesis = true);
    try {
      final api = context.read<AppState>().api;
      final updatedSignal = await api.regenerateAIThesis(signal!.id);
      if (!mounted) return;
      setState(() {
        signal = updatedSignal;
        isRegeneratingThesis = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI Investment Thesis regenerated with latest market confluence!'),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isRegeneratingThesis = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not regenerate AI thesis: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _recalculateMetrics() async {
    if (signal == null) return;
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    if (amount <= 0) return;

    final sl = double.tryParse(_stopLossController.text);
    final tp = double.tryParse(_targetController.text);

    try {
      final calc = await context.read<AppState>().api.calculateOrderMetrics(
            symbol: widget.symbol,
            investmentAmount: amount,
            entryPrice: signal!.price,
            stopLoss: sl,
            target: tp,
            holdingPeriodHours: _holdingPeriodHours,
          );
      if (mounted) {
        setState(() => calculation = calc);
      }
    } catch (_) {}
  }

  void _setQuickAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(0);
  }

  Future<void> _initiateBuyFlow() async {
    if (signal == null) return;
    final appState = context.read<AppState>();
    final api = appState.api;

    // Safety checks
    if (appState.safetyStatus?.emergencyStopEnabled == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot proceed: Emergency Trading Stop is ACTIVE.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid investment amount.')),
      );
      return;
    }

    final price = signal!.price;
    final shares = price > 0 ? (amount / price).floor() : 0;
    if (shares < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount ₹${amount.toStringAsFixed(0)} is below 1 share (₹${price.toStringAsFixed(2)}). Minimum 1 share required.'),
          backgroundColor: Colors.amber.shade900,
          action: SnackBarAction(
            label: 'Set 1 Share',
            textColor: Colors.white,
            onPressed: () => _setSharesQuantity(1),
          ),
        ),
      );
      return;
    }

    final sl = double.tryParse(_stopLossController.text) ?? (signal!.price * 0.97);
    final tp = double.tryParse(_targetController.text) ?? (signal!.price * 1.05);

    // Show preparation loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      ),
    );

    try {
      final prepared = await api.prepareBuyOrder(
        symbol: widget.symbol,
        investmentAmount: amount,
        expectedPrice: signal!.price,
        stopLoss: sl,
        target: tp,
        holdingPeriodHours: _holdingPeriodHours,
        signalId: signal!.id,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close preparation loading

      // Show Final Confirmation Screen
      _showFinalConfirmationDialog(prepared);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order preparation failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showFinalConfirmationDialog(PreparedBuyOrder prepared) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E222D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ORDER CONFIRMATION',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'BUY ${prepared.symbol} (${prepared.exchange})',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Slippage Warning Banner (if price moved)
                  if (prepared.priceChanged && prepared.slippageWarning != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade900.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amberAccent.shade400),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              prepared.slippageWarning!,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Execution Mode & Broker Badge
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
                        Row(
                          children: [
                            Icon(
                              prepared.mode == 'GROWW_LIVE' ? Icons.verified : Icons.science,
                              color: prepared.mode == 'GROWW_LIVE' ? Colors.greenAccent : Colors.lightBlueAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              prepared.mode == 'GROWW_LIVE'
                                  ? 'Official Groww Trade API (Live)'
                                  : 'Paper Trading Mode (Simulated)',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Text(
                          '${prepared.holdingPeriodHours}h Hold',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Parameter Table
                  _buildSummaryRow('Verified Quote:', '₹${prepared.verifiedCurrentPrice.toStringAsFixed(2)}'),
                  _buildSummaryRow('Executed Shares:', '${prepared.sharesQuantity} shares (Whole Shares)'),
                  _buildSummaryRow('Investment Capital:', '₹${prepared.estimatedInvestment.toStringAsFixed(2)}'),
                  _buildSummaryRow('Est. Charges & Taxes:', '₹${prepared.totalCharges.toStringAsFixed(2)}'),
                  _buildSummaryRow('Total Cash Required:', '₹${prepared.totalOutlay.toStringAsFixed(2)}', isBold: true),
                  _buildSummaryRow('Configured Stop-Loss:', '₹${prepared.stopLoss.toStringAsFixed(2)}', color: Colors.redAccent),
                  _buildSummaryRow('Configured Target:', '₹${prepared.target.toStringAsFixed(2)}', color: Colors.greenAccent),
                  const Divider(color: Colors.white12, height: 20),

                  // Automatic Position Exit & Take Money Setting
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Row(
                      children: [
                        Icon(Icons.bolt, color: Colors.amberAccent, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Auto Take Money & Auto-Sell on Target',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    subtitle: const Text(
                      'Submits sell order automatically when Target (+5% to +15%), Stop-Loss, or holding period is met to lock in profits.',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    value: _autoSellEnabled,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) {
                      setModalState(() => _autoSellEnabled = val);
                      setState(() => _autoSellEnabled = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Mandatory Explicit User Confirmation Notice
                  const Text(
                    'MANDATORY CONFIRMATION: The AI cannot purchase stocks on its own. '
                    'Tapping "Confirm & Place Buy Order" grants explicit authorization to submit this order.',
                    style: TextStyle(color: Colors.white60, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),

                  // Final Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _executeConfirmedBuy(prepared);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        'CONFIRM & PLACE BUY ORDER (₹${prepared.totalOutlay.toStringAsFixed(2)})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
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

  Future<void> _executeConfirmedBuy(PreparedBuyOrder prepared) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.greenAccent),
            SizedBox(height: 16),
            Text(
              'Submitting & Verifying Order with Broker...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );

    try {
      final order = await context.read<AppState>().api.confirmBuyOrder(
            clientOrderId: prepared.clientOrderId,
            symbol: prepared.symbol,
            investmentAmount: prepared.estimatedInvestment,
            confirmedPrice: prepared.verifiedCurrentPrice,
            quantity: prepared.sharesQuantity,
            stopLoss: prepared.stopLoss,
            target: prepared.target,
            holdingPeriodHours: prepared.holdingPeriodHours,
            autoSellEnabled: _autoSellEnabled,
            signalId: signal?.id,
          );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      // Refresh portfolio and funds
      await context.read<AppState>().refreshAll();

      _showExecutionSuccessDialog(order);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E222D),
          title: const Text('Order Submission Notice', style: TextStyle(color: Colors.redAccent)),
          content: Text(e.toString(), style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      );
    }
  }

  void _showExecutionSuccessDialog(ConfirmedOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
            SizedBox(width: 10),
            Text('Order Verified & Executed', style: TextStyle(color: Colors.white, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Successfully purchased ${order.filledQuantity} shares of ${order.symbol} at ₹${order.executedPrice?.toStringAsFixed(2) ?? order.requestedPrice.toStringAsFixed(2)}.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131722),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order ID: ${order.orderId}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('Status: ${order.status}', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('Holding Period: ${order.holdingPeriodHours} Hours', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                  Text('Auto-Selling: ${order.autoSellEnabled ? "ENABLED" : "DISABLED"}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  const Text('✅ Position registered for continuous monitoring.', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text('Close', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentPrice = signal?.price ?? (candles.isNotEmpty ? (candles.last['close'] as num).toDouble() : 0.0);
    final isWatched = state.isWatchlisted(widget.symbol);

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              signal?.companyName ?? '${widget.symbol} (${widget.exchange})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${widget.symbol} • ${widget.exchange}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isWatched ? 'Remove from Watchlist' : 'Add to Watchlist',
            icon: Icon(
              isWatched ? Icons.star : Icons.star_border,
              color: isWatched ? Colors.amberAccent : Colors.grey,
            ),
            onPressed: () {
              final willBeWatched = !isWatched;
              state.toggleWatchlist(widget.symbol, exchange: widget.exchange);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(willBeWatched
                      ? '⭐ ${widget.symbol} added to persistent Watchlist!'
                      : '${widget.symbol} removed from Watchlist.'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: willBeWatched ? Colors.teal : Colors.grey.shade800,
                ),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : RefreshIndicator(
              onRefresh: _fetchDetails,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Mandatory Potential Opportunity & Risk Disclaimer Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade900.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'POTENTIAL OPPORTUNITY — NOT GUARANTEED PROFIT\n'
                            'Quantitative decision-support recommendation. The AI never purchases stocks automatically. Every trade requires manual verification.',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Price Header with Data Freshness & Source
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₹${currentPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        signal?.dataFreshness ?? 'Verified Live',
                                        style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      signal?.dataSource ?? 'Groww Trade API',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (signal != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (signal!.priority.isNotEmpty && signal!.priority.toUpperCase() != 'NORMAL') ...[
                                    PriorityBadge(priority: signal!.priority),
                                    const SizedBox(width: 8),
                                  ],
                                  SignalPill(
                                    signalType: signal!.signalType,
                                    strength: signal!.strength,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (signal != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Last updated: ${signal!.timestamp.toLocal().toString().substring(0, 16)}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Price Trend Chart
                  if (candles.isNotEmpty)
                    Container(
                      height: 170,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222D),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: candles
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), (e.value['close'] as num).toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: Colors.blueAccent,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blueAccent.withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Gemini AI Live Stock Prediction & Working Algorithm
                  _buildGeminiPredictionCard(),

                  // 4. Explainable AI Investment Thesis Card (Phase 3 Core)
                  if (signal != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222D),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.25), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Header & Model Pill + Re-analyze Action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI INVESTMENT THESIS',
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (isRegeneratingThesis)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                                )
                              else
                                InkWell(
                                  onTap: _regenerateThesis,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.cyan.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.refresh, color: Colors.cyanAccent, size: 12),
                                        SizedBox(width: 4),
                                        Text('Re-analyze', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Model & Intended Holding Badge Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131722),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  '🤖 ${signal!.aiModelUsed}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(
                                '${signal!.strategyName.toUpperCase()} • ${signal!.holdingPeriodHours}h Hold',
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // AI Headline Banner (if present)
                          if (signal!.aiHeadline != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131F2E),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                              ),
                              child: Text(
                                signal!.aiHeadline!,
                                style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12, height: 1.3),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Strategy Execution Levels
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLevelTile('Stop-Loss', '₹${signal!.stopLoss ?? 'N/A'}', Colors.redAccent),
                              _buildLevelTile('Proposed Entry', '₹${signal!.entryRangeLow ?? currentPrice}', Colors.blueAccent),
                              _buildLevelTile('Target Price', '₹${signal!.target ?? 'N/A'}', Colors.greenAccent),
                              _buildLevelTile('Risk/Reward', '${signal!.riskReward ?? 'N/A'}', Colors.amberAccent),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 20),

                          // Scoring Breakdown Chips
                          if (signal!.scoreBreakdown != null) ...[
                            const Text(
                              'Confluence Scoring Breakdown:',
                              style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: signal!.scoreBreakdown!.entries.map((e) {
                                return Chip(
                                  backgroundColor: const Color(0xFF131722),
                                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                  label: Text(
                                    '${e.key.replaceAll('_', ' ').toUpperCase()}: ${e.value}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Explainable Investment Thesis Narrative
                          const Text(
                            'AI Investment Rationale:',
                            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            signal!.aiInvestmentThesis,
                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                          ),
                          const SizedBox(height: 14),

                          // Technical Confluence Matrix (4-Grid Display)
                          if (signal!.aiTechnicalSummary != null) ...[
                            const Text(
                              'Technical Confluence Matrix:',
                              style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131722),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMatrixCell('Trend', signal!.aiTechnicalSummary!['trend']?.toString() ?? 'N/A', Colors.lightBlueAccent),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMatrixCell('Momentum', signal!.aiTechnicalSummary!['momentum']?.toString() ?? 'N/A', Colors.tealAccent),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildMatrixCell('Volume', signal!.aiTechnicalSummary!['volume_profile']?.toString() ?? 'N/A', Colors.amberAccent),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _buildMatrixCell('Volatility', signal!.aiTechnicalSummary!['volatility']?.toString() ?? 'N/A', Colors.purpleAccent),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Tactical Trade Plan Summary
                          if (signal!.aiTacticalPlan != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF182232),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Tactical Trade Execution Plan:', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  if (signal!.aiTacticalPlan!['entry_zone'] != null)
                                    Text('• Entry Zone: ${signal!.aiTacticalPlan!['entry_zone']}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  if (signal!.aiTacticalPlan!['stop_loss'] != null)
                                    Text('• Stop Loss: ${signal!.aiTacticalPlan!['stop_loss']}', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                                  if (signal!.aiTacticalPlan!['target_1'] != null)
                                    Text('• Target 1: ${signal!.aiTacticalPlan!['target_1']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                  if (signal!.aiTacticalPlan!['target_2'] != null)
                                    Text('• Target 2: ${signal!.aiTacticalPlan!['target_2']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                  if (signal!.aiTacticalPlan!['time_horizon'] != null)
                                    Text('• Time Horizon: ${signal!.aiTacticalPlan!['time_horizon']}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 5. Key Confluence Catalysts (Why Buy Now)
                    if (signal!.aiCatalysts.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up, color: Colors.greenAccent, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'KEY CONFLUENCE CATALYSTS',
                                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...signal!.aiCatalysts.map((c) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 14),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        c,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 6. Important Risks & Invalidation Condition
                    if (signal!.aiRiskFactors.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'IMPORTANT RISKS (TRADE FAILURE REASONS)',
                                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ...signal!.aiRiskFactors.map((r) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('⚠️ ', style: TextStyle(fontSize: 12)),
                                    Expanded(
                                      child: Text(
                                        r,
                                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (signal!.aiInvalidationTrigger != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade900.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'Invalidation: ${signal!.aiInvalidationTrigger}',
                                  style: TextStyle(color: Colors.orange.shade300, fontSize: 11, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 7. Liquidity & Market News
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LIQUIDITY & MARKET NEWS',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          if (signal!.liquiditySummary != null)
                            Text(
                              signal!.liquiditySummary!,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          if (signal!.financialNews != null && signal!.financialNews!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ...signal!.financialNews!.map((n) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF131722),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '• ${n['title']} [${n['sentiment'] ?? "Neutral"}]',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 7. Interactive Investment Amount Input & Live Calculation Section
                    Builder(
                      builder: (ctx) {
                        final appState = ctx.watch<AppState>();
                        final isGrowwConn = appState.isGrowwConnected;
                        final brokerMargin = appState.funds?.availableFunds ?? 100000.0;
                        final enteredAmount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
                        final sharesCount = currentPrice > 0 ? (enteredAmount / currentPrice).floor() : 0;
                        final isBelowMin = enteredAmount > 0 && sharesCount < 1;
                        final currentSl = double.tryParse(_stopLossController.text);
                        final currentTp = double.tryParse(_targetController.text);
                        final slOffset = (currentSl != null && currentPrice > 0)
                            ? ((currentSl - currentPrice) / currentPrice * 100)
                            : -3.0;
                        final tpOffset = (currentTp != null && currentPrice > 0)
                            ? ((currentTp - currentPrice) / currentPrice * 100)
                            : 5.0;

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
                              // Header with Groww Status / In-App Login Pill
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.tune, color: Colors.lightBlueAccent, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'INVESTMENT & RISK SIZING',
                                        style: TextStyle(
                                          color: Colors.lightBlueAccent,
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

                              // Investment Amount (₹) Field + Whole Shares Stepper
                              const Text('Investment Amount (₹):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _amountController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      decoration: InputDecoration(
                                        prefixText: '₹ ',
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

                                  // Shares Quantity Stepper [ - ] [ N Shares ] [ + ]
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
                                          onPressed: () => _adjustShares(-1),
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
                                              const Text(
                                                'Shares',
                                                style: TextStyle(color: Colors.grey, fontSize: 9),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                                          onPressed: () => _adjustShares(1),
                                          tooltip: 'Increase 1 Share',
                                          constraints: const BoxConstraints(minWidth: 36, minHeight: 46),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Proactive guidance if entered amount is less than 1 share
                              if (isBelowMin) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade900.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '₹${enteredAmount.toStringAsFixed(0)} is less than 1 share (₹${currentPrice.toStringAsFixed(2)}). Min. 1 share required.',
                                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.amber.shade800,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: () => _setSharesQuantity(1),
                                        child: const Text('Set 1 Share', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),

                              // Price-Aware Dynamic Quick Chips
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _buildQuickChips(currentPrice, enteredAmount, sharesCount),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Stop Loss & Target Price Fields with deviation pills
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Stop-loss (₹):', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                            Text(
                                              '${slOffset.toStringAsFixed(1)}%',
                                              style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _stopLossController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color(0xFF131722),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Target (₹):', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                            Text(
                                              '+${tpOffset.toStringAsFixed(1)}%',
                                              style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _targetController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color(0xFF131722),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Holding Period Selector
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Max Holding Period:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Row(
                                    children: [
                                      ChoiceChip(
                                        label: const Text('24 Hours'),
                                        selected: _holdingPeriodHours == 24,
                                        selectedColor: Colors.blueAccent.withOpacity(0.3),
                                        labelStyle: TextStyle(
                                          color: _holdingPeriodHours == 24 ? Colors.blueAccent : Colors.grey,
                                          fontSize: 11,
                                        ),
                                        onSelected: (val) {
                                          if (val) {
                                            setState(() => _holdingPeriodHours = 24);
                                            _recalculateMetrics();
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('48 Hours'),
                                        selected: _holdingPeriodHours == 48,
                                        selectedColor: Colors.blueAccent.withOpacity(0.3),
                                        labelStyle: TextStyle(
                                          color: _holdingPeriodHours == 48 ? Colors.blueAccent : Colors.grey,
                                          fontSize: 11,
                                        ),
                                        onSelected: (val) {
                                          if (val) {
                                            setState(() => _holdingPeriodHours = 48);
                                            _recalculateMetrics();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(color: Colors.white12, height: 24),

                              // Live Recalculated Results Table
                              _buildCalculationRow(
                                'Estimated Whole Shares:',
                                '${calculation?.sharesQuantity ?? (sharesCount >= 1 ? sharesCount : 0)} shares',
                              ),
                              _buildCalculationRow(
                                'Estimated Investment:',
                                '₹${(calculation?.estimatedInvestment ?? (sharesCount * currentPrice)).toStringAsFixed(2)}',
                              ),
                              _buildCalculationRow(
                                'Brokerage & Statutory Charges:',
                                '₹${(calculation?.roundtripTargetCharges ?? 25.0).toStringAsFixed(2)} (Delivery Round-trip)',
                              ),
                              _buildCalculationRow(
                                'Potential Net Profit (Target):',
                                '+₹${(calculation?.potentialProfitNet ?? 0.0).toStringAsFixed(2)} (+${(calculation?.potentialProfitPct ?? 0.0).toStringAsFixed(1)}%)',
                                color: Colors.greenAccent,
                              ),
                              _buildCalculationRow(
                                'Potential Net Loss (Stop-loss):',
                                '-₹${(calculation?.potentialLossNet ?? 0.0).toStringAsFixed(2)} (-${(calculation?.potentialLossPct ?? 0.0).toStringAsFixed(1)}%)',
                                color: Colors.redAccent,
                              ),
                              _buildCalculationRow(
                                'Risk/Reward Ratio:',
                                '1 : ${(calculation?.riskRewardRatio ?? 0.0).toStringAsFixed(2)}',
                                color: Colors.amberAccent,
                              ),
                              _buildCalculationRow(
                                'Remaining Broker Margin:',
                                '₹${(calculation?.remainingAvailableFunds ?? (brokerMargin - (sharesCount * currentPrice))).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                              ),

                              // Risk warnings
                              if (calculation != null && calculation!.warnings.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ...calculation!.warnings.map((w) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text('⚠️ $w', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                                  );
                                }),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // 8. Clearly Labelled Manual BUY Button
                    Builder(
                      builder: (ctx) {
                        final appState = ctx.watch<AppState>();
                        final isGrowwConn = appState.isGrowwConnected;
                        final enteredAmount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
                        final sharesCount = currentPrice > 0 ? (enteredAmount / currentPrice).floor() : 0;
                        final canBuy = sharesCount >= 1;

                        return Column(
                          children: [
                            // Broker Mode Status Badge directly above BUY button
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E222D),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isGrowwConn ? Colors.teal.withOpacity(0.3) : Colors.white10,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isGrowwConn ? Icons.verified : Icons.science_outlined,
                                        size: 16,
                                        color: isGrowwConn ? Colors.greenAccent : Colors.lightBlueAccent,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isGrowwConn
                                            ? 'Broker: Official Groww Trade API'
                                            : 'Broker: Paper Trading Mode (Simulated)',
                                        style: TextStyle(
                                          color: isGrowwConn ? Colors.greenAccent : Colors.lightBlueAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isGrowwConn)
                                    InkWell(
                                      onTap: () => GrowwLoginDialog.show(context),
                                      child: const Text(
                                        'Log In to Groww →',
                                        style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canBuy ? Colors.green.shade600 : Colors.grey.shade800,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: canBuy ? 3 : 0,
                                ),
                                onPressed: canBuy ? _initiateBuyFlow : null,
                                icon: const Icon(Icons.shopping_cart_checkout, size: 22),
                                label: Text(
                                  canBuy
                                      ? 'BUY $sharesCount SHARES — ₹${(calculation?.totalOutlay ?? (sharesCount * currentPrice)).toStringAsFixed(2)}'
                                      : 'ENTER MIN. ₹${currentPrice.ceil()} (1 SHARE)',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Center(
                              child: Text(
                                'Mandatory manual buy approval • The AI never buys automatically • Verified Groww execution',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  List<Widget> _buildQuickChips(double price, double currentAmount, int currentShares) {
    if (price <= 0) return [];
    final chips = <Widget>[];

    // Calculated Suggested 2% Risk-Sizing Chip (Phase 3 Requirement)
    final availFunds = context.read<AppState>().funds?.availableFunds ?? 100000.0;
    final sl = double.tryParse(_stopLossController.text) ?? signal?.stopLoss ?? (price * 0.97);
    final riskPerShare = (price - sl).abs();
    if (riskPerShare > 0.05 && availFunds > 0) {
      final maxCapitalRisk = availFunds * 0.02; // 2% portfolio risk rule
      final suggestedShares = (maxCapitalRisk / riskPerShare).floor().clamp(1, 5000);
      final suggestedAmount = (suggestedShares * price).round();
      final isSelected = currentShares == suggestedShares;
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ActionChip(
            backgroundColor: isSelected ? Colors.amber.shade900.withOpacity(0.6) : Colors.amber.shade900.withOpacity(0.25),
            side: BorderSide(
              color: isSelected ? Colors.amberAccent : Colors.amber.withOpacity(0.5),
              width: isSelected ? 1.5 : 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            avatar: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 14),
            label: Text(
              '🎯 AI 2% Sizing: $suggestedShares Sh (₹$suggestedAmount)',
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
            onPressed: () => _setSharesQuantity(suggestedShares),
          ),
        ),
      );
    }

    // Share count chips: 1 Share, 2 Shares, 5 Shares, 10 Shares
    final shareOptions = [1, 2, 5, 10];
    for (final s in shareOptions) {
      final isSelected = currentShares == s;
      chips.add(
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ActionChip(
            backgroundColor: isSelected ? Colors.teal.shade900.withOpacity(0.5) : const Color(0xFF131722),
            side: BorderSide(
              color: isSelected ? Colors.tealAccent : Colors.white12,
              width: isSelected ? 1.5 : 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            label: Text(
              '$s Sh (₹${(s * price).round()})',
              style: TextStyle(
                color: isSelected ? Colors.tealAccent : Colors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onPressed: () => _setSharesQuantity(s),
          ),
        ),
      );
    }

    // Standard Rupee amounts that are >= price
    final rupeeOptions = [5000, 10000, 25000, 50000, 100000];
    for (final r in rupeeOptions) {
      if (r >= price) {
        final isSelected = currentAmount.round() == r;
        chips.add(
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ActionChip(
              backgroundColor: isSelected ? Colors.blue.shade900.withOpacity(0.5) : const Color(0xFF131722),
              side: BorderSide(
                color: isSelected ? Colors.lightBlueAccent : Colors.white10,
                width: isSelected ? 1.5 : 0.8,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              label: Text(
                '₹${r >= 100000 ? "${r ~/ 100000}L" : "${r ~/ 1000}k"}',
                style: TextStyle(
                  color: isSelected ? Colors.lightBlueAccent : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onPressed: () => _setQuickAmount(r.toDouble()),
            ),
          ),
        );
      }
    }

    return chips;
  }

  Widget _buildLevelTile(String title, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMatrixCell(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeminiPredictionCard() {
    final curPrice = signal?.price ?? (candles.isNotEmpty ? (candles.last['close'] as num).toDouble() : 0.0);
    final pred = prediction;
    final isBull = pred?.isBullish ?? true;
    final dirColor = isBull ? Colors.greenAccent : (pred?.isBearish == true ? Colors.redAccent : Colors.amberAccent);
    final dirBg = isBull ? const Color(0xFF0F291E) : (pred?.isBearish == true ? const Color(0xFF2E1218) : const Color(0xFF1E222D));
    final conf = pred?.confidenceScore ?? 75.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Gemini Branding & Live Predict Trigger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GEMINI AI STOCK PREDICTOR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        pred?.modelUsed ?? 'Google Gemini 3.5 Flash',
                        style: TextStyle(color: Colors.purpleAccent.shade100, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isPredictingLive ? null : _runGeminiPrediction,
                icon: isPredictingLive
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.flash_on, size: 14),
                label: Text(
                  isPredictingLive ? 'Predicting...' : (pred != null ? 'Re-Predict' : 'Run Prediction'),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Prediction Direction, Target & Win Probability
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dirBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dirColor.withOpacity(0.6)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          isBull ? '🚀 BULLISH' : (pred?.isBearish == true ? '🔻 BEARISH' : '⏸️ NEUTRAL'),
                          style: TextStyle(color: dirColor, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: dirColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pred?.predictedAction ?? (isBull ? 'BUY' : 'HOLD'),
                            style: TextStyle(color: dirColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🎯 ${conf.toStringAsFixed(0)}% Confidence',
                        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Predicted Target', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          pred != null ? '₹${pred.targetPrice.toStringAsFixed(2)}' : '₹${(signal?.target ?? curPrice * 1.08).toStringAsFixed(2)}',
                          style: TextStyle(color: dirColor, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (pred != null)
                          Text(
                            '${pred.expectedGainPct >= 0 ? "+" : ""}${pred.expectedGainPct.toStringAsFixed(1)}% expected',
                            style: TextStyle(color: dirColor.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Time Horizon', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E222D),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            pred?.timeHorizon ?? '1-DAY (Swing)',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Stop Loss', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text(
                          (pred != null && pred.stopLoss != null)
                              ? '₹${pred.stopLoss!.toStringAsFixed(2)}'
                              : (signal?.stopLoss != null ? '₹${signal!.stopLoss!.toStringAsFixed(2)}' : '---'),
                          style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text('Defined Risk', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Working Algorithm & Confluence Breakdown
          InkWell(
            onTap: () => setState(() => showAlgorithmDetails = !showAlgorithmDetails),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.memory, color: Colors.cyanAccent, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'WORKING ALGORITHM CONFLUENCE',
                        style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  Icon(
                    showAlgorithmDetails ? Icons.expand_less : Icons.expand_more,
                    color: Colors.cyanAccent,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (showAlgorithmDetails) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10141E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pred?.workingAlgorithm ??
                        '1. Multi-EMA Confluence: Price evaluated against 21-EMA and 50-EMA trend slopes.\n'
                        '2. Momentum Velocity: 14-period RSI tested inside high-probability impulse zone.\n'
                        '3. Volume Accumulation: RVOL surge calculated relative to 20-day moving volume.\n'
                        '4. Volatility Multiplier: 14-Day ATR channel projects dynamic risk-adjusted target.\n'
                        '5. Gemini Neural Synthesis: Validates technical confluence with market catalysts.',
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 11, height: 1.45),
                  ),
                  if (pred?.algorithmMetrics != null) ...[
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final metrics = pred!.algorithmMetrics!;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildMetricPill('RSI (14)', '${metrics['rsi_14'] ?? 50.0}'),
                            _buildMetricPill('RVOL', '${metrics['rvol'] ?? 1.0}x'),
                            _buildMetricPill('21-EMA', '₹${metrics['ema_21'] ?? curPrice}'),
                            _buildMetricPill('14-ATR', '₹${metrics['atr_14'] ?? 10.0}'),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Gemini Executive Synthesis
          if (pred?.aiPredictionSummary != null) ...[
            Text(
              'Gemini Forecast Summary',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              pred!.aiPredictionSummary!,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 10),
          ],

          // Key Catalysts
          if (pred != null && pred.keyCatalysts.isNotEmpty) ...[
            Text(
              'Key Prediction Catalysts',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...pred.keyCatalysts.take(3).map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚡ ', style: TextStyle(fontSize: 10)),
                      Expanded(
                        child: Text(c, style: TextStyle(color: Colors.grey.shade300, fontSize: 11)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],

          // Invalidation Trigger
          if (pred?.invalidationTrigger != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Invalidation: ${pred!.invalidationTrigger!}',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
