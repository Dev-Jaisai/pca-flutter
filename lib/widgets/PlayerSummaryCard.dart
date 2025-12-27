import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player.dart';
import '../models/player_installment_summary.dart';
import '../screens/installments/installments_screen.dart';
import '../screens/payments/record_payment_screen.dart';
import '../screens/payments/payment_list_screen.dart';
import '../services/api_service.dart';
import '../utils/billing_helper.dart';
import '../utils/event_bus.dart';

class PlayerSummaryCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // 1. Status Logic
    final status = (summary.status ?? 'PENDING').toUpperCase();
    final bool isSkipped = status == 'SKIPPED';
    final bool isPaid = status == 'PAID';
    final bool isOverdue = !isPaid && !isSkipped && (summary.remaining ?? 0) > 0;

    final Color statusColor = BillingHelper.getStatusColor(status, isOverdue);
    final Color cardBg = const Color(0xFF1E2A38).withOpacity(0.9);

    // Sort installments: Latest First
    final sortedInstallments = List<PlayerInstallmentSummary>.from(installments);
    if (sortedInstallments.isNotEmpty) {
      sortedInstallments.sort((a, b) {
        DateTime dateA = a.dueDate ?? DateTime(2000);
        DateTime dateB = b.dueDate ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))
            ],
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

              // --- ROW 2: CHIPS (The Months) ---
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
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InstallmentsScreen(
                              player: player,
                              initialFilter: nextScreenFilter,
                            ),
                          ),
                        );
                        EventBus().fire(PlayerEvent('updated'));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      child: const Text("Full History"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if ((summary.remaining ?? 0) > 0)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          var target = sortedInstallments.firstWhere(
                                (i) => (i.remaining ?? 0) > 0,
                            orElse: () => sortedInstallments.first,
                          );
                          if (target.installmentId != null) {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecordPaymentScreen(
                                  installmentId: target.installmentId!,
                                  remainingAmount: target.remaining,
                                ),
                              ),
                            );

                            if (result == true) {
                              EventBus().fire(PlayerEvent('updated'));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                        ),
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

  // --- HELPER 1: BUILD CHIP (🔥 FIXED) ---
  Widget _buildMonthChip(BuildContext context, PlayerInstallmentSummary inst, Player player) {
    final status = (inst.status ?? '').toUpperCase();
    final String notes = (inst.notes ?? '').toLowerCase();

    // 🔥 FIX: Only check notes for "left" or "waived", NOT player.isActive
    final bool isWaived = status == 'SKIPPED' && (notes.contains('left') || notes.contains('waived'));
    final bool isSkipped = status == 'SKIPPED' && !isWaived; // Holiday

    final bool isPaid = status == 'PAID';
    final bool isOverdue = !isPaid && !isSkipped && !isWaived &&
        inst.dueDate != null && inst.dueDate!.isBefore(DateTime.now());

    Color chipColor = Colors.orangeAccent;
    Color textColor = Colors.black;
    IconData icon = Icons.access_time;

    if (isWaived) {
      // LEFT/WAIVED: Grey
      chipColor = Colors.grey.shade700;
      textColor = Colors.white70;
      icon = Icons.person_off;
    } else if (isSkipped) {
      // HOLIDAY: White
      chipColor = Colors.white;
      textColor = Colors.black;
      icon = Icons.beach_access;
    } else if (isPaid) {
      // PAID: Green
      chipColor = Colors.greenAccent;
      textColor = Colors.black;
      icon = Icons.check_circle;
    } else if (isOverdue) {
      // OVERDUE: Red
      chipColor = Colors.redAccent;
      textColor = Colors.white;
      icon = Icons.warning;
    }

    String label = "Unknown";
    if (inst.dueDate != null) {
      label = DateFormat('MMM yy').format(inst.dueDate!);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showChipOptions(context, inst),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: chipColor.withOpacity(isOverdue || isWaived ? 0.8 : 0.9),
            borderRadius: BorderRadius.circular(6),
            border: isWaived ? Border.all(color: Colors.white24) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: textColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER 2: BOTTOM SHEET (🔥 FIXED) ---
  void _showChipOptions(BuildContext context, PlayerInstallmentSummary inst) {
    final status = (inst.status ?? '').toUpperCase();
    final String notes = (inst.notes ?? '').toLowerCase();

    // 🔥 FIX: Removed isPlayerInactive check
    final bool isWaived = status == 'SKIPPED' && (notes.contains('left') || notes.contains('waived'));
    final bool isSkipped = status == 'SKIPPED' && !isWaived;
    final bool isPaid = status == 'PAID';

    // Calculate Period Title
    DateTime anchorDate = inst.dueDate ?? DateTime.now();
    int cycle = player.paymentCycleMonths ?? 1;
    DateTime endDate = DateTime(anchorDate.year, anchorDate.month);
    DateTime startDate;

    if (cycle > 1) {
      startDate = DateTime(endDate.year, endDate.month - cycle + 1);
    } else {
      startDate = DateTime(endDate.year, endDate.month - 1);
    }

    String periodTitle;
    if (startDate.year != endDate.year) {
      periodTitle = '${DateFormat('MMM yy').format(startDate)} - ${DateFormat('MMM yy').format(endDate)}';
    } else {
      periodTitle = '${DateFormat('MMM').format(startDate)} - ${DateFormat('MMM').format(endDate)} ${endDate.year}';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF203A43),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Installment Details",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.date_range, color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "Cycle: $periodTitle",
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (inst.dueDate != null)
                Row(
                  children: [
                    const Icon(Icons.event, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Due Date: ${DateFormat('dd MMM yyyy').format(inst.dueDate!)}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // 1. LEFT/WAIVED
              if (isWaived) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "⛔ WAIVED OFF / LEFT:",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        inst.notes ?? "Student Left Academy.",
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. HOLIDAY
              if (isSkipped) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🏖️ Holiday Reason:",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        inst.notes ?? "No reason provided",
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. PAID (Revert Option)
              if (isPaid) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "This bill is fully PAID.",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                ListTile(
                  leading: const Icon(Icons.undo, color: Colors.redAccent),
                  title: const Text(
                    "Revert Payment (Refund)",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    "Mark as Pending again",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () async {
                    bool confirm = await showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF203A43),
                        title: const Text(
                          "Revert Payment?",
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          "This will mark the bill as PENDING. Are you sure?",
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: const Text("Yes, Revert"),
                          ),
                        ],
                      ),
                    ) ??
                        false;

                    if (confirm && inst.installmentId != null) {
                      Navigator.pop(ctx);
                      try {
                        await ApiService.revertPayment(inst.installmentId!);
                        EventBus().fire(PlayerEvent('updated'));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment Reverted! Bill is Pending.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],

              // 4. PENDING (Action Buttons)
              if (!isPaid && !isSkipped && !isWaived) ...[
                ListTile(
                  leading: const Icon(Icons.edit_calendar, color: Colors.orangeAccent),
                  title: const Text(
                    "Extend Due Date",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showExtendDialog(context, inst.installmentId!, inst.dueDate);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payment, color: Colors.greenAccent),
                  title: const Text(
                    "Record Payment",
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (inst.installmentId != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentsListScreen(
                            installmentId: inst.installmentId!,
                            remainingAmount: inst.remaining,
                          ),
                        ),
                      ).then((_) => EventBus().fire(PlayerEvent('updated')));
                    }
                  },
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Future<void> _showExtendDialog(
      BuildContext context,
      int installmentId,
      DateTime? currentDueDate,
      ) async {
    DateTime? selectedDate;
    final now = DateTime.now();
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Theme(
          data: ThemeData.dark(),
          child: StatefulBuilder(
            builder: (sbContext, setStateDialog) {
              return AlertDialog(
                backgroundColor: const Color(0xFF203A43),
                title: const Text(
                  'Extend Due Date',
                  style: TextStyle(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select a new due date.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        selectedDate == null
                            ? "Pick Date"
                            : DateFormat('dd MMM yyyy').format(selectedDate!),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: currentDueDate ?? now,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setStateDialog(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: selectedDate == null
                        ? null
                        : () async {
                      Navigator.pop(dialogContext);
                      try {
                        await ApiService.extendInstallmentDate(
                          installmentId: installmentId,
                          newDate: selectedDate!,
                        );
                        EventBus().fire(PlayerEvent('updated'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Date Updated!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Update'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}