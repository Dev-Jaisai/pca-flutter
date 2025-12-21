import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player.dart';
import '../models/player_installment_summary.dart';
import '../screens/installments/installments_screen.dart';
import '../screens/payments/payment_list_screen.dart';
import '../services/api_service.dart';
import '../utils/event_bus.dart'; // ✅ Needed for EventBus

class PlayerSummaryCard extends StatefulWidget {
  final Player player;
  final PlayerInstallmentSummary summary;
  final List<PlayerInstallmentSummary> installments;
  final String? nextScreenFilter; // ✅ Added to control next screen view

  const PlayerSummaryCard({
    super.key,
    required this.player,
    required this.summary,
    this.installments = const [],
    this.nextScreenFilter, // ✅ Constructor
  });

  @override
  State<PlayerSummaryCard> createState() => _PlayerSummaryCardState();
}

class _PlayerSummaryCardState extends State<PlayerSummaryCard> {
  final df = DateFormat('dd MMM yyyy');
  final chipDateFormat = DateFormat('dd MMM');

  @override
  Widget build(BuildContext context) {
    final double remaining = widget.summary.remaining ?? 0.0;
    final bool isOverdue = remaining > 0;
    final Color statusColor = isOverdue ? Colors.red : Colors.green;

    // 1. Copy list
    final sortedInstallments = List<PlayerInstallmentSummary>.from(widget.installments);

    // 2. APPLY MAGIC SORTING (Overdue First, Latest Paid First)
    sortedInstallments.sort((a, b) {
      // Step A: Status Check
      bool isPaidA = (a.status ?? '').toUpperCase() == 'PAID';
      bool isPaidB = (b.status ?? '').toUpperCase() == 'PAID';

      // Rule 1: Jar status vegla asel, tar UNPAID varati (-1), PAID khali (1)
      if (isPaidA != isPaidB) {
        return isPaidA ? 1 : -1;
      }

      // Step B: Date Sorting based on Status
      DateTime dateA = a.dueDate ?? DateTime(2099);
      DateTime dateB = b.dueDate ?? DateTime(2099);

      if (isPaidA) {
        // Rule 2: Jar PAID asel -> LATEST FIRST (May adhi, Jan nantar)
        return dateB.compareTo(dateA);
      } else {
        // Rule 3: Jar UNPAID asel -> OLDEST FIRST (Nov adhi, Dec nantar - Urgent)
        return dateA.compareTo(dateB);
      }
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: statusColor, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(widget.player.group ?? 'No Group', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOverdue ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Items: ${widget.installments.length}',
                      style: TextStyle(
                        color: isOverdue ? Colors.red.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // --- STATS ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat('Total', '₹${(widget.summary.installmentAmount ?? 0).toStringAsFixed(0)}', Colors.black87),
                  _buildStat('Paid', '₹${widget.summary.totalPaid.toStringAsFixed(0)}', Colors.green),
                  _buildStat('Remaining', '₹${remaining.toStringAsFixed(0)}', isOverdue ? Colors.red : Colors.grey),
                ],
              ),
              const SizedBox(height: 12),

              // --- CHIPS ---
              // --- MONTH PILLS ---
              if (sortedInstallments.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // 1. फक्त पहिले 6 महिने दाखवा (Display only first 6 items)
                    ...sortedInstallments.take(6).map((inst) => _buildMonthChip(context, inst)),

                    // 2. जर 6 पेक्षा जास्त असतील, तर '+ N more' दाखवा
                    if (sortedInstallments.length > 6)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "+${sortedInstallments.length - 6} more",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700
                          ),
                        ),
                      )
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // --- BUTTONS ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openDetails(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("View Details"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: remaining > 0 ? () => _openDetails() : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(remaining > 0 ? "Pay Now" : "Paid"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ FIXED: Navigation Logic
  void _openDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstallmentsScreen(
          player: widget.player,
          initialFilter: widget.nextScreenFilter, // ✅ Pass filter to next screen
        ),
      ),
    ).then((_) {
      // ✅ FIX: Use EventBus instead of _loadData()
      EventBus().fire(PlayerEvent('updated'));
    });
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildMonthChip(BuildContext context, PlayerInstallmentSummary inst) {
    final status = (inst.status).toUpperCase();
    final bool isPaid = status == 'PAID';
    final dueDateStr = inst.dueDate != null ? chipDateFormat.format(inst.dueDate!) : 'N/A';
    final paidDateStr = (isPaid && inst.lastPaymentDate != null) ? chipDateFormat.format(inst.lastPaymentDate!) : (isPaid ? 'Paid' : null);
    final String label = isPaid && paidDateStr != null && paidDateStr != 'Paid' ? '$dueDateStr / $paidDateStr' : dueDateStr;
    final bg = isPaid ? Colors.green.shade50 : Colors.red.shade50;
    final textCol = isPaid ? Colors.green.shade800 : Colors.red.shade800;

    return InkWell(
      onTap: () => _showInstallmentOptions(inst),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: textCol.withOpacity(0.2))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textCol)),
            if (isPaid) ...[const SizedBox(width: 4), Icon(Icons.check_circle, size: 12, color: textCol)]
          ],
        ),
      ),
    );
  }

  void _showInstallmentOptions(PlayerInstallmentSummary inst) {
    if (inst.installmentId == null) return;
    final isPaid = (inst.status ?? '').toUpperCase() == 'PAID';
    String headerDate = inst.dueDate != null ? df.format(inst.dueDate!) : 'No Date';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Installment: $headerDate", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text("Amount: ₹${inst.installmentAmount}  •  Paid: ₹${inst.totalPaid}", style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 24),
              if (!isPaid)
                ListTile(
                  leading: const Icon(Icons.edit_calendar, color: Colors.blue),
                  title: const Text("Extend Due Date"),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showExtendDialog(inst.installmentId!, inst.dueDate);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.green),
                title: const Text("View / Pay This Installment"),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentsListScreen(installmentId: inst.installmentId!, remainingAmount: inst.remaining),
                    ),
                  ).then((_) {
                    EventBus().fire(PlayerEvent('updated'));
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExtendDialog(int installmentId, DateTime? currentDueDate) async {
    DateTime? selectedDate;
    final now = DateTime.now();
    final initialDate = (currentDueDate != null && currentDueDate.isAfter(now)) ? currentDueDate : now.add(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (sbContext, setStateDialog) {
          return AlertDialog(
            title: const Text('Extend Due Date'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pick a new due date.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate ?? initialDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setStateDialog(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(selectedDate == null ? 'Pick Date' : df.format(selectedDate!), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Icon(Icons.calendar_month, color: Colors.deepPurple),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedDate == null ? null : () async {
                  Navigator.pop(dialogContext);
                  try {
                    await ApiService.extendInstallmentDate(installmentId: installmentId, newDate: selectedDate!);
                    EventBus().fire(PlayerEvent('installment_updated'));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated to ${df.format(selectedDate!)}')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        });
      },
    );
  }
}