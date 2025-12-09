// lib/models/fee_structure.dart
class FeeStructure {
  final int id;
  final int groupId;
  final String groupName;
  final double monthlyFee;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;

  FeeStructure({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.monthlyFee,
    this.effectiveFrom,
    this.effectiveTo,
  });

  factory FeeStructure.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return FeeStructure(
      id: (json['id'] is int) ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      groupId: (json['groupId'] is int) ? json['groupId'] as int : int.tryParse(json['groupId']?.toString() ?? '0') ?? 0,
      groupName: json['groupName'] ?? json['group']?['name'] ?? '',
      monthlyFee: (json['monthlyFee'] is num) ? (json['monthlyFee'] as num).toDouble() : double.tryParse(json['monthlyFee']?.toString() ?? '0') ?? 0.0,
      effectiveFrom: parseDate(json['effectiveFrom']),
      effectiveTo: parseDate(json['effectiveTo']),
    );
  }
}
