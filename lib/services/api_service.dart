// lib/services/api_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/InstallmentSummary.dart';
import '../models/fee_structure.dart';
import '../models/installment.dart';
import '../models/installment_status.dart';
import '../models/payment.dart';
import '../models/player.dart';
import '../models/group.dart';
import '../models/player_installment_summary.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator, localhost for iOS simulator, or PC LAN IP for real devices.


  static const String baseUrl = 'http://10.0.2.2:5000';
  // static const String baseUrl = 'https://pca-backend-1.onrender.com';
  // ---------------- Players ----------------
  static Future<List<Player>> fetchPlayers() async {
    final url = Uri.parse('$baseUrl/api/players');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Player.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
          'Failed to load players: ${response.statusCode} - ${response.body}');
    }
  }
  static Future<Player> fetchPlayerById(int id) async {
    final url = Uri.parse('$baseUrl/api/players/$id');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      // 🔥 DEBUG: Print the raw JSON
      debugPrint("📦 Raw JSON from fetchPlayerById($id):");
      debugPrint(data.toString());
      debugPrint("isActive in JSON: ${data['isActive']}");
      debugPrint("is_active in JSON: ${data['is_active']}");

      return Player.fromJson(data);
    } else {
      throw Exception('Failed to load player: ${response.statusCode} - ${response.body}');
    }
  }
// ✅ UPDATED createPlayer
  static Future<Player> createPlayer({
    required String name,
    required String phone,
    int? age,
    DateTime? joinDate,
    required int groupId,
    String? notes,
    String? photoUrl,

    // New Parameters
    DateTime? firstInstallmentDate,
    int? paymentCycleMonths, // 1 or 3
  }) async {
    final url = Uri.parse('$baseUrl/api/players');
    final body = {
      'name': name,
      'phone': phone,
      if (age != null) 'age': age,
      if (joinDate != null)
        'joinDate': joinDate.toIso8601String().split('T')[0],
      'groupId': groupId,
      if (notes != null) 'notes': notes,
      if (photoUrl != null) 'photoUrl': photoUrl,

      // Pass to Backend
      if (firstInstallmentDate != null)
        'firstInstallmentDate': firstInstallmentDate.toIso8601String().split('T')[0],
      if (paymentCycleMonths != null)
        'paymentCycleMonths': paymentCycleMonths,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Player.fromJson(json.decode(response.body));
    } else {
      throw Exception(
          'Failed to create player: ${response.statusCode} - ${response.body}');
    }
  }
  static Future<void> deletePlayer(int id) async {
    final url = Uri.parse('$baseUrl/api/players/$id');
    final response = await http.delete(url);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          'Failed to delete player: ${response.statusCode} - ${response.body}');
    }
  }


  // ✅ NEW: Bulk Extend for Holidays (+ Days logic)
  static Future<void> bulkExtendDays({
    required int month,
    required int year,
    required int days,
  }) async {
    // Note: Ensure your backend Controller has this endpoint mapped as:
    // @PostMapping("/bulk-extend-days")
    final url = Uri.parse('$baseUrl/api/installments/bulk-extend-days?month=$month&year=$year&days=$days');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to extend dates: ${response.body}');
    }
  }
  // ---------------- Groups ----------------
  static Future<List<Group>> fetchGroups() async {
    final url = Uri.parse('$baseUrl/api/groups');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Group.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // If backend not available, throw so caller can handle fallback.
      throw Exception(
          'Failed to load groups: ${response.statusCode} - ${response.body}');
    }
  }
  static Future<void> createGroup({required String name, required double fee}) async {
    // ❌ OLD (Wrong):
    // Uri.parse('$baseUrl/groups'),

    // ✅ NEW (Correct): Add '/api' before '/groups'
    final response = await http.post(
      Uri.parse('$baseUrl/api/groups'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'monthlyFee': fee,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create group: ${response.body}');
    }
  }

  static Future<void> updateGroup(int id, String name, double fee) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/groups/$id'), // '/api' विसरू नका
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'monthlyFee': fee,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update group: ${response.body}');
    }
  }

  static Future<void> deleteGroup(int id) async {
    final url = Uri.parse('$baseUrl/api/groups/$id');
    final response = await http.delete(url);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          'Failed to delete group: ${response.statusCode} - ${response.body}');
    }
  }

  // ---------------- Installments ----------------
  static Future<List<Installment>> fetchInstallmentsByPlayer(
      int playerId) async {
    final url = Uri.parse('$baseUrl/api/installments/player/$playerId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Installment.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
          'Failed to load installments: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<void> createInstallment({
    required int playerId,
    required int periodMonth,
    required int periodYear,
    required DateTime dueDate,
    double? amount,
  }) async {
    final url = Uri.parse('$baseUrl/api/installments');
    final body = {
      'playerId': playerId,
      'periodMonth': periodMonth,
      'periodYear': periodYear,
      'dueDate': dueDate.toIso8601String().split('T')[0],
      if (amount != null) 'amount': amount,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to create installment: ${response.statusCode} - ${response.body}');
    }
  }

  // ---------------- Fee Structures ----------------
  static Future<List<FeeStructure>> fetchFeesByGroup(int groupId) async {
    final url = Uri.parse('$baseUrl/api/fees/group/$groupId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => FeeStructure.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
          'Failed to load fees: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<FeeStructure> createFeeStructure({
    required int groupId,
    required double monthlyFee,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
  }) async {
    final url = Uri.parse('$baseUrl/api/fees');
    final body = {
      'groupId': groupId,
      'monthlyFee': monthlyFee,
      if (effectiveFrom != null)
        'effectiveFrom': effectiveFrom.toIso8601String().split('T')[0],
      if (effectiveTo != null)
        'effectiveTo': effectiveTo.toIso8601String().split('T')[0],
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return FeeStructure.fromJson(json.decode(response.body));
    } else {
      throw Exception(
          'Failed to create fee: ${response.statusCode} - ${response.body}');
    }
  } // GET effective fee for a group (returns FeeStructure)

  static Future<FeeStructure?> fetchEffectiveFee(int groupId,
      {DateTime? onDate}) async {
    final dateParam = (onDate != null)
        ? '?date=${onDate.toIso8601String().split('T')[0]}'
        : '';
    final url =
    Uri.parse('$baseUrl/api/fees/group/$groupId/effective$dateParam');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return FeeStructure.fromJson(json.decode(response.body));
    } else if (response.statusCode == 204) {
      return null;
    } else {
      throw Exception(
          'Failed to fetch effective fee: ${response.statusCode} - ${response.body}');
    }
  }

  // record a payment
  static Future<void> recordPayment({
    required int installmentId,
    required double amount,
    String? paymentMethod,
    String? reference,
  }) async {
    final url = Uri.parse('$baseUrl/api/payments');
    final body = {
      'installmentId': installmentId,
      'amount': amount,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (reference != null) 'reference': reference,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to record payment: ${response.statusCode} - ${response.body}');
    }
  }

// fetch payments for an installment
  static Future<List<Payment>> fetchPaymentsByInstallment(
      int installmentId) async {
    final url = Uri.parse('$baseUrl/api/payments/installment/$installmentId');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
          'Failed to load payments: ${response.statusCode} - ${response.body}');
    }
  }

// add method
  static Future<List<InstallmentStatus>> fetchInstallmentStatus({
    int? month,
    int? year,
  }) async {
    // pass optional query params only if provided
    final query = <String, String>{};
    if (month != null) query['month'] = month.toString();
    if (year != null) query['year'] = year.toString();

    final uri = Uri.parse('$baseUrl/api/players/installment-status')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => InstallmentStatus.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception(
          'Failed to load installment status: ${response.statusCode} ${response.body}');
    }
  }

  // ---------------- Installment Summary (all players for month YYYY-MM) ----------------
  static Future<List<PlayerInstallmentSummary>> fetchInstallmentSummary(
      String yearMonth) async {
    // UPDATE: Now points to the correct endpoint in InstallmentController
    final url = Uri.parse(
        '$baseUrl/api/installments/summary?month=$yearMonth');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) =>
          PlayerInstallmentSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load installment summary: ${response.statusCode} - ${response.body}');
    }
  }

  // Create single installment for a player (optional endpoint on your backend)
  static Future<void> createInstallmentForPlayer({
    required int playerId,
    required int periodMonth,
    required int periodYear,
    required DateTime dueDate,
    required double amount,
  }) async {
    final url = Uri.parse('$baseUrl/api/installments');
    final body = {
      'playerId': playerId,
      'periodMonth': periodMonth,
      'periodYear': periodYear,
      'dueDate': dueDate.toIso8601String().split('T')[0],
      'amount': amount,
    };
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to create installment: ${response.statusCode} - ${response.body}');
    }
  }
  // // --- OPTIMIZED FETCH ---
  // static Future<List<PlayerInstallmentSummary>> fetchAllInstallmentsSummary({int page = 0, int size = 2000}) async {
  //   final url = Uri.parse('$baseUrl/api/installments/all-summary?page=$page&size=$size');
  //   final response = await http.get(url);
  //
  //   if (response.statusCode == 200) {
  //     // Pass the raw string to background thread
  //     return compute(_parseInstallmentsResponse, response.body);
  //   } else {
  //     throw Exception('Failed to load installments: ${response.statusCode}');
  //   }

// ApiService.dart मध्ये
  static Future<List<PlayerInstallmentSummary>> fetchAllInstallmentsSummary({int page = 0, int size = 2000}) async {
    final url = Uri.parse('$baseUrl/api/installments/all-summary?page=$page&size=$size');
    final response = await http.get(url);

    // Debug print
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      print("📊 Sample item from API:");
      if (jsonData['content'] != null && jsonData['content'].length > 0) {
        final sample = jsonData['content'][0];
        print("Player: ${sample['playerName']}");
        print("Status: ${sample['status']}");
        print("Last Payment Date: ${sample['lastPaymentDate']}");
        print("Due Date: ${sample['dueDate']}");
        print("Total Paid: ${sample['totalPaid']}");
      }
    }

    if (response.statusCode == 200) {
      return compute(_parseInstallmentsResponse, response.body);
    } else {
      throw Exception('Failed to load installments: ${response.statusCode}');
    }
  }

  static Future<void> pausePlayer(int playerId, DateTime date, String reason) async {
    final dateStr = date.toIso8601String().split('T')[0];
    // URL: /api/player-lifecycle/{id}/pause?date=...&reason=...
    final url = Uri.parse('$baseUrl/api/player-lifecycle/$playerId/pause?date=$dateStr&reason=$reason');

    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to pause player: ${response.body}');
    }
  }

  // ▶️ ACTIVATE PLAYER (Return)
  static Future<void> activatePlayer(int playerId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    // URL: /api/player-lifecycle/{id}/activate?date=...
    final url = Uri.parse('$baseUrl/api/player-lifecycle/$playerId/activate?date=$dateStr');

    final response = await http.post(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to activate player: ${response.body}');
    }
  }
  // Standalone parser
  static List<PlayerInstallmentSummary> _parseInstallmentsResponse(String responseBody) {
    final dynamic decoded = json.decode(responseBody);
    List<dynamic> data;

    if (decoded is Map<String, dynamic> && decoded.containsKey('content')) {
      data = decoded['content'];
    } else if (decoded is List) {
      data = decoded;
    } else {
      data = [];
    }

    return data
        .map((e) => PlayerInstallmentSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  // ApiService: add method
  static Future<Map<String, dynamic>> fetchLatestInstallmentMonth() async {
    final url = Uri.parse('$baseUrl/api/installments/latest-month');
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      return json.decode(resp.body) as Map<String, dynamic>;
    } else {
      throw Exception(
          'Failed to fetch latest month: ${resp.statusCode} - ${resp.body}');
    }
  }
  // ADD THESE METHODS TO YOUR EXISTING ApiService class

  static Future<List<FeeStructure>> fetchAllFees() async {
    try {
      // Since your backend doesn't have a "get all fees" endpoint,
      // we'll fetch fees for each group individually
      final groups = await fetchGroups();
      final allFees = <FeeStructure>[];

      for (final group in groups) {
        try {
          final fees = await fetchFeesByGroup(group.id);
          allFees.addAll(fees);
        } catch (e) {
          debugPrint('Error fetching fees for group ${group.id}: $e');
        }
      }

      return allFees;
    } catch (e) {
      throw Exception('Failed to load fees: $e');
    }
  }
  static Future<void> extendInstallmentDate({
    required int installmentId,
    required DateTime newDate,
  }) async {
    final url = Uri.parse('$baseUrl/api/installments/extend-due-date');
    final body = {
      'installmentId': installmentId,
      'newDueDate': newDate.toIso8601String().split('T')[0], // "2025-12-25"
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to extend date: ${response.body}');
    }
  }
  static Future<List<PlayerInstallmentSummary>> fetchOverdueSummary() async {
    final url = Uri.parse('$baseUrl/api/installments/overdue-summary');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .map((e) => PlayerInstallmentSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load overdue summary: ${response.statusCode} - ${response.body}');
    }
  }
  static Future<void> payOverdue({
    required int playerId,
    required double amount,
    String? paymentMethod,
    String? reference,
  }) async {
    final url = Uri.parse('$baseUrl/api/payments/pay-overdue');

    // Body madhye passed values wapra
    final body = {
      'playerId': playerId,
      'amount': amount,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (reference != null) 'reference': reference,
    };

    print('📤 PAY OVERDUE REQUEST:');
    print('Body: $body');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to record overdue payment: ${response.body}');
      }
      print('✅ PAY OVERDUE SUCCESS!');
    } catch (e) {
      print('❌ ERROR: $e');
      rethrow;
    }
  }

  static Future<void> updatePlayer(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/players/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update player: ${response.body}');
    }
  }
  static Future<void> payUnpaid({
    required int playerId,
    required double amount,
    String? paymentMethod, // Ha parameter add kela
    String? reference,     // Ha parameter add kela
  }) async {
    final url = Uri.parse('$baseUrl/api/payments/pay-unpaid');

    // Body madhye passed values wapra
    final body = {
      'playerId': playerId,
      'amount': amount,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (reference != null) 'reference': reference,
    };

    print('📤 PAY UNPAID REQUEST:');
    print('Body: $body');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to record payment: ${response.body}');
      }
      print('✅ PAY UNPAID SUCCESS!');
    } catch (e) {
      print('❌ ERROR: $e');
      rethrow;
    }
  }

  // Add this inside ApiService class
  static Future<void> deleteFeeStructure(int id) async {
    final url = Uri.parse('$baseUrl/api/fees/$id');
    final response = await http.delete(url);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete fee: ${response.body}');
    }
  }
  // Add this inside ApiService class
  static Future<void> updateFeeStructure(int id, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/fees/$id');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update fee: ${response.body}');
    }
  }
  // --- BULK EXTEND API ---
  static Future<String> bulkExtendForHolidays({
    required DateTime holidayStart,
    required DateTime holidayEnd,
    int? groupId,
  }) async {
    final url = Uri.parse('$baseUrl/api/installments/extend-for-holidays');
    final body = {
      'holidayStart': holidayStart.toIso8601String().split('T')[0],
      'holidayEnd': holidayEnd.toIso8601String().split('T')[0],
      'groupId': groupId, // null for ALL groups
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return response.body; // Success Message from Backend
    } else {
      throw Exception('Failed to extend dates: ${response.body}');
    }
  }
}