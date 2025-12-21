// lib/services/data_manager.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/fee_structure.dart';
import '../models/group.dart';
import '../models/player.dart';
import '../models/player_installment_summary.dart';
import 'api_service.dart'; // <--- Make sure to import this!
import '../models/installment.dart'; // ✅ Make sure to import Installment model
import '../models/payment.dart'; // ✅ Import Payment Model
class DataManager {
  // Singleton
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();
// RAM Cache
  List<Group>? _memGroups;
  List<FeeStructure>? _memFees;
  static const String _boxName = 'app_cache';
  late Box _box; // Marked as late, initialized in init()

  // RAM cache
  List<Player>? _memPlayers;
  Map<int, bool>? _memStatusMap;
  final Map<int, List<Installment>> _memPlayerDetails = {};
  // NEW: RAM cache for all-installments
  List<PlayerInstallmentSummary>? _memAllInstallments;
  // ✅ ADDED: The missing init() method

  // ✅ NEW: Cache for Payments List (Key: InstallmentId, Value: List of Payments)
  final Map<int, List<Payment>> _memPayments = {};
  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  ({List<Player>? players, Map<int, bool>? status}) getCachedData() {
    if (_memPlayers != null && _memPlayers!.isNotEmpty) {
      return (players: _memPlayers, status: _memStatusMap);
    }
    try {
      if (_box.containsKey('players_data')) {
        final playersJson = jsonDecode(_box.get('players_data') as String) as List<dynamic>;
        final players = playersJson.map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
        _memPlayers = players;

        // Load status if needed
        return (players: players, status: _memStatusMap);
      }
    } catch (e) {
      debugPrint('Cache error: $e');
    }
    return (players: null, status: null);
  }
// 1. GET GROUPS (Instant)
  Future<List<Group>> getGroups({bool forceRefresh = false}) async {
    if (!forceRefresh && _memGroups != null && _memGroups!.isNotEmpty) return _memGroups!;

    // Try Disk
    if (!forceRefresh && _box.containsKey('groups_data')) {
      // ... (Add disk logic if you want strict persistence, or rely on API fallback)
    }

    try {
      final data = await ApiService.fetchGroups();
      _memGroups = data;
      // Optional: Save to Hive _box.put(...)
      return data;
    } catch (e) {
      return _memGroups ?? [];
    }
  }

  // 2. GET FEES (Instant)
  Future<List<FeeStructure>> getFees({bool forceRefresh = false}) async {
    if (!forceRefresh && _memFees != null && _memFees!.isNotEmpty) return _memFees!;

    try {
      final data = await ApiService.fetchAllFees(); // Ensure ApiService has this method
      _memFees = data;
      return data;
    } catch (e) {
      return _memFees ?? [];
    }
  }

  // Clear cache to force refresh next time
  void invalidateFees() { _memFees = null; }
  void invalidateGroups() { _memGroups = null; }
  // ==========================================
  // ✅ NEW: Get Payments (Instant Cache)
  // ==========================================
  Future<List<Payment>> getPayments(int installmentId, {bool forceRefresh = false}) async {
    // 1. Return RAM if available
    if (!forceRefresh && _memPayments.containsKey(installmentId)) {
      return _memPayments[installmentId]!;
    }

    // 2. Fetch from API
    try {
      final data = await ApiService.fetchPaymentsByInstallment(installmentId);
      _memPayments[installmentId] = data; // Save to RAM
      return data;
    } catch (e) {
      debugPrint("Error fetching payments: $e");
      return _memPayments[installmentId] ?? [];
    }
  }

  // Call this when adding a new payment to clear old data
  void invalidatePayments(int installmentId) {
    _memPayments.remove(installmentId);
  }
// ✅ PRE-FETCH: Loads data in background
// ... inside DataManager class

  Future<void> prefetchAllData() async {
    try {
      debugPrint("🚀 DataManager: Starting pre-fetch...");

      // Fetch EVERYTHING in parallel
      final results = await Future.wait([
        ApiService.fetchPlayers(),
        ApiService.fetchAllInstallmentsSummary(page: 0, size: 5000),
        ApiService.fetchGroups(), // Add Groups
        ApiService.fetchAllFees(), // Add Fees
      ]);

      // Process and Cache
      final players = results[0] as List<Player>;
      final installments = results[1] as List<PlayerInstallmentSummary>;
      final groups = results[2] as List<Group>;
      final fees = results[3] as List<FeeStructure>;

      await saveData(players, []);
      await saveAllInstallments(installments);

      // Manually cache groups and fees to memory
      _memGroups = groups;
      _memFees = fees;

      debugPrint("🚀 DataManager: Pre-fetch complete. App is ready.");
    } catch (e) {
      debugPrint("⚠️ DataManager: Pre-fetch failed ($e). App will load data lazily.");
    }
  }
  // ==========================================
  // ✅ FIXED: Missing 'getPlayers' Method
  // ==========================================
  Future<List<Player>> getPlayers({bool forceRefresh = false}) async {
    // 1. Return RAM if available
    if (!forceRefresh && _memPlayers != null && _memPlayers!.isNotEmpty) {
      return _memPlayers!;
    }

    // 2. Return Disk if available
    if (!forceRefresh) {
      final cached = getCachedData();
      if (cached.players != null && cached.players!.isNotEmpty) {
        return cached.players!;
      }
    }

    // 3. Fetch from API
    try {
      final players = await ApiService.fetchPlayers();
      await saveData(players, []); // Save to cache
      return players;
    } catch (e) {
      debugPrint("Error fetching players: $e");
      // Fallback to cache even if forceRefresh was true
      return _memPlayers ?? [];
    }
  }
// ==========================================
  // ✅ NEW: Get Specific Player History (Fast)
  // ==========================================
  Future<List<Installment>> getInstallmentsForPlayer(int playerId, {bool forceRefresh = false}) async {
    // 1. Return RAM if available
    if (!forceRefresh && _memPlayerDetails.containsKey(playerId)) {
      return _memPlayerDetails[playerId]!;
    }

    // 2. Fetch from API
    try {
      final data = await ApiService.fetchInstallmentsByPlayer(playerId);
      _memPlayerDetails[playerId] = data; // Save to RAM
      return data;
    } catch (e) {
      debugPrint("Error fetching details for player $playerId: $e");
      // Return cached version if API fails
      return _memPlayerDetails[playerId] ?? [];
    }
  }

  // Clear specific player cache (call this after adding/editing installment)
  void invalidatePlayerDetails(int playerId) {
    _memPlayerDetails.remove(playerId);
  }
  // ==========================================
  // ✅ FIXED: Missing 'getAllInstallments' Method
  // ==========================================
  Future<List<PlayerInstallmentSummary>> getAllInstallments({bool forceRefresh = false}) async {
    // 1. Return RAM if available
    if (!forceRefresh && _memAllInstallments != null && _memAllInstallments!.isNotEmpty) {
      return _memAllInstallments!;
    }

    // 2. Return Disk if available
    if (!forceRefresh) {
      final cached = await getCachedAllInstallments();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    // 3. Fetch from API
    try {
      final items = await ApiService.fetchAllInstallmentsSummary(page: 0, size: 5000);
      await saveAllInstallments(items); // Save to cache
      return items;
    } catch (e) {
      debugPrint("Error fetching installments: $e");
      return _memAllInstallments ?? [];
    }
  }
  /// Save players and statuses to RAM + Hive (stores JSON strings)
  Future<void> saveData(List<Player> players, List<dynamic> statuses) async {
    // RAM
    _memPlayers = players;
    _memStatusMap = { for (final s in statuses) s.playerId as int : s.hasInstallments as bool };
    try {
      final playersJson = jsonEncode(players.map((p) => p.toJson()).toList());
      await _box.put('players_data', playersJson);
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }
  /// Remove a single player by id from RAM and Hive cache (good for delete)
  Future<void> removePlayer(int id) async {
    // RAM
    _memPlayers?.removeWhere((p) => p.id == id);
    _memStatusMap?.remove(id);

    // Disk: read existing JSON -> remove -> write back
    try {
      if (_box.containsKey('players_data')) {
        final playersJson = jsonDecode(_box.get('players_data') as String) as List<dynamic>;
        final updated = playersJson.where((e) {
          try {
            final map = e as Map<String, dynamic>;
            final pid = map['id'];
            return pid != id;
          } catch (_) {
            return true;
          }
        }).toList();
        await _box.put('players_data', jsonEncode(updated));
      }

      if (_box.containsKey('status_data')) {
        final statusJson = jsonDecode(_box.get('status_data') as String) as Map<String, dynamic>;
        statusJson.remove(id.toString());
        await _box.put('status_data', jsonEncode(statusJson));
      }
    } catch (e) {
      debugPrint('DataManager.removePlayer error: $e');
    }
  }

  /// Clear all cache (RAM + Disk)
  Future<void> clear() async {
    _memPlayers = null;
    _memStatusMap = null;
    _memAllInstallments = null;
    await _box.clear();
  }
  Future<List<PlayerInstallmentSummary>?> getCachedAllInstallments() async {
    if (_memAllInstallments != null && _memAllInstallments!.isNotEmpty) {
      return _memAllInstallments;
    }
    try {
      if (_box.containsKey('all_installments_cache')) {
        final jsonStr = _box.get('all_installments_cache') as String;
        final items = await compute(_parseCachedInstallments, jsonStr);
        _memAllInstallments = items;
        return items;
      }
    } catch (e) {
      debugPrint('Installment Cache error: $e');
    }
    return null;
  }
  static List<PlayerInstallmentSummary> _parseCachedInstallments(String jsonStr) {
    final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => PlayerInstallmentSummary.fromJson(e)).toList();
  }
  Future<void> saveAllInstallments(List<PlayerInstallmentSummary> items) async {
    _memAllInstallments = items;
    try {
      final jsonStr = await compute(_encodeInstallments, items);
      await _box.put('all_installments_cache', jsonStr);
    } catch (e) {
      debugPrint('Save Installments error: $e');
    }
  }
  static String _encodeInstallments(List<PlayerInstallmentSummary> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }

  // ==========================================
  // ✅ NEW: Clear All Cache (RAM + Disk)
  // ==========================================
  Future<void> clearAllCache() async {
    debugPrint("🧹 Clearing entire cache...");

    // 1. Clear RAM
    _memGroups = null;
    _memFees = null;
    _memPlayers = null;
    _memStatusMap = null;
    _memAllInstallments = null;

    // Clear Maps
    _memPlayerDetails.clear();
    _memPayments.clear();

    // 2. Clear Disk (Hive)
    await _box.clear();

    debugPrint("✨ Cache cleared successfully.");
  }
}
