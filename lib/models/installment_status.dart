// lib/models/installment_status.dart
class InstallmentStatus {
  final int playerId;
  final bool hasInstallments;

  InstallmentStatus({required this.playerId, required this.hasInstallments});

  factory InstallmentStatus.fromJson(Map<String, dynamic> json) {
    return InstallmentStatus(
      playerId: (json['playerId'] as num).toInt(),
      hasInstallments: json['hasInstallments'] as bool,
    );
  }
}
