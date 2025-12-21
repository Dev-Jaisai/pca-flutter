import 'dart:ui'; // Required for Glassmorphism
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player.dart';
import '../models/player_installment_summary.dart';
import '../screens/installments/installments_screen.dart';
import '../screens/payments/payment_list_screen.dart';
import '../services/PdfInvoiceService.dart';
import '../services/api_service.dart';
import '../utils/event_bus.dart';

class PlayerSummaryCard extends StatefulWidget {
  final Player player;
  final PlayerInstallmentSummary summary;
  final List<PlayerInstallmentSummary> installments;
  final String? nextScreenFilter;

  const PlayerSummaryCard({
    super.key,
    required this.player,
    required this.summary,
    this.installments = const [],
    this.nextScreenFilter,
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
    final Color statusColor = isOverdue ? Colors.redAccent : Colors.greenAccent;

    // Sorting Logic
    final sortedInstallments = List<PlayerInstallmentSummary>.from(widget.installments);
    sortedInstallments.sort((a, b) {
      bool isPaidA = (a.status ?? '').toUpperCase() == 'PAID';
      bool isPaidB = (b.status ?? '').toUpperCase() == 'PAID';
      if (isPaidA != isPaidB) return isPaidA ? 1 : -1;
      DateTime dateA = a.dueDate ?? DateTime(2099);
      DateTime dateB = b.dueDate ?? DateTime(2099);
      return isPaidA ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });

    // --- GLASS CARD DESIGN ---
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Blur effect
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08), // Transparent White (Glass)
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1), // Subtle Border
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
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
                        Text(
                            widget.player.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                        Text(
                            widget.player.group ?? 'No Group',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2), // Transparent Badge
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        'Items: ${widget.installments.length}',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white24),

                // --- STATS ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStat('Total', '₹${(widget.summary.installmentAmount ?? 0).toStringAsFixed(0)}', Colors.white),
                    _buildStat('Paid', '₹${widget.summary.totalPaid.toStringAsFixed(0)}', Colors.greenAccent),
                    _buildStat('Remaining', '₹${remaining.toStringAsFixed(0)}', isOverdue ? Colors.redAccent : Colors.white54),
                  ],
                ),
                const SizedBox(height: 12),

                // --- CHIPS ---
                if (sortedInstallments.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...sortedInstallments.take(6).map((inst) => _buildMonthChip(context, inst)),
                      if (sortedInstallments.length > 6)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "+${sortedInstallments.length - 6} more",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
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
                          side: BorderSide(color: Colors.white.withOpacity(0.2)), // Light border
                          foregroundColor: Colors.white,
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
                          backgroundColor: isOverdue ? Colors.redAccent : Colors.greenAccent,
                          foregroundColor: Colors.black, // Black text on neon button
                          disabledBackgroundColor: Colors.white10,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(remaining > 0 ? "Pay Now" : "Paid", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstallmentsScreen(
          player: widget.player,
          initialFilter: widget.nextScreenFilter,
        ),
      ),
    ).then((_) {
      EventBus().fire(PlayerEvent('updated'));
    });
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildMonthChip(BuildContext context, PlayerInstallmentSummary inst) {
    final status = (inst.status ?? '').toUpperCase();
    final bool isPaid = status == 'PAID';
    final dueDateStr = inst.dueDate != null ? chipDateFormat.format(inst.dueDate!) : 'N/A';
    final paidDateStr = (isPaid && inst.lastPaymentDate != null) ? chipDateFormat.format(inst.lastPaymentDate!) : (isPaid ? 'Paid' : null);
    final String label = isPaid && paidDateStr != null && paidDateStr != 'Paid' ? '$dueDateStr / $paidDateStr' : dueDateStr;

    // Chip Colors for Dark Mode
    final bg = isPaid ? Colors.greenAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2);
    final textCol = isPaid ? Colors.greenAccent : Colors.redAccent;
    final borderCol = isPaid ? Colors.greenAccent.withOpacity(0.5) : Colors.redAccent.withOpacity(0.5);

    return InkWell(
      onTap: () => _showInstallmentOptions(inst),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderCol)
        ),
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

  // ... (Keep _showInstallmentOptions and _showExtendDialog as is, they are fine) ...
  // Be sure to update their dialog backgrounds to dark if needed, but for now this fixes the Card issue.
  void _showInstallmentOptions(PlayerInstallmentSummary inst) {
    if (inst.installmentId == null) return;
    final isPaid = (inst.status ?? '').toUpperCase() == 'PAID';
    String headerDate = inst.dueDate != null ? df.format(inst.dueDate!) : 'No Date';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF203A43), // Dark Sheet
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Installment: $headerDate", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 8),
              Text("Amount: ₹${inst.installmentAmount}  •  Paid: ₹${inst.totalPaid}", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              if (isPaid)
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.blueAccent),
                  title: const Text("Download Receipt", style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await PdfInvoiceService.generateAndPrint(widget.player, inst);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                ),
              if (!isPaid)
                ListTile(
                  leading: const Icon(Icons.edit_calendar, color: Colors.blueAccent),
                  title: const Text("Extend Due Date", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showExtendDialog(inst.installmentId!, inst.dueDate);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.greenAccent),
                title: const Text("View / Pay This Installment", style: TextStyle(color: Colors.white)),
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
    // ... (Keep existing logic, just change Dialog colors if you want) ...
    // For now, standard dialog is okay, or you can wrap it in Theme(data: ThemeData.dark(), ...)
    DateTime? selectedDate;
    final now = DateTime.now();
    final initialDate = (currentDueDate != null && currentDueDate.isAfter(now)) ? currentDueDate : now.add(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: ThemeData.dark(), // Force Dark Dialog
          child: StatefulBuilder(builder: (sbContext, setStateDialog) {
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
                          const Icon(Icons.calendar_month, color: Colors.deepPurpleAccent),
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
          }),
        );
      },
    );
  }
}