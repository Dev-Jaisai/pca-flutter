import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/player.dart';
import '../models/player_installment_summary.dart';
import '../screens/installments/installments_screen.dart';

class PlayerSummaryCard extends StatelessWidget {
  final Player player;
  final PlayerInstallmentSummary summary;
  final List<PlayerInstallmentSummary> installments;

  const PlayerSummaryCard({
    super.key,
    required this.player,
    required this.summary,
    this.installments = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Check remaining amount
    final double remaining = summary.remaining ?? 0.0;
    final bool isOverdue = remaining > 0;

    // Status Color (Red if pending, Green if all paid)
    final Color statusColor = isOverdue ? Colors.red : Colors.green;

    // Sort installments by date
    final sortedInstallments = List<PlayerInstallmentSummary>.from(installments)
      ..sort((a, b) => (a.dueDate ?? DateTime(2000)).compareTo(b.dueDate ?? DateTime(2000)));

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
                      Text(
                        player.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        player.group ?? 'No Group',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  // Item Count Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOverdue ? Colors.red.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Items: ${installments.length}',
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

              // --- STATS ROW ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat('Total', '₹${(summary.installmentAmount ?? 0).toStringAsFixed(0)}', Colors.black87),
                  _buildStat('Paid', '₹${summary.totalPaid.toStringAsFixed(0)}', Colors.green),
                  _buildStat('Remaining', '₹${remaining.toStringAsFixed(0)}', isOverdue ? Colors.red : Colors.grey),
                ],
              ),

              const SizedBox(height: 12),

              // --- MONTH PILLS ---
              if (sortedInstallments.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sortedInstallments.map((inst) => _buildMonthChip(inst)).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // --- ACTION BUTTONS ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openDetails(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text("View Details", style: TextStyle(color: Colors.black)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      // ✅ FIX: Disable button if remaining is 0 (Paid)
                      onPressed: remaining > 0 ? () => _openDetails(context) : null,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300, // Gray when disabled
                        disabledForegroundColor: Colors.grey.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(remaining > 0 ? "Pay Now" : "Paid"), // Change text too
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

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstallmentsScreen(player: player),
      ),
    );
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

  Widget _buildMonthChip(PlayerInstallmentSummary inst) {
    final status = (inst.status).toUpperCase();
    final bool isPaid = status == 'PAID';
    final df = DateFormat('d MMM');

    final dueDateStr = inst.dueDate != null ? df.format(inst.dueDate!) : 'N/A';

    final paidDateStr = (isPaid && inst.lastPaymentDate != null)
        ? df.format(inst.lastPaymentDate!)
        : (isPaid ? 'Paid' : null);

    final String label = isPaid && paidDateStr != null && paidDateStr != 'Paid'
        ? '$dueDateStr / $paidDateStr'
        : dueDateStr;

    final bg = isPaid ? Colors.green.shade50 : Colors.red.shade50;
    final textCol = isPaid ? Colors.green.shade800 : Colors.red.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textCol),
          ),
          if (isPaid) ...[
            const SizedBox(width: 4),
            Icon(Icons.check_circle, size: 12, color: textCol),
          ]
        ],
      ),
    );
  }
}