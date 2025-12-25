import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player.dart';
import '../models/player_installment_summary.dart';
import '../screens/installments/installments_screen.dart';
import '../screens/payments/record_payment_screen.dart';
import '../screens/payments/payment_list_screen.dart';
import '../services/PdfInvoiceService.dart';
import '../services/api_service.dart';
import '../utils/billing_helper.dart';
import '../utils/event_bus.dart';

class PlayerSummaryCard extends StatelessWidget {
  final Player player;
  final PlayerInstallmentSummary summary;

  // 🔥 List of all installments for this player (Required for Chips)
  final List<PlayerInstallmentSummary> installments;

  const PlayerSummaryCard({
    super.key,
    required this.player,
    required this.summary,
    this.installments = const [],
    String? nextScreenFilter,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Status & Colors for MAIN Card (Header)
    final status = (summary.status ?? 'PENDING').toUpperCase();
    final bool isSkipped = status == 'SKIPPED';
    final bool isPaid = status == 'PAID';
    final bool isOverdue = !isPaid && !isSkipped && (summary.remaining ?? 0) > 0;

    final Color statusColor = BillingHelper.getStatusColor(status, isOverdue);
    final Color cardBg = const Color(0xFF1E2A38).withOpacity(0.9);

    // Sort installments: Latest First
    final sortedInstallments = List<PlayerInstallmentSummary>.from(installments);
    sortedInstallments.sort((a, b) {
      DateTime dateA = a.dueDate ?? DateTime(2000);
      DateTime dateB = b.dueDate ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ROW 1: HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text("${player.group ?? 'No Group'} • Bill Day: ${player.billingDay ?? 1}", style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      "Total Due: ₹${summary.remaining?.toInt() ?? 0}",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 16),

              // --- 🔥 ROW 2: CHIPS (The Months) ---
              if (sortedInstallments.isNotEmpty) ...[
                const Text("Recent Months:", style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sortedInstallments.take(4).map((inst) {
                    return _buildMonthChip(context, inst, player);
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // --- ROW 3: BUTTONS ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstallmentsScreen(player: player))).then((_) => EventBus().fire(PlayerEvent('updated'))),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white24)),
                      child: const Text("Full History"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (summary.remaining! > 0)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Default to latest unpaid installment
                          var target = sortedInstallments.firstWhere((i) => (i.remaining ?? 0) > 0, orElse: () => sortedInstallments.first);
                          if (target.installmentId != null) {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => RecordPaymentScreen(installmentId: target.installmentId!, remainingAmount: target.remaining)));
                            EventBus().fire(PlayerEvent('updated'));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                        child: const Text("Pay Now"),
                      ),
                    )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper to Build Individual Chips ---
  Widget _buildMonthChip(BuildContext context, PlayerInstallmentSummary inst, Player player) {
    // 1. Get Status & Color
    final status = (inst.status ?? '').toUpperCase();
    final bool isSkipped = status == 'SKIPPED';
    final bool isPaid = status == 'PAID';
    final bool isOverdue = !isPaid && !isSkipped && inst.dueDate != null && inst.dueDate!.isBefore(DateTime.now());

    Color chipColor = Colors.orangeAccent; // Pending
    Color textColor = Colors.black;

    if (isSkipped) {
      chipColor = Colors.white; // Holiday
      textColor = Colors.black;
    } else if (isPaid) {
      chipColor = Colors.greenAccent; // Paid
      textColor = Colors.black;
    } else if (isOverdue) {
      chipColor = Colors.redAccent; // Overdue
      textColor = Colors.white;
    }

    // 2. Format Date (e.g., "Dec '25")
    String label = "Unknown";
    if (inst.dueDate != null) {
      // Using Helper logic just for Month Name
      int billDay = player.billingDay ?? 1;
      DateTime date = inst.dueDate!;
      DateTime billingMonth = DateTime(date.year, date.month, billDay);
      if (billingMonth.isAfter(date) || billingMonth.isAtSameMomentAs(date)) {
        billingMonth = DateTime(date.year, date.month - 1, 1);
      }
      label = DateFormat('MMM yy').format(billingMonth);
    }

    // 3. Status Icon
    IconData icon = Icons.access_time; // Pending
    if (isPaid) icon = Icons.check_circle;
    if (isSkipped) icon = Icons.beach_access;
    if (isOverdue) icon = Icons.warning;

    return InkWell(
      onTap: () => _showChipOptions(context, inst), // 🔥 CLICK HANDLER
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: chipColor.withOpacity(isOverdue ? 0.8 : 0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  // 🔥 RESTORED & FIXED BOTTOM SHEET
  void _showChipOptions(BuildContext context, PlayerInstallmentSummary inst) {
    final status = (inst.status ?? '').toUpperCase();
    final bool isSkipped = status == 'SKIPPED';
    final bool isPaid = status == 'PAID';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF203A43),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Installment Details", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 8),

              // Date Info
              if (inst.dueDate != null)
                Text("Due Date: ${DateFormat('dd MMM yyyy').format(inst.dueDate!)}", style: const TextStyle(color: Colors.white70)),

              const SizedBox(height: 20),

              // 🔥 1. HOLIDAY NOTE (If Skipped)
              if (isSkipped) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("🏖️ Holiday Reason:", style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                      const SizedBox(height: 4),
                      // Note: Ensure your backend sends 'notes' in the summary API. If not, it won't show here.
                      // You might need to add 'notes' to PlayerInstallmentSummary model.
                      Text("Check history for full reason.", style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 🔥 2. EXTEND DATE (If Pending/Overdue)
              if (!isPaid && !isSkipped)
                ListTile(
                  leading: const Icon(Icons.edit_calendar, color: Colors.orangeAccent),
                  title: const Text("Extend Due Date", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showExtendDialog(context, inst.installmentId!, inst.dueDate);
                  },
                ),

              // 🔥 3. PAY / VIEW
              ListTile(
                leading: const Icon(Icons.payment, color: Colors.greenAccent),
                title: Text(isPaid ? "View Receipt" : "Record Payment", style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (inst.installmentId != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentsListScreen(installmentId: inst.installmentId!, remainingAmount: inst.remaining))).then((_) => EventBus().fire(PlayerEvent('updated')));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExtendDialog(BuildContext context, int installmentId, DateTime? currentDueDate) async {
    DateTime? selectedDate;
    final now = DateTime.now();
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: ThemeData.dark(),
          child: StatefulBuilder(builder: (sbContext, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF203A43),
              title: const Text('Extend Due Date', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select a new due date.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(selectedDate == null ? "Pick Date" : DateFormat('dd MMM yyyy').format(selectedDate!)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: currentDueDate ?? now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setStateDialog(() => selectedDate = picked);
                    },
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
                      EventBus().fire(PlayerEvent('updated'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date Updated!'), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          }),
        );
      },
    );
  }
}