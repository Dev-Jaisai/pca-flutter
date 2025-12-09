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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load payments: $e')));
      }
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
    final df = DateFormat('dd MMM yyyy, hh:mm a');
    const bg = Color(0xFFFBF8FF);
    const accent = Color(0xFF9B6CFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Payments'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRecord,
        icon: const Icon(Icons.add),
        label: const Text('Record Payment'),
        backgroundColor: accent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.payments_outlined, size: 56, color: Colors.black26),
            SizedBox(height: 12),
            Text('No payments found', style: TextStyle(color: Colors.black54)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _load,
        color: accent,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          itemCount: _payments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final p = _payments[i];
            return Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 6,
              shadowColor: Colors.black12,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {}, // keep non-interactive for now
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F5FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments, color: Color(0xFF6067FF)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('₹ ${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 6),
                            Text('${p.paymentMethod ?? '—'} • ${p.reference ?? ''}', style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 6),
                            Text(df.format(p.paidOn.toLocal()), style: const TextStyle(color: Colors.black45, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // optional quick actions (copy ref / share) - placeholder icons
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: Colors.black45),
                        onPressed: () {
                          final text = '${p.reference ?? ''}';
                          if (text.isNotEmpty) {
                            // copy to clipboard simplified
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied')));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
