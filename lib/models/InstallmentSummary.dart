// lib/models/installment_summary.dart
class InstallmentSummary {
  final int playerId;
  final String playerName;
  final String phone;
  final String groupName;
  final String joinDate;         // ISO date string
  final double installmentAmount;
  final double totalPaid;
  final double remaining;
  final String dueDate;          // ISO date string
  final String status;
  final int installmentId;

  InstallmentSummary({
    required this.playerId,
    required this.playerName,
    required this.phone,
    required this.groupName,
    required this.joinDate,
    required this.installmentAmount,
    required this.totalPaid,
    required this.remaining,
    required this.dueDate,
    required this.status,
    required this.installmentId,
  });

  factory InstallmentSummary.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return InstallmentSummary(
      playerId: (json['playerId'] as num).toInt(),
      playerName: json['playerName'] ?? '',
      phone: json['phone'] ?? '',
      groupName: json['groupName'] ?? '',
      joinDate: json['joinDate'] ?? '',
      installmentAmount: parseDouble(json['installmentAmount']),
      totalPaid: parseDouble(json['totalPaid']),
      remaining: parseDouble(json['remaining']),
      dueDate: json['dueDate'] ?? '',
      status: json['status'] ?? '',
      installmentId: (json['installmentId'] as num).toInt(),
    );
  }
}
