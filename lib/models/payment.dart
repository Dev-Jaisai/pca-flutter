// lib/models/payment.dart
class Payment {
  final int id;
  final int installmentId;
  final double amount;
  final DateTime paidOn;
  final String? paymentMethod;
  final String? reference;

  Payment({
    required this.id,
    required this.installmentId,
    required this.amount,
    required this.paidOn,
    this.paymentMethod,
    this.reference,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: (json['id'] ?? 0) is int ? json['id'] as int : int.parse(json['id'].toString()),
      installmentId: (json['installmentId'] ?? 0) is int ? json['installmentId'] as int : int.parse(json['installmentId'].toString()),
      amount: (json['amount'] ?? 0).toDouble(),
      paidOn: DateTime.parse(json['paidOn'] ?? json['paid_on'] ?? json['paidOnDate'] ?? DateTime.now().toIso8601String()),
      paymentMethod: json['paymentMethod'] ?? json['payment_method'],
      reference: json['reference'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'installmentId': installmentId,
    'amount': amount,
    'paidOn': paidOn.toIso8601String(),
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (reference != null) 'reference': reference,
  };
}
