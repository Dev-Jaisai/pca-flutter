import 'package:flutter/cupertino.dart';

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
    // 🔥 DEBUG: Print all keys to see what's coming
    debugPrint("📦 Installment JSON Keys: ${json.keys.toList()}");

    // 1. SAFE ID PARSING - Check ALL possible key names
    int safeId = 0;

    // Priority order:
    // 1. 'installmentId' (from backend)
    // 2. 'id' (standard)
    // 3. 'installment_id' (snake_case)

    if (json['installmentId'] != null) {
      if (json['installmentId'] is int) {
        safeId = json['installmentId'];
        debugPrint("✅ ID from 'installmentId': $safeId");
      } else if (json['installmentId'] is String) {
        safeId = int.tryParse(json['installmentId']) ?? 0;
        debugPrint("✅ ID from 'installmentId' (string): $safeId");
      }
    }
    else if (json['id'] != null) {
      if (json['id'] is int) {
        safeId = json['id'];
        debugPrint("✅ ID from 'id': $safeId");
      } else if (json['id'] is String) {
        safeId = int.tryParse(json['id']) ?? 0;
        debugPrint("✅ ID from 'id' (string): $safeId");
      }
    }
    else if (json['installment_id'] != null) {
      if (json['installment_id'] is int) {
        safeId = json['installment_id'];
        debugPrint("✅ ID from 'installment_id': $safeId");
      } else if (json['installment_id'] is String) {
        safeId = int.tryParse(json['installment_id']) ?? 0;
        debugPrint("✅ ID from 'installment_id' (string): $safeId");
      }
    }
    else {
      debugPrint("⚠️ WARNING: No ID field found in installment JSON!");
      // Print all available keys
      json.forEach((key, value) {
        debugPrint("  $key: $value (${value.runtimeType})");
      });
    }

    // 2. Safe Player ID Parsing (Handle nested object or flat field)
    int? pId;
    if (json['playerId'] != null) {
      pId = json['playerId'] is int ? json['playerId'] : int.tryParse(json['playerId'].toString());
    } else if (json['player_id'] != null) {
      pId = json['player_id'] is int ? json['player_id'] : int.tryParse(json['player_id'].toString());
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
        parsedDate = DateTime.parse(json['dueDate'].toString());
      } catch (e) {
        parsedDate = null;
        debugPrint("❌ Error parsing dueDate: $e");
      }
    } else if (json['due_date'] != null) {
      try {
        parsedDate = DateTime.parse(json['due_date'].toString());
      } catch (e) {
        parsedDate = null;
        debugPrint("❌ Error parsing due_date: $e");
      }
    }

    // 4. Double Parsing Helper
    double? parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is int) return val.toDouble();
      if (val is double) return val;
      return double.tryParse(val.toString()) ?? 0.0;
    }

    // 5. Status parsing
    String? statusVal;
    if (json['status'] != null) {
      statusVal = json['status'].toString();
    } else if (json['installment_status'] != null) {
      statusVal = json['installment_status'].toString();
    }

    return Installment(
      id: safeId, // 🔥 Fixed: Should now get correct ID
      playerId: pId,
      periodMonth: json['periodMonth'] is int
          ? json['periodMonth']
          : int.tryParse(json['periodMonth']?.toString() ?? ''),
      periodYear: json['periodYear'] is int
          ? json['periodYear']
          : int.tryParse(json['periodYear']?.toString() ?? ''),
      amount: parseDouble(json['amount']),
      paidAmount: parseDouble(json['paidAmount'] ?? json['paid_amount']),
      status: statusVal,
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