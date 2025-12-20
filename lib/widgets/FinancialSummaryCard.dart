import 'package:flutter/material.dart';

class FinancialSummaryCard extends StatelessWidget {
  final String title;
  final double totalTarget;
  final double totalCollected;
  final double totalPending;
  final String? countLabel;

  const FinancialSummaryCard({
    super.key,
    required this.title,
    required this.totalTarget,
    required this.totalCollected,
    required this.totalPending,
    this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (countLabel != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    countLabel!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(Icons.monetization_on, "Target", totalTarget),
              _buildSummaryItem(Icons.check_circle, "Collected", totalCollected),
              _buildSummaryItem(Icons.pending, "Remaining", totalPending),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, double amount) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          "₹${amount >= 1000 ? (amount / 1000).toStringAsFixed(1) + 'k' : amount.toInt()}",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}