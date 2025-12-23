import 'dart:convert';
import 'package:flutter/foundation.dart'; // For compute & debugPrint
import 'package:hive/hive.dart';

// --- MODELS ---
import '../models/fee_structure.dart';
import '../models/group.dart';
import '../models/player.dart';
import '../models/player_installment_summary.dart';
import '../models/installment.dart';
import '../models/payment.dart';

// --- SERVICES ---
import 'api_service.dart';

class DataManager {
  // Singleton Pattern
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  // --- HIVE CONFIG ---
  static const String _boxName = 'app_cache';
  late Box _box;

  // --- RAM CACHE (MEMORY) ---
  // 1. Core Data
  List<Group>? _memGroups;
  List<FeeStructure>? _memFees;
  List<Player>? _memPlayers;
  List<PlayerInstallmentSummary>? _memAllInstallments;
  Map<int, bool>? _memStatusMap;

  // 2. Drill-Down Data (History & Payments)
  // Key: PlayerId, Value: List of Installments
  final Map<int, List<Installment>> _memPlayerDetails = {};

  // Key: InstallmentId, Value: List of Payments
  final Map<int, List<Payment>> _memPayments = {};

  // ==========================================
  // 1. INITIALIZATION
  // ==========================================

  /// Call this in main.dart before running the app
  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
      debugPrint("✅ DataManager Initialized");
    } catch (e) {
      debugPrint("❌ DataManager Init Failed: $e");
    }
  }

  /// Loads heavy data in background when app starts
  Future<void> prefetchAllData() async {
    try {
      debugPrint("🚀 DataManager: Starting pre-fetch...");

      // Fetch EVERYTHING in parallel (Faster)
      final results = await Future.wait([
        ApiService.fetchPlayers(),
        ApiService.fetchAllInstallmentsSummary(page: 0, size: 5000),
        ApiService.fetchGroups(),
        ApiService.fetchAllFees(),
      ]);

      // Process and Cache
      final players = results[0] as List<Player>;
      final installments = results[1] as List<PlayerInstallmentSummary>;
      final groups = results[2] as List<Group>;
      final fees = results[3] as List<FeeStructure>;

      // Save to Disk & RAM
      await saveData(players, []);
      await saveAllInstallments(installments);

      _memGroups = groups;
      _memFees = fees;

      debugPrint("🚀 DataManager: Pre-fetch complete. App is ready.");
    } catch (e) {
      debugPrint("⚠️ DataManager: Pre-fetch failed ($e). App will load data lazily.");
    }
  }

  // ==========================================
  // 2. CORE DATA GETTERS (Players, Groups, Fees)
  // ==========================================

  /// Get Players (RAM -> Disk -> API)
  Future<List<Player>> getPlayers({bool forceRefresh = false}) async {
    // 1. RAM
    if (!forceRefresh && _memPlayers != null && _memPlayers!.isNotEmpty) {
      return _memPlayers!;
    }

    // 2. Disk (only if not forcing refresh)
    if (!forceRefresh) {
      final cached = getCachedData();
      if (cached.players != null && cached.players!.isNotEmpty) {
        _memPlayers = cached.players; // Restore RAM
        return cached.players!;
      }
    }

    // 3. API
    try {
      final players = await ApiService.fetchPlayers();
      await saveData(players, []); // Save to Cache
      return players;
    } catch (e) {
      debugPrint("Error fetching players: $e");
      return _memPlayers ?? [];
    }
  }

  /// Get Groups (RAM -> API)
  Future<List<Group>> getGroups({bool forceRefresh = false}) async {
    if (!forceRefresh && _memGroups != null && _memGroups!.isNotEmpty) {
      return _memGroups!;
    }
    try {
      final data = await ApiService.fetchGroups();
      _memGroups = data;
      return data;
    } catch (e) {
      return _memGroups ?? [];
    }
  }

  /// Get Fees (RAM -> API)
  Future<List<FeeStructure>> getFees({bool forceRefresh = false}) async {
    if (!forceRefresh && _memFees != null && _memFees!.isNotEmpty) {
      return _memFees!;
    }
    try {
      final data = await ApiService.fetchAllFees();
      _memFees = data;
      return data;
    } catch (e) {
      return _memFees ?? [];
    }
  }

  // ==========================================
  // 3. INSTALLMENT DATA (Summary & Detailed)
  // ==========================================

  /// Get All Installments Summary (Big List)
  Future<List<PlayerInstallmentSummary>> getAllInstallments({bool forceRefresh = false}) async {
    // 1. RAM
    if (!forceRefresh && _memAllInstallments != null && _memAllInstallments!.isNotEmpty) {
      return _memAllInstallments!;
    }

    // 2. Disk
    if (!forceRefresh) {
      final cached = await getCachedAllInstallments();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    // 3. API
    try {
      final items = await ApiService.fetchAllInstallmentsSummary(page: 0, size: 5000);
      await saveAllInstallments(items);
      return items;
    } catch (e) {
      debugPrint("Error fetching installments: $e");
      return _memAllInstallments ?? [];
    }
  }

  /// Get Specific Player History (Installments List)
  /// Used in InstallmentsScreen
  Future<List<Installment>> getInstallmentsForPlayer(int playerId, {bool forceRefresh = false}) async {
    // 1. RAM (Skip if forceRefresh is true)
    if (!forceRefresh && _memPlayerDetails.containsKey(playerId)) {
      return _memPlayerDetails[playerId]!;
    }

    // 2. API
    try {
      final data = await ApiService.fetchInstallmentsByPlayer(playerId);
      _memPlayerDetails[playerId] = data; // Update RAM
      return data;
    } catch (e) {
      debugPrint("Error fetching details for player $playerId: $e");
      return _memPlayerDetails[playerId] ?? [];
    }
  }

  /// Get Payments for an Installment
  Future<List<Payment>> getPayments(int installmentId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _memPayments.containsKey(installmentId)) {
      return _memPayments[installmentId]!;
    }

    try {
      final data = await ApiService.fetchPaymentsByInstallment(installmentId);
      _memPayments[installmentId] = data;
      return data;
    } catch (e) {
      debugPrint("Error fetching payments: $e");
      return _memPayments[installmentId] ?? [];
    }
  }

  // ==========================================
  // 4. CACHE INVALIDATION (Cleaning)
  // ==========================================

  /// Clear specific player cache (Call after Payment/Edit)
  void invalidatePlayerDetails(int playerId) {
    _memPlayerDetails.remove(playerId);
  }

  /// Clear payments cache for an installment
  void invalidatePayments(int installmentId) {
    _memPayments.remove(installmentId);
  }

  /// Clear config caches
  void invalidateFees() { _memFees = null; }
  void invalidateGroups() { _memGroups = null; }

  /// Remove a player completely (Delete logic)
  Future<void> removePlayer(int id) async {
    _memPlayers?.removeWhere((p) => p.id == id);
    _memStatusMap?.remove(id);
    _memPlayerDetails.remove(id);

    // Update Disk
    try {
      if (_box.containsKey('players_data')) {
        final playersJson = jsonDecode(_box.get('players_data') as String) as List<dynamic>;
        final updated = playersJson.where((e) {
          try {
            return e['id'] != id;
          } catch (_) { return true; }
        }).toList();
        await _box.put('players_data', jsonEncode(updated));
      }
    } catch (e) {
      debugPrint('DataManager.removePlayer error: $e');
    }
  }

  /// 🔥 Clear EVERYTHING (Logout / Reset)
  Future<void> clearAllCache() async {
    debugPrint("🧹 Clearing entire cache...");
    _memGroups = null;
    _memFees = null;
    _memPlayers = null;
    _memStatusMap = null;
    _memAllInstallments = null;
    _memPlayerDetails.clear();
    _memPayments.clear();

    await _box.clear();
    debugPrint("✨ Cache cleared successfully.");
  }

  // ==========================================
  // 5. INTERNAL HELPERS (Disk & Computation)
  // ==========================================

  /// Helper: Get Players from Disk
  ({List<Player>? players, Map<int, bool>? status}) getCachedData() {
    try {
      if (_memPlayers != null && _memPlayers!.isNotEmpty) {
        return (players: _memPlayers, status: _memStatusMap);
      }
      if (_box.containsKey('players_data')) {
        final playersJson = jsonDecode(_box.get('players_data') as String) as List<dynamic>;
        final players = playersJson.map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();
        _memPlayers = players;
        return (players: players, status: _memStatusMap);
      }
    } catch (e) {
      debugPrint('Cache error: $e');
    }
    return (players: null, status: null);
  }

  /// Helper: Save Players to Disk
  Future<void> saveData(List<Player> players, List<dynamic> statuses) async {
    _memPlayers = players;
    _memStatusMap = { for (final s in statuses) s.playerId as int : s.hasInstallments as bool };
    try {
      // Use compute for encoding if list is huge, otherwise simple encode is fine
      final playersJson = jsonEncode(players.map((p) => p.toJson()).toList());
      await _box.put('players_data', playersJson);
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  /// Helper: Get All Installments from Disk (Threaded)
  Future<List<PlayerInstallmentSummary>?> getCachedAllInstallments() async {
    if (_memAllInstallments != null && _memAllInstallments!.isNotEmpty) {
      return _memAllInstallments;
    }
    try {
      if (_box.containsKey('all_installments_cache')) {
        final jsonStr = _box.get('all_installments_cache') as String;
        // Run parsing in background thread
        final items = await compute(_parseCachedInstallments, jsonStr);
        _memAllInstallments = items;
        return items;
      }
    } catch (e) {
      debugPrint('Installment Cache error: $e');
    }
    return null;
  }

  /// Helper: Save All Installments to Disk (Threaded)
  Future<void> saveAllInstallments(List<PlayerInstallmentSummary> items) async {
    _memAllInstallments = items;
    try {
      // Run encoding in background thread
      final jsonStr = await compute(_encodeInstallments, items);
      await _box.put('all_installments_cache', jsonStr);
    } catch (e) {
      debugPrint('Save Installments error: $e');
    }
  }

  // Static functions for 'compute' (Isolates)
  static List<PlayerInstallmentSummary> _parseCachedInstallments(String jsonStr) {
    final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
    return list.map((e) => PlayerInstallmentSummary.fromJson(e)).toList();
  }

  static String _encodeInstallments(List<PlayerInstallmentSummary> items) {
    return jsonEncode(items.map((e) => e.toJson()).toList());
  }
}