class PlayerInstallmentSummary {
  final int? installmentId;
  final int playerId;
  final String playerName;
  final String? phone;
  final String? groupName;
  final DateTime? joinDate;
  final double? installmentAmount;
  final double totalPaid;
  final double? remaining;
  final DateTime? dueDate;
  final String status;
  final DateTime? lastPaymentDate;
  final int? paymentCycleMonths;
  final int? periodMonth;
  final int? periodYear;
  final String? notes;

  PlayerInstallmentSummary({
    this.installmentId,
    required this.playerId,
    required this.playerName,
    this.phone,
    this.groupName,
    this.joinDate,
    this.installmentAmount,
    required this.totalPaid,
    this.remaining,
    this.dueDate,
    required this.status,
    this.lastPaymentDate,
    this.paymentCycleMonths,
    this.periodMonth,
    this.periodYear,
    this.notes,
  });

  factory PlayerInstallmentSummary.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return double.tryParse(value.toString()) ?? 0.0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return PlayerInstallmentSummary(
      installmentId: json['installmentId'] ?? json['id'],
      playerId: json['playerId'] ?? 0,
      playerName: json['playerName'] ?? 'Unknown',
      phone: json['phone'],
      groupName: json['groupName'],
      joinDate: parseDate(json['joinDate']),

      // 🔥 FIX: Prioritize keys sent by Spring Boot DTO ('amount', 'paidAmount', 'remainingAmount')
      installmentAmount: parseDouble(json['amount'] ?? json['installmentAmount']),
      totalPaid: parseDouble(json['paidAmount'] ?? json['totalPaid']),
      remaining: parseDouble(json['remainingAmount'] ?? json['remaining']),

      dueDate: parseDate(json['dueDate']),
      status: json['status'] ?? 'PENDING',
      lastPaymentDate: parseDate(json['lastPaymentDate']),
      paymentCycleMonths: json['paymentCycleMonths'],
      notes: json['notes'],
      periodMonth: json['periodMonth'],
      periodYear: json['periodYear'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'installmentId': installmentId,
      'playerId': playerId,
      'playerName': playerName,
      'phone': phone,
      'groupName': groupName,
      'joinDate': joinDate?.toIso8601String(),
      'installmentAmount': installmentAmount,
      'totalPaid': totalPaid,
      'remaining': remaining,
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
      'lastPaymentDate': lastPaymentDate?.toIso8601String(),
      'paymentCycleMonths': paymentCycleMonths,
      'periodMonth': periodMonth,
      'periodYear': periodYear,
      'notes': notes,
    };
  }
}