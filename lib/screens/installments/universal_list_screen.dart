import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/data_manager.dart';
import '../../utils/event_bus.dart';
import '../../widgets/PlayerSummaryCard.dart';
import '../home/edit_player_screen.dart';

class UniversalListScreen extends StatefulWidget {
  final String title;
  final String filterType;
  final String? targetMonth;

  const UniversalListScreen({
    super.key,
    required this.title,
    required this.filterType,
    this.targetMonth,
  });

  @override
  State<UniversalListScreen> createState() => _UniversalListScreenState();
}

class _UniversalListScreenState extends State<UniversalListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _displayList = [];
  String? _error;
  late StreamSubscription<PlayerEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initialLoad();

    _eventSubscription = EventBus().stream.listen((event) {
      if (['updated', 'installment_created', 'payment_recorded', 'added'].contains(event.action)) {
        debugPrint("🔄 Auto-refreshing Universal List: ${event.action}");

        // 🔥 Clear cache first, then reload
        DataManager().clearCache();
        _loadData(forceRefresh: true, showLoading: true);
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    // First load from cache (fast)
    await _loadData(forceRefresh: false, showLoading: true);
    // Then load fresh data (background)
    await _loadData(forceRefresh: true, showLoading: false);
  }

  Future<void> _loadData({required bool forceRefresh, bool showLoading = false}) async {
    if (!mounted) return;

    // 🔥 CRITICAL: Show loader and clear old data immediately
    if (showLoading) {
      setState(() {
        _loading = true;
        _displayList = []; // Clear old data to avoid stale UI
        _error = null;
      });
    }

    try {
      // 🔥 Get fresh data from API if forceRefresh is true
      final allInstallments = await DataManager().getAllInstallments(forceRefresh: forceRefresh);

      // Skip if cache was empty and not forcing refresh
      if (!forceRefresh && allInstallments.isEmpty) return;

      final allPlayers = await DataManager().getPlayers(forceRefresh: forceRefresh);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Group installments by player
      final Map<int, List<PlayerInstallmentSummary>> playerInstallmentsMap = {};

      for (var inst in allInstallments) {
        if (inst.playerId == null) continue;
        playerInstallmentsMap.putIfAbsent(inst.playerId!, () => []).add(inst);
      }

      final List<Map<String, dynamic>> result = [];

      for (final player in allPlayers) {
        final playerId = player.id;
        final playerInstallments = playerInstallmentsMap[playerId] ?? [];

        List<PlayerInstallmentSummary> matchingInstallments = [];

        for (var inst in playerInstallments) {
          final status = (inst.status ?? '').toUpperCase();
          final dueDate = inst.dueDate ?? DateTime(2000);
          bool include = false;

          // Apply filters based on screen type
          if (widget.filterType == 'OVERDUE') {
            if (dueDate.isBefore(today) &&
                status != 'PAID' &&
                status != 'SKIPPED' &&
                status != 'CANCELLED' &&
                (inst.remaining ?? 0) > 0) {
              include = true;
            }
          }
          else if (widget.filterType == 'MONTHLY' && widget.targetMonth != null) {
            final parts = widget.targetMonth!.split('-');
            if (dueDate.year == int.parse(parts[0]) &&
                dueDate.month == int.parse(parts[1])) {
              include = true;
            }
          }
          else if (widget.filterType == 'HOLIDAY') {
            if (status == 'SKIPPED' || status == 'CANCELLED') {
              include = true;
            }
          }
          else {
            // Show all installments
            include = true;
          }

          if (include) {
            matchingInstallments.add(inst);
          }
        }

        if (matchingInstallments.isNotEmpty) {
          // Sort: Latest first
          matchingInstallments.sort((a, b) => (b.dueDate ?? DateTime(2000))
              .compareTo(a.dueDate ?? DateTime(2000)));

          final primaryInstallment = matchingInstallments.first;

          // 🔥 Chips Logic: Recent + Future (Last 60 days to future)
          final chipsList = playerInstallments.where((inst) {
            if (inst.dueDate == null) return false;
            final diff = inst.dueDate!.difference(now).inDays;
            return diff > -60; // Show installments from last 60 days onwards
          }).toList()
            ..sort((a, b) => (a.dueDate!).compareTo(b.dueDate!));

          result.add({
            'player': player,
            'summary': primaryInstallment,
            'installments': chipsList.take(4).toList(), // Show max 4 chips
          });
        }
      }

      if (mounted) {
        setState(() {
          _displayList = result;
          _loading = false;
          _error = null;
        });
      }

    } catch (e) {
      debugPrint("❌ Error loading data: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            if (!_loading && _displayList.isNotEmpty)
              Text(
                "${_displayList.length} Players",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // 🔥 Manual refresh: Clear cache + reload
              DataManager().clearCache();
              _loadData(forceRefresh: true, showLoading: true);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: _loading
                ? const Center(
              child: CircularProgressIndicator(color: Colors.cyanAccent),
            )
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    "Error: $_error",
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      DataManager().clearCache();
                      _loadData(forceRefresh: true, showLoading: true);
                    },
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
                : _displayList.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No records found",
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: () async {
                DataManager().clearCache();
                await _loadData(forceRefresh: true, showLoading: true);
              },
              color: Colors.cyanAccent,
              backgroundColor: const Color(0xFF203A43),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _displayList.length,
                itemBuilder: (ctx, i) {
                  final item = _displayList[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () async {
                        // Navigate to edit screen
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditPlayerScreen(
                              player: item['player'],
                            ),
                          ),
                        );

                        // 🔥 Refresh IMMEDIATELY when returning
                        if (result == true || result == null) {
                          DataManager().clearCache();
                          _loadData(forceRefresh: true, showLoading: true);
                        }
                      },
                      child: PlayerSummaryCard(
                        player: item['player'] as Player,
                        summary: item['summary'] as PlayerInstallmentSummary,
                        installments: item['installments'] as List<PlayerInstallmentSummary>,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}