// lib/models/installment.dart
class Installment {
  final int id; // used throughout UI
  final int? installmentId; // also map if backend uses this name
  final int? periodMonth;
  final int? periodYear;
  final double? amount;
  final double? paidAmount;
  final double? remainingAmount;
  final String? status;
  final DateTime? dueDate;

  Installment({
    required this.id,
    this.installmentId,
    this.periodMonth,
    this.periodYear,
    this.amount,
    this.paidAmount,
    this.remainingAmount,
    this.status,
    this.dueDate,
  });

  factory Installment.fromJson(Map<String, dynamic> json) {
    // backend might return "installmentId" (DTO) or "id" depending on endpoint
    int idVal = 0;
    if (json['id'] != null) {
      idVal = (json['id'] is int) ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0;
    } else if (json['installmentId'] != null) {
      idVal = (json['installmentId'] is int) ? json['installmentId'] as int : int.tryParse(json['installmentId'].toString()) ?? 0;
    }

    DateTime? due;
    final dueRaw = json['dueDate'] ?? json['due_date'];
    if (dueRaw != null) {
      try {
        due = DateTime.parse(dueRaw.toString());
      } catch (_) {
        due = null;
      }
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Installment(
      id: idVal,
      installmentId: json['installmentId'] is int ? json['installmentId'] as int : (json['installmentId'] != null ? int.tryParse(json['installmentId'].toString()) : null),
      periodMonth: json['periodMonth'] is int ? json['periodMonth'] as int : (json['periodMonth'] != null ? int.tryParse(json['periodMonth'].toString()) : null),
      periodYear: json['periodYear'] is int ? json['periodYear'] as int : (json['periodYear'] != null ? int.tryParse(json['periodYear'].toString()) : null),
      amount: parseDouble(json['amount']),
      paidAmount: parseDouble(json['paidAmount']),
      remainingAmount: parseDouble(json['remainingAmount']),
      status: json['status']?.toString(),
      dueDate: due,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'installmentId': installmentId,
    'periodMonth': periodMonth,
    'periodYear': periodYear,
    'amount': amount,
    'paidAmount': paidAmount,
    'remainingAmount': remainingAmount,
    'status': status,
    'dueDate': dueDate?.toIso8601String(),
  };
}
