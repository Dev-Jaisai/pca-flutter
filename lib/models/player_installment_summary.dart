// lib/models/player_installment_summary.dart

class PlayerInstallmentSummary {
  final int playerId;
  final String playerName;
  final String? phone;
  final String? groupName;
  final DateTime? joinDate;
  final int? installmentId;
  final double? installmentAmount;
  final double totalPaid;
  final double? remaining;
  final DateTime? dueDate;
  final String status;
  final DateTime? lastPaymentDate;

  PlayerInstallmentSummary({
    required this.playerId,
    required this.playerName,
    this.phone,
    this.groupName,
    this.joinDate,
    this.installmentId,
    this.installmentAmount,
    required this.totalPaid,
    this.remaining,
    this.dueDate,
    required this.status,
    this.lastPaymentDate,
  });

  factory PlayerInstallmentSummary.fromJson(Map<String, dynamic> json) {
    return PlayerInstallmentSummary(
      playerId: json['playerId'] ?? 0,
      playerName: json['playerName'] ?? '',
      phone: json['phone'],
      groupName: json['groupName'],
      joinDate: json['joinDate'] != null ? DateTime.parse(json['joinDate']) : null,
      installmentId: json['installmentId'],
      installmentAmount: json['installmentAmount'] != null
          ? (json['installmentAmount'] as num).toDouble()
          : null,
      totalPaid: (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble(),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      status: json['status'] ?? 'PENDING',
      lastPaymentDate: json['lastPaymentDate'] != null
          ? DateTime.parse(json['lastPaymentDate'])
          : null,
    );
  }

  // Ensure this method is inside this class in this file!
  Map<String, dynamic> toJson() {
    return {
      'playerId': playerId,
      'playerName': playerName,
      'phone': phone,
      'groupName': groupName,
      'joinDate': joinDate?.toIso8601String(),
      'installmentId': installmentId,
      'installmentAmount': installmentAmount,
      'totalPaid': totalPaid,
      'remaining': remaining,
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
    };
  }
}