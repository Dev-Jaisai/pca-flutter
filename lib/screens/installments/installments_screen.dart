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
    final bg = const Color(0xFFFBF8FF);
    final accent = const Color(0xFF9B6CFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('${widget.player.name} — Installments'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<Installment>>(
        future: _futureInstallments,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.calendar_month_outlined, size: 56, color: Colors.black26),
                  SizedBox(height: 12),
                  Text('No installments found', style: TextStyle(color: Colors.black54)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _load();
              await _futureInstallments;
            },
            color: accent,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final it = list[i];

                // compute whether fully paid
                final double remaining = (it.remainingAmount ?? it.amount ?? 0.0);
                final bool isPaid = remaining <= 0.0;

                // friendly status text
                final statusText = it.status ?? 'N/A';
                final period = '${it.periodMonth ?? '-'} / ${it.periodYear ?? '-'}';

                // Status Colors
                Color statusColor = Colors.grey;
                if(statusText == 'OVERDUE') statusColor = Colors.red;
                else if(statusText == 'PENDING') statusColor = Colors.blue;
                else if(statusText == 'PARTIALLY_PAID') statusColor = Colors.orange;
                else if(statusText == 'PAID') statusColor = Colors.green;

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 6,
                  shadowColor: Colors.black12,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Period, Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              period,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            ),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                statusText.replaceAll('_', ' '),
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 20),

                        // amounts and due date
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Amount: ${it.amount?.toStringAsFixed(2) ?? '-'}', style: const TextStyle(fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text('Paid: ${it.paidAmount?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                            if (it.dueDate != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Due Date', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                  const SizedBox(height: 4),
                                  Text(
                                      df.format(it.dueDate!),
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: (statusText == 'OVERDUE' && !isPaid) ? Colors.red : Colors.black87
                                      )
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // action row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PaymentsListScreen(
                                        installmentId: it.id,
                                        remainingAmount: remaining,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.receipt_long, size: 18),
                                label: const Text('Payments'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.grey.shade200),
                                  foregroundColor: accent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 140,
                              child: ElevatedButton.icon(
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
                                icon: const Icon(Icons.add_card, size: 18),
                                label: const Text('Record', style: TextStyle(fontWeight: FontWeight.w600)),
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                                    if (states.contains(MaterialState.disabled)) return Colors.grey.shade200;
                                    return accent;
                                  }),
                                  foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                                    if (states.contains(MaterialState.disabled)) return Colors.grey.shade500;
                                    return Colors.white;
                                  }),
                                  elevation: MaterialStateProperty.resolveWith<double?>((states) {
                                    if (states.contains(MaterialState.disabled)) return 0.0;
                                    return 6.0;
                                  }),
                                  padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 12)),
                                  shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFBFA7FF), Color(0xFF9B6CFF)]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: _openCreate,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Create Installment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}