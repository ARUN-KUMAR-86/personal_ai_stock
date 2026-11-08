import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/portfolio.dart';

class ManualSaleDialog extends StatefulWidget {
  final Position position;

  const ManualSaleDialog({
    super.key,
    required this.position,
  });

  static Future<bool?> show(BuildContext context, Position position) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => ManualSaleDialog(position: position),
    );
  }

  @override
  State<ManualSaleDialog> createState() => _ManualSaleDialogState();
}

class _ManualSaleDialogState extends State<ManualSaleDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _chargesController;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.position.currentPrice > 0
          ? widget.position.currentPrice.toStringAsFixed(2)
          : widget.position.avgEntryPrice.toStringAsFixed(2),
    );
    _quantityController = TextEditingController(text: widget.position.quantity.toString());
    _chargesController = TextEditingController(text: '0.00');

    _priceController.addListener(() => setState(() {}));
    _quantityController.addListener(() => setState(() {}));
    _chargesController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _chargesController.dispose();
    super.dispose();
  }

  double get _calculatedRealizedPnl {
    final sellPrice = double.tryParse(_priceController.text) ?? 0.0;
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final charges = double.tryParse(_chargesController.text) ?? 0.0;
    return ((sellPrice - widget.position.avgEntryPrice) * qty) - charges;
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
            primary: Colors.redAccent,
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
            primary: Colors.redAccent,
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

    final sellPrice = double.parse(_priceController.text.trim());
    final qtySold = int.parse(_quantityController.text.trim());
    final charges = double.tryParse(_chargesController.text.trim()) ?? 0.0;

    final dateStr =
        '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00';

    setState(() => _isSubmitting = true);

    try {
      final state = context.read<AppState>();
      final res = await state.recordManualSale(
        symbol: widget.position.symbol,
        sellingPrice: sellPrice,
        quantitySold: qtySold,
        sellingDate: dateStr,
        sellingTime: timeStr,
        charges: charges,
      );

      if (mounted) {
        Navigator.pop(context, true);
        final pnl = res['realized_pnl'] ?? _calculatedRealizedPnl;
        final isProfit = pnl >= 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isProfit ? Colors.green.shade800 : Colors.red.shade800,
            content: Row(
              children: [
                Icon(isProfit ? Icons.check_circle : Icons.trending_down, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sale recorded for ${widget.position.symbol}! Realized P/L: ${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}',
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
            content: Text('Failed to record sale: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    final pnl = _calculatedRealizedPnl;
    final isProfit = pnl >= 0;

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
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sell_outlined, color: Colors.redAccent, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'I SOLD THIS STOCK',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${pos.symbol} • ${pos.quantity} Shares Holding',
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
                const SizedBox(height: 16),

                // Realized P/L Preview Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131722),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isProfit ? Colors.greenAccent.withOpacity(0.4) : Colors.redAccent.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated Realized P/L:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            'Buy Avg: ₹${pos.avgEntryPrice.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                      Text(
                        '${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isProfit ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Selling Price & Quantity Sold
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Actual Selling Price (₹)*',
                          labelStyle: TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Color(0xFF131722),
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
                        decoration: InputDecoration(
                          labelText: 'Quantity Sold (Max ${pos.quantity})*',
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF131722),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final val = int.tryParse(v);
                          if (val == null || val <= 0) return 'Min 1 share';
                          if (val > pos.quantity) return 'Max ${pos.quantity}';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Sale Date & Time
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
                  decoration: const InputDecoration(
                    labelText: 'Brokerage & Transaction Charges (₹) (Optional)',
                    labelStyle: TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Color(0xFF131722),
                  ),
                ),
                const SizedBox(height: 20),

                // Confirm Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text(
                            'CONFIRM & CLOSE POSITION',
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
