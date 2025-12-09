// lib/screens/payments/payments_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart';
import 'record_payment_screen.dart';

class PaymentsListScreen extends StatefulWidget {
  final int installmentId;
  final double? remainingAmount; // optional for record screen hint

  const PaymentsListScreen({super.key, required this.installmentId, this.remainingAmount});

  @override
  State<PaymentsListScreen> createState() => _PaymentsListScreenState();
}

class _PaymentsListScreenState extends State<PaymentsListScreen> {
  bool _loading = true;
  List<Payment> _payments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.fetchPaymentsByInstallment(widget.installmentId);
      if (mounted) setState(() => _payments = list);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load payments: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRecord() async {
    final didCreate = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RecordPaymentScreen(installmentId: widget.installmentId, remainingAmount: widget.remainingAmount)),
    );
    if (didCreate == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecord,
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
          ? const Center(child: Text('No payments found'))
          : ListView.separated(
        itemCount: _payments.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) {
          final p = _payments[i];
          return ListTile(
            title: Text('₹ ${p.amount.toStringAsFixed(2)}'),
            subtitle: Text('${p.paymentMethod ?? '—'} • ${p.reference ?? ''}\n${df.format(p.paidOn.toLocal())}'),
            isThreeLine: true,
            leading: const Icon(Icons.payments),
          );
        },
      ),
    );
  }
}
