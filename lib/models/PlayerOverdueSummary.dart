class PlayerOverdueSummary {
  final int playerId;
  final String playerName;
  final String groupName;
  final String? phone;

  // Breakdown fields
  final double totalOriginalAmount; // e.g. 30000
  final double totalPaidAmount;     // e.g. 10000
  final double totalOverdueRemaining; // e.g. 20000

  final List<DateTime> overdueMonths;
  final List<int> installmentIds;

  PlayerOverdueSummary({
    required this.playerId,
    required this.playerName,
    required this.groupName,
    this.phone,
    required this.totalOriginalAmount,
    required this.totalPaidAmount,
    required this.totalOverdueRemaining,
    required this.overdueMonths,
    required this.installmentIds,
  });
}