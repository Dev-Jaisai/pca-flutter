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
  @override
  Widget build(BuildContext context) {
    // 1. Status Logic
    final status = (widget.summary.status ?? 'PENDING').toUpperCase();
    final bool isSkipped = status == 'SKIPPED';
    final bool isPaid = status == 'PAID';
    final bool isOverdue = !isPaid && !isSkipped && (widget.summary.remaining ?? 0) > 0;

    final Color statusColor = BillingHelper.getStatusColor(status, isOverdue);
    final Color cardBg = const Color(0xFF1E2A38).withOpacity(0.9);

    // 🔥 FIX: Filter List - Hide REFUNDED & CANCELLED from Dashboard Card
    final sortedInstallments = List<PlayerInstallmentSummary>.from(widget.installments)
        .where((inst) {
      String s = (inst.status ?? '').toUpperCase();
      // Refunded आणि Cancelled दोन्ही लपवा
      return s != 'CANCELLED';    })
        .toList();

    // Sort: Latest First
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
              // --- ROW 1: HEADER (Name & Status Badge) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),

                          // 🔥 Only call this ONCE
                          if (!widget.player.isActive)
                            _buildStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("${widget.player.group ?? 'No Group'} • Bill Day: ${widget.player.billingDay ?? 1}", style: const TextStyle(fontSize: 12, color: Colors.white54)),
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
                      "Total Due: ₹${widget.summary.remaining?.toInt() ?? 0}",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  )
                ],
              ),

              // 🔥 Credit Balance Row (Wallet)
              if ((widget.player.creditBalance ?? 0) > 0) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 16, color: Colors.greenAccent),
                      const SizedBox(width: 8),
                      Text(
                        "Wallet Credit: ₹${widget.player.creditBalance!.toInt()}",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "(Advance Adjustment)",
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // --- ROW 2: CHIPS (The Months) ---
              if (sortedInstallments.isNotEmpty) ...[
                const Text("Recent & Future:", style: TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sortedInstallments.take(4).map((inst) {
                    return _buildMonthChip(context, inst, widget.player);
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
                            MaterialPageRoute(builder: (_) => InstallmentsScreen(
                                player: widget.player,
                                initialFilter: widget.nextScreenFilter
                            ))
                        );
                        debugPrint("🔙 Returned from History. Triggering Refresh...");
                        EventBus().fire(PlayerEvent('updated'));
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                      child: const Text("Full History"),
                    ),
                  ),
                  const SizedBox(width: 12),

                  if ((widget.summary.remaining ?? 0) > 0)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          var target = sortedInstallments.firstWhere((i) => (i.remaining ?? 0) > 0, orElse: () => sortedInstallments.first);
                          if (target.installmentId != null) {
                            final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => RecordPaymentScreen(
                                    installmentId: target.installmentId!,
                                    remainingAmount: target.remaining
                                ))
                            );
                            if (result == true) {
                              EventBus().fire(PlayerEvent('updated'));
                            }
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

  // 🔥 Helper: Dynamic Status Badge (Left vs Holiday)
  Widget _buildStatusBadge() {
    bool isLeft = false;
    for (var inst in widget.installments) {
      if ((inst.notes ?? '').toLowerCase().contains('left')) {
        isLeft = true;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLeft ? Colors.redAccent : Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isLeft ? "⛔ LEFT" : "🏖️ HOLIDAY",
        style: TextStyle(
          color: isLeft ? Colors.white : Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- HELPER 1: BUILD CHIP ---
  Widget _buildMonthChip(BuildContext context, PlayerInstallmentSummary inst, Player player) {
    final status = (inst.status ?? '').toUpperCase();
    final String notes = (inst.notes ?? '').toLowerCase();

    // Logic
    final bool isWaived = status == 'SKIPPED' && (notes.contains('left') || notes.contains('waived'));
    final bool isSkipped = status == 'SKIPPED' && !isWaived;
    final bool isPaid = status == 'PAID';
    final bool isOverdue = !isPaid && !isSkipped && !isWaived && inst.dueDate != null && inst.dueDate!.isBefore(DateTime.now());

    // 🔥 NEW STATUS FLAGS
    final bool isRefunded = status == 'REFUNDED';
    final bool isCancelled = status == 'CANCELLED';

    // Corner Logic: Left Emoji or Wallet/Credit Icon
    final bool showLeftEmoji = !player.isActive && notes.contains('left');
    final bool showHolidayIcon = isSkipped || (notes.contains('holiday') || notes.contains('credit'));

    Color chipColor = Colors.orangeAccent;
    Color textColor = Colors.black;
    IconData mainIcon = Icons.access_time;

    if (isWaived) {
      chipColor = Colors.grey.shade700; textColor = Colors.white70; mainIcon = Icons.person_off;
    } else if (isRefunded) {
      // 💸 REFUNDED STYLE (Purple)
      chipColor = Colors.purpleAccent;
      textColor = Colors.white;
      mainIcon = Icons.replay;
    } else if (isCancelled) {
      // 🚫 CANCELLED STYLE (Grey/Red)
      chipColor = Colors.red.withOpacity(0.2);
      textColor = Colors.white70;
      mainIcon = Icons.block;
    } else if (isSkipped) {
      chipColor = Colors.cyanAccent.withOpacity(0.9); textColor = Colors.black; mainIcon = Icons.beach_access;
    } else if (isPaid) {
      chipColor = Colors.greenAccent; textColor = Colors.black; mainIcon = Icons.check_circle;
    } else if (isOverdue) {
      chipColor = Colors.redAccent; textColor = Colors.white; mainIcon = Icons.warning;
    }

    String label = inst.dueDate != null ? DateFormat('MMM yy').format(inst.dueDate!) : "Unknown";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showChipOptions(context, inst),
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main Chip Body
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: chipColor,
                borderRadius: BorderRadius.circular(6),
                border: isWaived ? Border.all(color: Colors.white24) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mainIcon, size: 12, color: textColor),
                  const SizedBox(width: 4),
                  Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
            ),

            // Corner Emoji: Left (Runner)
            if (showLeftEmoji)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)]
                  ),
                  child: const Text("🏃‍♂️", style: TextStyle(fontSize: 10)),
                ),
              ),

            // Corner Icon: Credit (Wallet) or Holiday (Umbrella)
            if (showHolidayIcon && !isSkipped && !showLeftEmoji)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2)]
                  ),
                  child: Icon(
                      notes.contains('credit') ? Icons.account_balance_wallet : Icons.beach_access,
                      size: 10,
                      color: notes.contains('credit') ? Colors.green : Colors.blueAccent
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- HELPER 2: BOTTOM SHEET ---
  void _showChipOptions(BuildContext context, PlayerInstallmentSummary inst) {
    final status = (inst.status ?? '').toUpperCase();
    final String notes = (inst.notes ?? '').toLowerCase();

    // Logic
    final bool isWaived = status == 'SKIPPED' && (notes.contains('left') || notes.contains('waived'));
    final bool isSkipped = status == 'SKIPPED' && !isWaived;
    final bool isPaid = status == 'PAID';

    DateTime anchorDate = inst.dueDate ?? DateTime.now();
    int cycle = widget.player.paymentCycleMonths ?? 1;
    String periodTitle = DateFormat('MMM yyyy').format(anchorDate);

    if (!isSkipped && !isWaived && cycle > 1) {
      DateTime endDate = DateTime(anchorDate.year, anchorDate.month);
      DateTime startDate = DateTime(endDate.year, endDate.month - cycle + 1);
      periodTitle = '${DateFormat('MMM').format(startDate)} - ${DateFormat('MMM').format(endDate)} ${endDate.year}';
    }

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
              const Text("Installment Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.date_range, color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 8),
                  Text("Cycle: $periodTitle", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),

              if (inst.dueDate != null)
                Row(
                  children: [
                    const Icon(Icons.event, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text("Due Date: ${DateFormat('dd MMM yyyy').format(inst.dueDate!)}", style: const TextStyle(color: Colors.white70)),
                  ],
                ),

              const SizedBox(height: 20),

              if (isWaived) ...[
                _buildStatusBox("⛔ WAIVED OFF / LEFT:", inst.notes ?? "Student Left Academy.", Colors.grey),
              ],

              // 5. REFUNDED DETAILS
              if (status == 'REFUNDED') ...[
                _buildStatusBox(
                    "💸 PAYMENT REFUNDED:",
                    inst.notes ?? "Payment has been refunded.",
                    Colors.purpleAccent
                ),
              ],

              // 6. CANCELLED DETAILS
              if (status == 'CANCELLED') ...[
                _buildStatusBox(
                    "🚫 BILL CANCELLED:",
                    inst.notes ?? "Bill cancelled (Player Left).",
                    Colors.redAccent
                ),
              ],

              if (isSkipped) ...[
                _buildStatusBox("🏖️ HOLIDAY / PAUSED:", (inst.notes != null && inst.notes!.isNotEmpty) ? inst.notes! : "Marked as Holiday.", Colors.cyanAccent),
              ],

              if (isPaid) ...[
                _buildPaidBox(),
                const SizedBox(height: 16),
                _buildRevertButton(ctx, inst),
              ],

              if (!isPaid && !isSkipped && !isWaived && status != 'CANCELLED' && status != 'REFUNDED') ...[
                if (inst.notes != null && inst.notes!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("ℹ️ Note / Credit Info:", style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(inst.notes!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildActionButtons(ctx, inst),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBox(String title, String content, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPaidBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.greenAccent.withOpacity(0.3))),
      child: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.greenAccent),
          SizedBox(width: 8),
          Expanded(child: Text("This bill is fully PAID.", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }

  Widget _buildRevertButton(BuildContext ctx, PlayerInstallmentSummary inst) {
    return ListTile(
      leading: const Icon(Icons.undo, color: Colors.redAccent),
      title: const Text("Revert Payment (Refund)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      onTap: () async {
        bool confirm = await showDialog(
            context: context,
            builder: (dCtx) => AlertDialog(
              backgroundColor: const Color(0xFF203A43),
              title: const Text("Revert Payment?", style: TextStyle(color: Colors.white)),
              content: const Text("This will mark the bill as PENDING (or Refunded).", style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text("Cancel")),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(dCtx, true), child: const Text("Yes, Revert"))
              ],
            )
        ) ?? false;

        if (confirm && inst.installmentId != null) {
          Navigator.pop(ctx);
          try {
            await ApiService.revertPayment(inst.installmentId!);
            EventBus().fire(PlayerEvent('updated'));
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Reverted!'), backgroundColor: Colors.orange));
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
          }
        }
      },
    );
  }

  Widget _buildActionButtons(BuildContext ctx, PlayerInstallmentSummary inst) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.edit_calendar, color: Colors.orangeAccent),
          title: const Text("Extend Due Date", style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(ctx);
            _showExtendDialog(context, inst.installmentId!, inst.dueDate);
          },
        ),
        ListTile(
          leading: const Icon(Icons.payment, color: Colors.greenAccent),
          title: const Text("Record Payment", style: TextStyle(color: Colors.white)),
          onTap: () {
            Navigator.pop(ctx);
            if (inst.installmentId != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentsListScreen(installmentId: inst.installmentId!, remainingAmount: inst.remaining))).then((_) => EventBus().fire(PlayerEvent('updated')));
            }
          },
        ),
      ],
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