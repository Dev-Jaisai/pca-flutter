class Installment {
  final int id;
  final int? playerId;
  final int? periodMonth;
  final int? periodYear;
  final double? amount;
  final double? paidAmount;
  final String? status;
  final DateTime? dueDate;
  final String? notes;

  Installment({
    required this.id,
    this.playerId,
    this.periodMonth,
    this.periodYear,
    this.amount,
    this.paidAmount,
    this.status,
    this.dueDate,
    this.notes,
  });

  factory Installment.fromJson(Map<String, dynamic> json) {
    // 1. Safe ID Parsing (Crucial Fix)
    // Jar ID null aala, tar 0 ghyaycha (Crash honar nahi)
    int safeId = 0;
    if (json['id'] != null) {
      if (json['id'] is int) {
        safeId = json['id'];
      } else if (json['id'] is String) {
        safeId = int.tryParse(json['id']) ?? 0;
      }
    }

    // 2. Safe Player ID Parsing (Handle nested object or flat field)
    int? pId;
    if (json['playerId'] != null) {
      pId = json['playerId'] is int ? json['playerId'] : int.tryParse(json['playerId'].toString());
    } else if (json['player'] != null && json['player'] is Map) {
      // Jar backend ne 'Player' object pathavla asel
      var pObj = json['player'];
      if (pObj['id'] != null) {
        pId = pObj['id'] is int ? pObj['id'] : int.tryParse(pObj['id'].toString());
      }
    }

    // 3. Date Parsing
    DateTime? parsedDate;
    if (json['dueDate'] != null) {
      try {
        parsedDate = DateTime.parse(json['dueDate']);
      } catch (e) {
        parsedDate = null;
      }
    }

    // 4. Double Parsing Helper
    double? parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is int) return val.toDouble();
      if (val is double) return val;
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return Installment(
      id: safeId, // 🔥 Fixed: Never Null
      playerId: pId,
      periodMonth: json['periodMonth'] is int ? json['periodMonth'] : int.tryParse(json['periodMonth']?.toString() ?? ''),
      periodYear: json['periodYear'] is int ? json['periodYear'] : int.tryParse(json['periodYear']?.toString() ?? ''),
      amount: parseDouble(json['amount']),
      paidAmount: parseDouble(json['paidAmount']),
      status: json['status'],
      dueDate: parsedDate,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'playerId': playerId,
    'periodMonth': periodMonth,
    'periodYear': periodYear,
    'amount': amount,
    'paidAmount': paidAmount,
    'status': status,
    'dueDate': dueDate?.toIso8601String(),
    'notes': notes,
  };
}