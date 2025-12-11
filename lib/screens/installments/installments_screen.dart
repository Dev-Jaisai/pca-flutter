import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/installment.dart';
import '../../services/api_service.dart';
import '../payments/payment_list_screen.dart';
import 'package:textewidget/screens/payments/record_payment_screen.dart';
import 'create_installment_screen.dart';

class InstallmentsScreen extends StatefulWidget {
  final Player player;
  final String? initialFilter;

  const InstallmentsScreen({
    super.key,
    required this.player,
    this.initialFilter,
  });

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  late Future<List<Installment>> _futureInstallments;
  final df = DateFormat('dd MMM yyyy');

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
    const bg = Color(0xFFF5F7FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.player.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Installment History',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: false,
        // --- ADDED BUTTON HERE (Top Right) ---
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_circle_outline, color: Colors.deepPurple, size: 28),
              tooltip: 'Create Installment',
            ),
          ),
        ],
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
                children: [
                  Icon(Icons.history_edu, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No installments recorded yet.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  // Optional: Call to action button for empty state
                  OutlinedButton.icon(
                    onPressed: _openCreate,
                    icon: const Icon(Icons.add),
                    label: const Text("Create First Installment"),
                  )
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _load();
              await _futureInstallments;
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                return _buildInstallmentCard(list[i]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstallmentCard(Installment it) {
    final double total = it.amount ?? 0.0;
    final double paid = it.paidAmount ?? 0.0;
    final double remaining = total - paid;
    final bool isPaid = remaining <= 0;
    final bool isOverdue = !isPaid && it.dueDate != null && it.dueDate!.isBefore(DateTime.now());

    // Status Determination
    String statusText = (it.status ?? 'PENDING').replaceAll('_', ' ');
    Color statusColor = Colors.blue;
    Color statusBg = Colors.blue.shade50;

    if (isPaid) {
      statusText = "PAID";
      statusColor = Colors.green;
      statusBg = Colors.green.shade50;
    } else if (isOverdue) {
      statusText = "OVERDUE";
      statusColor = Colors.red;
      statusBg = Colors.red.shade50;
    } else if (paid > 0) {
      statusText = "PARTIAL";
      statusColor = Colors.orange;
      statusBg = Colors.orange.shade50;
    }

    final periodLabel = '${it.periodMonth}/${it.periodYear}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        // Left accent border based on status
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header: Month & Status Badge ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  periodLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- Amount Details ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paid', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${paid.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Due Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        it.dueDate != null ? df.format(it.dueDate!) : '—',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isOverdue ? Colors.red : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- Action Buttons ---
            Row(
              children: [
                // 1. View History Button
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.history, size: 18, color: Colors.grey),
                    label: const Text('Payments'),
                  ),
                ),

                const SizedBox(width: 12),

                // 2. Record Payment Button (Primary)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPaid
                        ? null // Disabled if fully paid
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_card, size: 18),
                    label: const Text('Record'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}