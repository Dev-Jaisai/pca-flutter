import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/data_manager.dart';
import '../../utils/event_bus.dart';
import '../../widgets/PlayerSummaryCard.dart';
import '../../widgets/FinancialSummaryCard.dart';
import '../home/edit_player_screen.dart'; // Correct path for your edit screen

class UniversalListScreen extends StatefulWidget {
  final String title;
  final String filterType; // 'OVERDUE', 'MONTHLY', 'UPCOMING', 'HOLIDAY'
  final String? targetMonth; // '2025-12' (Optional)

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

  // Stats Variables
  double _totalTarget = 0;
  double _totalCollected = 0;
  double _totalRemaining = 0;

  @override
  void initState() {
    super.initState();
    _initialLoad();

    _eventSubscription = EventBus().stream.listen((event) {
      if (['updated', 'installment_created', 'payment_recorded', 'added'].contains(event.action)) {
        debugPrint("🔄 Auto-refreshing Universal List: ${event.action}");
        DataManager().clearCache();
        _loadData(forceRefresh: true, showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    await _loadData(forceRefresh: false, showLoading: true);
    await _loadData(forceRefresh: true, showLoading: false);
  }

  Future<void> _loadData({required bool forceRefresh, bool showLoading = false}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() {
        _loading = true;
        _displayList = [];
        _error = null;
      });
    }

    try {
      final allInstallments = await DataManager().getAllInstallments(forceRefresh: forceRefresh);

      if (!forceRefresh && allInstallments.isEmpty) return;

      final allPlayers = await DataManager().getPlayers(forceRefresh: forceRefresh);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

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

          if (widget.filterType == 'OVERDUE') {
            if (dueDate.isBefore(today) &&
                status != 'PAID' &&
                status != 'SKIPPED' &&
                status != 'CANCELLED' &&
                status != 'REFUNDED' &&
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
            include = true;
          }

          if (include) {
            matchingInstallments.add(inst);
          }
        }

        if (matchingInstallments.isNotEmpty) {
          // Sort by date descending
          matchingInstallments.sort((a, b) => (b.dueDate ?? DateTime(2000))
              .compareTo(a.dueDate ?? DateTime(2000)));

          final primaryInstallment = matchingInstallments.first;

          final chipsList = playerInstallments.where((inst) {
            if (inst.dueDate == null) return false;
            final diff = inst.dueDate!.difference(now).inDays;
            return diff > -60;
          }).toList()
            ..sort((a, b) => (a.dueDate!).compareTo(b.dueDate!));

          result.add({
            'player': player,
            'summary': primaryInstallment,
            'installments': chipsList.take(4).toList(),
          });
        }
      }

      // 🔥🔥🔥 CALCULATE SUMMARY TOTALS (Updated Logic) 🔥🔥🔥
      double tTarget = 0;
      double tCollected = 0;
      double tPending = 0;

      for (var item in result) {
        final summary = item['summary'] as PlayerInstallmentSummary;

        final status = (summary.status ?? '').toUpperCase();

        // 🔥 FIX: Ignore SKIPPED, CANCELLED, and REFUNDED from Financial Stats
        if (status != 'SKIPPED' && status != 'CANCELLED' && status != 'REFUNDED') {
          tTarget += (summary.installmentAmount ?? 0);
          tCollected += (summary.totalPaid);
          tPending += (summary.remaining ?? 0);
        }
      }

      if (mounted) {
        setState(() {
          _displayList = result;
          _totalTarget = tTarget;
          _totalCollected = tCollected;
          _totalRemaining = tPending;

          _loading = false;
        });
      }

    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
            Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            if (!_loading && _displayList.isNotEmpty)
              Text("${_displayList.length} Players", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                DataManager().clearCache();
                _loadData(forceRefresh: true, showLoading: true);
              }
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF2C5364)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),

          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _displayList.isEmpty
                ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 60, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text("No records found", style: TextStyle(color: Colors.white54)),
                  ],
                )
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
              itemCount: _displayList.length + 1,
              itemBuilder: (ctx, i) {

                if (i == 0) {
                  return FinancialSummaryCard(
                    title: "Total Summary",
                    totalTarget: _totalTarget,
                    totalCollected: _totalCollected,
                    totalPending: _totalRemaining,
                    countLabel: "${_displayList.length} Players",
                  );
                }

                final item = _displayList[i - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditPlayerScreen(player: item['player']))
                      );
                      DataManager().clearCache();
                      _loadData(forceRefresh: true, showLoading: true);
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
          )
        ],
      ),
    );
  }
}