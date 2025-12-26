class PlayerInstallmentSummary {
  final int? installmentId; // Make sure this matches your JSON (sometimes it is 'id')
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

  // 🔥 IMPORTANT FIELDS ADDED
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
    // 🔥 Add to Constructor
    this.periodMonth,
    this.periodYear,
    this.notes,
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
          // print("Date Parse Error: $value");
          return null;
        }
      }
      return null;
    }

    return PlayerInstallmentSummary(
      // Handle ID mapping (sometimes backend sends 'id' or 'installmentId')
      installmentId: json['installmentId'] ?? json['id'],
      playerId: json['playerId'] ?? 0,
      playerName: json['playerName'] ?? 'Unknown',
      phone: json['phone'],
      groupName: json['groupName'],
      joinDate: parseDate(json['joinDate']),
      installmentAmount: parseDouble(json['installmentAmount'] ?? json['amount']), // Check both keys
      totalPaid: parseDouble(json['totalPaid'] ?? json['paidAmount']),
      remaining: parseDouble(json['remaining'] ?? json['remainingAmount']),
      dueDate: parseDate(json['dueDate']),
      status: json['status'] ?? 'PENDING',
      lastPaymentDate: parseDate(json['lastPaymentDate']),
      paymentCycleMonths: json['paymentCycleMonths'],
      notes: json['notes'],
      // 🔥🔥 MAPPING NEW FIELDS 🔥🔥
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
      'notes': notes, // 🔥 He add karu shakta (Optional for now)
    };
  }
}