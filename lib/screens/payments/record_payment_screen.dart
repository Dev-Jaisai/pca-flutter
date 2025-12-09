// lib/screens/payments/record_payment_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../utils/event_bus.dart'; // ADDED import for EventBus and PlayerEvent

class RecordPaymentScreen extends StatefulWidget {
  final int installmentId;
  final double? remainingAmount;

  const RecordPaymentScreen({super.key, required this.installmentId, this.remainingAmount});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtl = TextEditingController();
  final _methodCtl = TextEditingController();
  final _refCtl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountCtl.dispose();
    _methodCtl.dispose();
    _refCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtl.text.trim())!;
    final method = _methodCtl.text.trim().isEmpty ? null : _methodCtl.text.trim();
    final ref = _refCtl.text.trim().isEmpty ? null : _refCtl.text.trim();

    setState(() => _loading = true);
    try {
      await ApiService.recordPayment(
        installmentId: widget.installmentId,
        amount: amount,
        paymentMethod: method,
        reference: ref,
      );

      // FIRE EVENT so dashboard and lists refresh
      EventBus().fire(PlayerEvent('payment_recorded'));
      EventBus().fire(PlayerEvent('installment_updated'));

      // Notify caller and close
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyHint = widget.remainingAmount != null ? 'Remaining: ₹${widget.remainingAmount!.toStringAsFixed(2)}' : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _amountCtl,
                decoration: InputDecoration(labelText: 'Amount', helperText: currencyHint),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter valid amount';
                  if (widget.remainingAmount != null && n > widget.remainingAmount!) return 'Amount exceeds remaining';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _methodCtl,
                decoration: const InputDecoration(labelText: 'Payment Method (e.g. UPI, Cash)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _refCtl,
                decoration: const InputDecoration(labelText: 'Reference (optional)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _submit, child: const Text('Record Payment')),
              )
            ],
          ),
        ),
      ),
    );
  }
}
