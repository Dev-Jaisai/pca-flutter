// lib/services/data_manager.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/player.dart';
import '../models/player_installment_summary.dart';

class DataManager {
  // Singleton
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  static const String _boxName = 'app_cache';
  final Box _box = Hive.box(_boxName);

  // RAM cache
  List<Player>? _memPlayers;
  Map<int, bool>? _memStatusMap;

  // NEW: RAM cache for all-installments
  List<PlayerInstallmentSummary>? _memAllInstallments;

  /// Returns cached players/status if available (RAM -> Hive)
  ({List<Player>? players, Map<int, bool>? status}) getCachedData() {
    // 1) RAM
    if (_memPlayers != null && _memPlayers!.isNotEmpty) {
      return (players: _memPlayers, status: _memStatusMap);
    }

    // 2) Hive
    try {
      if (_box.containsKey('players_data')) {
        final playersJson = jsonDecode(_box.get('players_data') as String) as List<dynamic>;
        final players = playersJson.map((e) => Player.fromJson(e as Map<String, dynamic>)).toList();

        Map<int, bool> statusMap = {};
        if (_box.containsKey('status_data')) {
          final statusJson = jsonDecode(_box.get('status_data') as String) as Map<String, dynamic>;
          statusMap = statusJson.map((k, v) => MapEntry(int.parse(k), v as bool));
        }

        _memPlayers = players;
        _memStatusMap = statusMap;
        return (players: players, status: statusMap);
      }
    } catch (e) {
      // ignore and fallback to null (cache might be corrupt)
      debugPrint('DataManager.getCachedData error: $e');
    }

    // 3) nothing
    return (players: null, status: null);
  }

  /// Save players and statuses to RAM + Hive (stores JSON strings)
  Future<void> saveData(List<Player> players, List<dynamic> statuses) async {
    // RAM
    _memPlayers = players;
    _memStatusMap = { for (final s in statuses) s.playerId as int : s.hasInstallments as bool };

    // Disk (store JSON encoded)
    try {
      final playersJson = jsonEncode(players.map((p) => p.toJson()).toList());
      final statusMap = _memStatusMap ?? <int, bool>{};
      // convert keys to string for json
      final statusStringKeyMap = statusMap.map((k, v) => MapEntry(k.toString(), v));
      final statusJson = jsonEncode(statusStringKeyMap);

      await _box.put('players_data', playersJson);
      await _box.put('status_data', statusJson);
    } catch (e) {
      debugPrint('DataManager.saveData error: $e');
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

  // -----------------------------
  // NEW METHODS FOR ALL INSTALLMENTS
  // -----------------------------

  /// Returns cached All Installments if available (RAM -> Hive)
  List<PlayerInstallmentSummary>? getCachedAllInstallments() {
    // 1. Try RAM
    if (_memAllInstallments != null && _memAllInstallments!.isNotEmpty) {
      return _memAllInstallments;
    }

    // 2. Try Disk (Hive)
    try {
      if (_box.containsKey('all_installments_cache')) {
        final jsonStr = _box.get('all_installments_cache') as String;
        final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
        final items = list.map((e) {
          // ensure Map<String, dynamic>
          if (e is Map<String, dynamic>) {
            return PlayerInstallmentSummary.fromJson(e);
          } else if (e is Map) {
            return PlayerInstallmentSummary.fromJson(Map<String, dynamic>.from(e));
          } else {
            throw Exception('Invalid cached installment item');
          }
        }).toList();

        _memAllInstallments = items; // Update RAM
        return items;
      }
    } catch (e) {
      debugPrint('DataManager.getCachedAllInstallments error: $e');
    }

    return null;
  }

  /// Save all-installments to RAM + Hive (stores JSON strings)
  Future<void> saveAllInstallments(List<PlayerInstallmentSummary> items) async {
    _memAllInstallments = items; // Update RAM
    try {
      // Encode to JSON string
      final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
      await _box.put('all_installments_cache', jsonStr);
    } catch (e) {
      debugPrint('DataManager.saveAllInstallments error: $e');
    }
  }
}
