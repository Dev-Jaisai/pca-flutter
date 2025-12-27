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
      margin: const EdgeInsets.only(bottom: 16), // Space below header
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], // Purple-Blue Gradient
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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (countLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    countLabel!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                )
            ],
          ),
          const SizedBox(height: 20),

          // Stats Row
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
    // Format K for thousands (e.g. 5000 -> 5.0k)
    String formattedAmount = amount >= 1000
        ? "${(amount / 1000).toStringAsFixed(1)}k"
        : amount.toInt().toString();

    // Use specific colors for logic
    Color iconColor = Colors.white70;
    if (label == "Collected") iconColor = Colors.greenAccent;
    if (label == "Remaining") iconColor = Colors.orangeAccent;

    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          "₹$formattedAmount",
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}