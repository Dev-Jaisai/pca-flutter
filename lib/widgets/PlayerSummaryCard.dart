import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player.dart';
import '../models/player_installment_summary.dart';
import '../screens/installments/installments_screen.dart';
import '../screens/payments/payment_list_screen.dart';
import '../screens/payments/record_payment_screen.dart';
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
    // --- 1. PERIOD LOGIC (Smart Date Handling) ---
    int cycle = widget.player.paymentCycleMonths ?? 1;
    DateTime dueDate = widget.summary.dueDate ?? DateTime.now();

    // Check Billing Day
    int targetDay = widget.player.billingDay ?? dueDate.day;

    DateTime shownEndDate = DateTime(dueDate.year, dueDate.month, targetDay);
    if (shownEndDate.month != dueDate.month) {
      shownEndDate = DateTime(dueDate.year, dueDate.month + 1, 0);
    }

    DateTime shownStartDate = DateTime(shownEndDate.year, shownEndDate.month - cycle, shownEndDate.day);
    if (shownStartDate.day != targetDay) {
      shownStartDate = DateTime(shownStartDate.year, shownStartDate.month + 1, 0);
    }

    String periodText = "${chipDateFormat.format(shownStartDate)} - ${df.format(shownEndDate)}";

    // --- 2. STATUS & COLOR LOGIC ---
    final String statusStr = (widget.summary.status ?? '').toUpperCase();
    final bool isSkipped = statusStr == 'SKIPPED';
    final bool isCancelled = statusStr == 'CANCELLED'; // Left
    final bool isPaid = !isSkipped && !isCancelled && statusStr == 'PAID';

    final double remaining = widget.summary.remaining ?? 0.0;
    final bool isOverdue = !isSkipped && !isCancelled && !isPaid && remaining > 0 && dueDate.isBefore(DateTime.now());

    // Dynamic Color
    Color statusColor;
    if (isSkipped) {
      statusColor = Colors.white; // White for Holiday
    } else if (isCancelled) {
      statusColor = Colors.grey;  // Grey for Left
    } else if (isPaid) {
      statusColor = Colors.greenAccent;
    } else if (isOverdue) {
      statusColor = Colors.redAccent;
    } else {
      statusColor = Colors.orangeAccent;
    }

    // Sort installments for Chip Display
    final sortedInstallments = List<PlayerInstallmentSummary>.from(widget.installments);
    sortedInstallments.sort((a, b) {
      bool isPaidA = (a.status ?? '').toUpperCase() == 'PAID';
      bool isPaidB = (b.status ?? '').toUpperCase() == 'PAID';
      if (isPaidA != isPaidB) return isPaidA ? 1 : -1;
      DateTime dateA = a.dueDate ?? DateTime(2099);
      DateTime dateB = b.dueDate ?? DateTime(2099);
      return isPaidA ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2A38).withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 2)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ROW 1: HEADER (Name & Group) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.player.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                  widget.player.group ?? 'No Group',
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.cyan.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.cyan.withOpacity(0.3), width: 0.5),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 10, color: Colors.cyanAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Bill Day: ${widget.player.billingDay ?? '-'}",
                                      style: const TextStyle(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Count Badge
                    if (widget.installments.isNotEmpty || isSkipped)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.5)),
                        ),
                        child: Text(
                          isSkipped ? 'Holiday' : (isCancelled ? 'Left' : 'Items: ${widget.installments.length}'),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // --- 🔥 ROW 2: DETAILED BILLING INFO BOX ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line 1: Period
                      Row(
                        children: [
                          Icon(Icons.date_range, size: 14, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(
                            "Period: $periodText",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),

                      // Line 2: Status Specific Display
                      if (isSkipped) ...[
                        const SizedBox(height: 8),
                        // 🏖️ HOLIDAY
                        Row(
                          children: [
                            const Icon(Icons.beach_access, size: 14, color: Colors.white),
                            const SizedBox(width: 8),
                            const Text(
                              "Holiday / Skipped",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ] else if (isCancelled) ...[
                        const SizedBox(height: 8),
                        // ⛔ LEFT
                        Row(
                          children: [
                            const Icon(Icons.block, size: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              "Left Academy",
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ] else if (isPaid) ...[
                        const SizedBox(height: 8),
                        // 🟢 PAID (Show Paid Date)
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.summary.lastPaymentDate != null
                                    ? "Paid on ${df.format(widget.summary.lastPaymentDate!)}"
                                    : "Paid (Date N/A)",
                                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        // 🟠 PENDING / OVERDUE
                        // 🔥 REMOVED THE "Overdue (Due: 25 Dec)" LINE AS REQUESTED
                        // Ata ethe kahi dakhvle janar nahi. Clean View.
                      ]
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // --- ROW 3: STATS ---
                if (!isSkipped && !isCancelled)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStat('Total', '₹${(widget.summary.installmentAmount ?? 0).toStringAsFixed(0)}', Colors.white),
                      _buildStat('Paid', '₹${widget.summary.totalPaid.toStringAsFixed(0)}', Colors.greenAccent),
                      _buildStat('Remaining', '₹${remaining.toStringAsFixed(0)}', isOverdue ? Colors.redAccent : Colors.white54),
                    ],
                  )
                else
                // Simplified Stat for Holiday/Left
                  Row(
                    children: [
                      _buildStat('Status', isSkipped ? 'SKIPPED' : 'LEFT ACADEMY', Colors.white),
                    ],
                  ),

                const SizedBox(height: 12),

                // --- CHIPS (Previous Months) ---
                if (sortedInstallments.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...sortedInstallments.take(6).map((inst) => _buildMonthChip(context, inst)),
                      if (sortedInstallments.length > 6)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text("+${sortedInstallments.length - 6} more", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                        )
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // --- ROW 4: ACTION BUTTONS ---
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openDetails(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("View Details"),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 🔥 Hide 'Pay Now' if Skipped or Left
                    if (!isPaid && !isSkipped && !isCancelled)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: remaining > 0 ? () async {
                            int? instId = widget.summary.installmentId ?? (widget.installments.isNotEmpty ? widget.installments.first.installmentId : null);
                            if(instId != null) {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => RecordPaymentScreen(installmentId: instId, remainingAmount: remaining)));
                              EventBus().fire(PlayerEvent('updated'));
                            }
                          } : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOverdue ? Colors.redAccent : Colors.greenAccent,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white10,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Pay Now", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    else if (isPaid)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await PdfInvoiceService.generateAndPrint(widget.player, widget.summary);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                            }
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text("Receipt"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueAccent,
                            side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
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
    final bool isSkipped = status == 'SKIPPED';
    final bool isCancelled = status == 'CANCELLED';
    final bool isPaid = status == 'PAID';
    final dueDateStr = inst.dueDate != null ? chipDateFormat.format(inst.dueDate!) : 'N/A';

    // Label Logic
    String label = dueDateStr;
    if (isPaid) label += ' (Paid)';
    if (isSkipped) label += ' (Holiday)';
    if (isCancelled) label += ' (Left)';

    // Color Logic
    Color bg, textCol, borderCol;

    if (isSkipped || isCancelled) {
      bg = Colors.white.withOpacity(0.2);
      textCol = Colors.white;
      borderCol = Colors.white54;
    } else if (isPaid) {
      bg = Colors.greenAccent.withOpacity(0.2);
      textCol = Colors.greenAccent;
      borderCol = Colors.greenAccent.withOpacity(0.5);
    } else {
      bg = Colors.redAccent.withOpacity(0.2);
      textCol = Colors.redAccent;
      borderCol = Colors.redAccent.withOpacity(0.5);
    }

    return InkWell(
      onTap: () => _showInstallmentOptions(inst),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderCol)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textCol)),
            if (isPaid) ...[const SizedBox(width: 4), Icon(Icons.check_circle, size: 14, color: textCol)]
          ],
        ),
      ),
    );
  }

  void _showInstallmentOptions(PlayerInstallmentSummary inst) {
    // ... Same function as before ...
    if (inst.installmentId == null) return;
    final status = (inst.status ?? '').toUpperCase();
    final isPaid = status == 'PAID';
    final isSkipped = status == 'SKIPPED';
    final isCancelled = status == 'CANCELLED';
    String headerDate = inst.dueDate != null ? df.format(inst.dueDate!) : 'No Date';

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
              Text("Installment: $headerDate", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 8),
              Text("Amount: ₹${inst.installmentAmount}  •  Status: $status", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),

              if (!isPaid && !isSkipped && !isCancelled)
                ListTile(
                  leading: const Icon(Icons.edit_calendar, color: Colors.orangeAccent),
                  title: const Text("Extend Due Date", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showExtendDialog(inst.installmentId!, inst.dueDate);
                  },
                ),

              if (!isSkipped && !isCancelled)
                ListTile(
                  leading: const Icon(Icons.payment, color: Colors.greenAccent),
                  title: const Text("View / Pay This Installment", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentsListScreen(installmentId: inst.installmentId!, remainingAmount: inst.remaining))).then((_) {EventBus().fire(PlayerEvent('updated'));});
                  },
                ),

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
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExtendDialog(int installmentId, DateTime? currentDueDate) async {
    // ... Same logic ...
    DateTime? selectedDate;
    final now = DateTime.now();
    final initialDate = (currentDueDate != null) ? currentDueDate : now;

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
                  const Text('Select a new date for payment.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate ?? initialDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent, onPrimary: Colors.black, surface: Color(0xFF1E2A38)),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setStateDialog(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8), color: Colors.white10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(selectedDate == null ? df.format(initialDate) : df.format(selectedDate!), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          const Icon(Icons.calendar_month, color: Colors.cyanAccent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                ElevatedButton(
                  onPressed: selectedDate == null ? null : () async {
                    Navigator.pop(dialogContext);
                    try {
                      await ApiService.extendInstallmentDate(installmentId: installmentId, newDate: selectedDate!);
                      EventBus().fire(PlayerEvent('installment_updated'));
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Date Updated Successfully!'), backgroundColor: Colors.green));
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
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