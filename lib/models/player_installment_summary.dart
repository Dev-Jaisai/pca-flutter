// lib/models/player_installment_summary.dart
import 'package:flutter/foundation.dart';

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
  final String status; // NO_INSTALLMENT / PENDING / PARTIALLY_PAID / PAID

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
  });

  factory PlayerInstallmentSummary.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString());
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return PlayerInstallmentSummary(
      playerId: (json['playerId'] as num).toInt(),
      playerName: json['playerName']?.toString() ?? '',
      phone: json['phone']?.toString(),
      groupName: json['groupName']?.toString(),
      joinDate: parseDate(json['joinDate']),
      installmentId: json['installmentId'] != null ? (json['installmentId'] as num).toInt() : null,
      installmentAmount: parseDouble(json['installmentAmount']),
      totalPaid: parseDouble(json['totalPaid']) ?? 0.0,
      remaining: parseDouble(json['remaining']),
      dueDate: parseDate(json['dueDate']),
      status: json['status']?.toString() ?? 'NO_INSTALLMENT',
    );
  }
}
