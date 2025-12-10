// lib/screens/payments/record_payment_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/event_bus.dart';

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

      // Fire events to update other screens (Dashboard stats etc)
      EventBus().fire(PlayerEvent('payment_recorded'));
      EventBus().fire(PlayerEvent('installment_updated'));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded successfully')));

      // --- THE FIX: JUMP BACK TO ALL INSTALLMENTS ---
      // This pops all screens until it finds '/all-installments' OR the very first screen.
      // This effectively closes "Record Payment" AND "Payment List" in one go.
      Navigator.of(context).popUntil((route) {
        return route.settings.name == '/all-installments' || route.isFirst;
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Record failed: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyHint = widget.remainingAmount != null ? 'Remaining: ₹${widget.remainingAmount!.toStringAsFixed(2)}' : null;
    const bg = Color(0xFFFBF8FF);
    const accent = Color(0xFF9B6CFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Record Payment'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (currencyHint != null) ...[
                      const SizedBox(height: 8),
                      Text(currencyHint, style: const TextStyle(color: Colors.black54)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: const Offset(0, 8))],
                ),
                child: Form(
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
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 8,
                          ),
                          child: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}