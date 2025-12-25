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
  final int? paymentCycleMonths; // Added this

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
    this.paymentCycleMonths,
  });

  factory PlayerInstallmentSummary.fromJson(Map<String, dynamic> json) {
    // --- Helper to parse various number formats ---
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return double.tryParse(value.toString()) ?? 0.0;
    }

    // --- Helper to parse Dates safely ---
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          print("Date Parse Error: $value"); // Debug
          return null;
        }
      }
      return null;
    }

    return PlayerInstallmentSummary(
      playerId: json['playerId'] ?? 0,
      playerName: json['playerName'] ?? 'Unknown',
      phone: json['phone'],
      groupName: json['groupName'],
      joinDate: parseDate(json['joinDate']),
      installmentId: json['installmentId'],
      installmentAmount: parseDouble(json['installmentAmount']),
      totalPaid: parseDouble(json['totalPaid']),
      remaining: parseDouble(json['remaining']),
      dueDate: parseDate(json['dueDate']),
      status: json['status'] ?? 'PENDING',

      // 🔥🔥🔥 THE FIX IS HERE 🔥🔥🔥
      // Backend returns full ISO string with time (e.g. 2025-12-24T12:00:36...)
      // This helper will handle it correctly.
      lastPaymentDate: parseDate(json['lastPaymentDate']),

      paymentCycleMonths: json['paymentCycleMonths'],
    );
  }

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
      'paymentCycleMonths': paymentCycleMonths,
    };
  }
}