// lib/screens/installments/installments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/installment.dart';
import '../../services/api_service.dart';
import '../payments/payment_list_screen.dart';
import 'create_installment_screen.dart';
import 'package:textewidget/screens/payments/record_payment_screen.dart';

class InstallmentsScreen extends StatefulWidget {
  final Player player;
  const InstallmentsScreen({super.key, required this.player});

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  late Future<List<Installment>> _futureInstallments;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _futureInstallments = ApiService.fetchInstallmentsByPlayer(widget.player.id);
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateInstallmentScreen(player: widget.player)),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: Text('${widget.player.name} — Installments')),
      body: FutureBuilder<List<Installment>>(
        future: _futureInstallments,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final list = snap.data ?? [];
          if (list.isEmpty) return const Center(child: Text('No installments found'));
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final it = list[i];

              // compute whether fully paid
              final double remaining = (it.remainingAmount ?? it.amount ?? 0.0);
              final bool isPaid = remaining <= 0.0;

              return ListTile(
                title: Text(
                  '${it.periodMonth ?? '-'} / ${it.periodYear ?? '-'}  •  ${it.status ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      'Amount: ${it.amount?.toStringAsFixed(2) ?? '-'}'
                          '  Paid: ${it.paidAmount?.toStringAsFixed(2) ?? '0.00'}',
                    ),
                    if (it.dueDate != null) Text('Due: ${df.format(it.dueDate!)}'),
                    const SizedBox(height: 8),

                    // PAID badge when fully paid
                    if (isPaid)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Text(
                            'PAID',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                    // Action row
                    Row(
                      children: [
                        // View Payments
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.deepPurple, // icon + label color
                          ),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('Payments'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentsListScreen(
                                  installmentId: it.id, // use id (int) from model
                                  remainingAmount: remaining,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 10),

                        // Record Payment (disabled when fully paid)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: isPaid ? Colors.grey : Colors.deepPurple,
                          ),
                          icon: Icon(Icons.add_card, size: 18, color: isPaid ? Colors.grey : Colors.deepPurple),
                          label: Text(
                            'Record',
                            style: TextStyle(
                              color: isPaid ? Colors.grey : Colors.deepPurple,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: isPaid
                              ? null
                              : () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecordPaymentScreen(
                                  installmentId: it.id,
                                  remainingAmount: remaining,
                                ),
                              ),
                            );
                            if (result == true) _load();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade400,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.deepPurple.shade400,
          elevation: 0,
          onPressed: _openCreate,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "Create Installment",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
