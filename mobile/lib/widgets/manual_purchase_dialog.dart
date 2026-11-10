import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class ManualPurchaseDialog extends StatefulWidget {
  final String symbol;
  final String? companyName;
  final double? currentPrice;
  final double? targetPrice;
  final double? stopLossPrice;
  final String? exchange;

  const ManualPurchaseDialog({
    super.key,
    required this.symbol,
    this.companyName,
    this.currentPrice,
    this.targetPrice,
    this.stopLossPrice,
    this.exchange,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String symbol,
    String? companyName,
    double? currentPrice,
    double? targetPrice,
    double? stopLossPrice,
    String? exchange,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ManualPurchaseDialog(
        symbol: symbol,
        companyName: companyName,
        currentPrice: currentPrice,
        targetPrice: targetPrice,
        stopLossPrice: stopLossPrice,
        exchange: exchange,
      ),
    );
  }

  @override
  State<ManualPurchaseDialog> createState() => _ManualPurchaseDialogState();
}

class _ManualPurchaseDialogState extends State<ManualPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _symbolController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _chargesController;
  late TextEditingController _targetController;
  late TextEditingController _stopLossController;

  late String _selectedExchange;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSubmitting = false;

  bool get _isUS => (_selectedExchange == 'US' || _selectedExchange == 'NASDAQ' || _selectedExchange == 'NYSE');
  String get _currencySymbol => _isUS ? '\$' : '₹';

  @override
  void initState() {
    super.initState();
    _selectedExchange = (widget.exchange != null && widget.exchange!.isNotEmpty)
        ? widget.exchange!.toUpperCase()
        : 'NSE';
    _symbolController = TextEditingController(text: widget.symbol);
    _nameController = TextEditingController(text: widget.companyName ?? widget.symbol);
    _priceController = TextEditingController(
      text: widget.currentPrice != null && widget.currentPrice! > 0
          ? widget.currentPrice!.toStringAsFixed(2)
          : '',
    );
    _quantityController = TextEditingController(text: '10');
    _chargesController = TextEditingController(text: '0.00');
    _targetController = TextEditingController(
      text: widget.targetPrice != null ? widget.targetPrice!.toStringAsFixed(2) : '',
    );
    _stopLossController = TextEditingController(
      text: widget.stopLossPrice != null ? widget.stopLossPrice!.toStringAsFixed(2) : '',
    );

    _priceController.addListener(() => setState(() {}));
    _quantityController.addListener(() => setState(() {}));
    _chargesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _chargesController.dispose();
    _targetController.dispose();
    _stopLossController.dispose();
    super.dispose();
  }

  double get _calculatedInvestment {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final charges = double.tryParse(_chargesController.text) ?? 0.0;
    return (price * qty) + charges;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.greenAccent,
            surface: Color(0xFF1E222D),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.greenAccent,
            surface: Color(0xFF1E222D),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final symbol = _symbolController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final price = double.parse(_priceController.text.trim());
    final quantity = int.parse(_quantityController.text.trim());
    final charges = double.tryParse(_chargesController.text.trim()) ?? 0.0;
    final target = double.tryParse(_targetController.text.trim());
    final sl = double.tryParse(_stopLossController.text.trim());

    final dateStr =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00';

    setState(() => _isSubmitting = true);

    try {
      final state = context.read<AppState>();
      final effectiveEx = _selectedExchange;
      final res = await state.recordManualPurchase(
        symbol: symbol,
        exchange: effectiveEx,
        companyName: name,
        actualPrice: price,
        quantity: quantity,
        purchaseDate: dateStr,
        purchaseTime: timeStr,
        charges: charges,
        customTarget: target,
        customStopLoss: sl,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res['message'] ?? 'Successfully recorded purchase of $quantity shares of $symbol!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Failed to record purchase: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E222D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Colors.greenAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'I BOUGHT THIS STOCK',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _isUS ? 'US Broker Purchase Entry (USD)' : 'Groww Broker Purchase Entry (INR)',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Market Selector (India NSE vs US Stocks)
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(
                          child: Text('🇮🇳 Indian (NSE)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                        selected: !_isUS,
                        selectedColor: Colors.blueAccent.withOpacity(0.35),
                        side: BorderSide(color: !_isUS ? Colors.blueAccent : Colors.white12),
                        onSelected: (val) {
                          if (val) setState(() => _selectedExchange = 'NSE');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(
                          child: Text('🌐 US Stocks (\$)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                        selected: _isUS,
                        selectedColor: Colors.blueAccent.withOpacity(0.35),
                        side: BorderSide(color: _isUS ? Colors.blueAccent : Colors.white12),
                        onSelected: (val) {
                          if (val) setState(() => _selectedExchange = 'US');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Investment Preview Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131722),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Investment:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(
                        '$_currencySymbol${_calculatedInvestment.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Symbol & Company Name
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _symbolController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Stock Symbol',
                          labelStyle: TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Color(0xFF131722),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white70),
                        decoration: const InputDecoration(
                          labelText: 'Company Name',
                          labelStyle: TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Color(0xFF131722),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Price and Quantity
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Purchase Price ($_currencySymbol)*',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF131722),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final val = double.tryParse(v);
                          if (val == null || val <= 0) return 'Invalid price';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Quantity (Shares)*',
                          labelStyle: TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Color(0xFF131722),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final val = int.tryParse(v);
                          if (val == null || val <= 0) return 'Min 1 share';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Purchase Date & Time
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131722),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131722),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                              const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Brokerage / Charges
                TextFormField(
                  controller: _chargesController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white70),
                  decoration: InputDecoration(
                    labelText: 'Brokerage & Other Charges ($_currencySymbol) (Optional)',
                    labelStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF131722),
                  ),
                ),
                const SizedBox(height: 12),

                // Custom Target & Stop-Loss
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _targetController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.greenAccent),
                        decoration: InputDecoration(
                          labelText: 'Custom Target ($_currencySymbol)',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF131722),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _stopLossController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.redAccent),
                        decoration: InputDecoration(
                          labelText: 'Custom Stop-Loss ($_currencySymbol)',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF131722),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text(
                            'CONFIRM & START MONITORING',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
