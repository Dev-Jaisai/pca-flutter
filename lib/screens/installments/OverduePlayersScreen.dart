import 'dart:async'; // 🔥 Required for Subscription
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../widgets/FinancialSummaryCard.dart';
import '../../widgets/PlayerSummaryCard.dart';
import '../../utils/event_bus.dart';

class OverduePlayersScreen extends StatefulWidget {
  const OverduePlayersScreen({super.key});

  @override
  State<OverduePlayersScreen> createState() => _OverduePlayersScreenState();
}

class _OverduePlayersScreenState extends State<OverduePlayersScreen> {
  List<PlayerInstallmentSummary> _allItems = [];
  bool _isLoading = true;
  String? _error;

  // 🔥 1. Subscription Variable
  late StreamSubscription<PlayerEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    // 🔥 Cache First Strategy
    _initialLoad();

    // 🔥 Live Listener
    _eventSubscription = EventBus().stream.listen((event) {
      if (['updated', 'payment_recorded', 'installment_created'].contains(event.action)) {
        debugPrint("🔄 Auto-refreshing Overdue List due to event: ${event.action}");
        _loadData(forceRefresh: true, showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }

  // 🔥 Helper: Cache First, Then Network
  Future<void> _initialLoad() async {
    // 1. Load from Cache (Instant)
    await _loadData(forceRefresh: false, showLoading: true);

    // 2. Fetch Fresh Data (Background)
    await _loadData(forceRefresh: true, showLoading: false);
  }

  Future<void> _loadData({required bool forceRefresh, bool showLoading = false}) async {
    if (!mounted) return;

    if (showLoading && _allItems.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // 🔥 DataManager handles caching logic
      final list = await DataManager().getAllInstallments(forceRefresh: forceRefresh);

      // If cache is empty and not forcing refresh, wait for next call
      if (!forceRefresh && list.isEmpty) return;

      if (mounted) {
        setState(() {
          _allItems = list;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && showLoading) {
        setState(() { _isLoading = false; _error = e.toString(); });
      }
    }
  }

  // --- 1. LIST LOGIC (Only Overdue Items) ---
  List<Map<String, dynamic>> _getOverdueGroups() {
    final Map<int, List<PlayerInstallmentSummary>> grouped = {};
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var item in _allItems) {
      if (item.playerId == null) continue;

      // Condition: Past Date AND Not Paid AND Not Skipped/Left
      final bool isPastDue = item.dueDate != null && item.dueDate!.isBefore(startOfToday);
      final String status = (item.status ?? '').toUpperCase();
      final String notes = (item.notes ?? '').toLowerCase();

      // Check for Left/Waived logic to exclude them from Overdue list if needed
      final bool isWaived = status == 'SKIPPED' && (notes.contains('left') || notes.contains('waived'));

      final bool isPending = status != 'PAID' && status != 'SKIPPED' && status != 'CANCELLED' && !isWaived;

      if (isPastDue && isPending) {
        if (!grouped.containsKey(item.playerId)) {
          grouped[item.playerId!] = [];
        }
        grouped[item.playerId!]!.add(item);
      }
    }

    List<Map<String, dynamic>> result = [];
    grouped.forEach((pid, installments) {
      if (installments.isEmpty) return;

      final first = installments.first;

      double totalOverdue = 0;
      double totalPaidSoFar = 0;
      double totalRemaining = 0;

      // Sort installments (Latest First)
      installments.sort((a, b) {
        DateTime dateA = a.dueDate ?? DateTime(2000);
        DateTime dateB = b.dueDate ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      for (var inst in installments) {
        totalOverdue += (inst.installmentAmount ?? 0);
        totalPaidSoFar += (inst.totalPaid);
        totalRemaining += (inst.remaining ?? 0);
      }

      result.add({
        'player': Player(
          id: pid,
          name: first.playerName,
          group: first.groupName ?? '',
          phone: first.phone ?? '',
          billingDay: 1, // Defaulting to 1 if not available
        ),
        'summary': PlayerInstallmentSummary(
          playerId: pid,
          playerName: first.playerName,
          totalPaid: totalPaidSoFar,
          installmentAmount: totalOverdue,
          remaining: totalRemaining,
          status: 'PENDING', // Force Pending for visual consistency in list
          dueDate: installments.first.dueDate, // Latest overdue date
          installmentId: installments.first.installmentId,
          notes: installments.first.notes,
        ),
        'installments': installments
      });
    });

    // Sort by Highest Remaining Amount
    result.sort((a, b) {
      final remA = (a['summary'] as PlayerInstallmentSummary).remaining ?? 0;
      final remB = (b['summary'] as PlayerInstallmentSummary).remaining ?? 0;
      return remB.compareTo(remA);
    });

    return result;
  }

  // --- 2. HEADER LOGIC (Global Stats) ---
  Map<String, double> _calculateGlobalOverdueStats() {
    double totalTarget = 0;
    double totalCollected = 0;
    double totalPending = 0;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var item in _allItems) {
      final status = (item.status ?? '').toUpperCase();
      final String notes = (item.notes ?? '').toLowerCase();
      final bool isWaived = status == 'SKIPPED' && (notes.contains('left') || notes.contains('waived'));

      if (item.dueDate != null && item.dueDate!.isBefore(startOfToday) &&
          status != 'SKIPPED' && status != 'CANCELLED' && !isWaived) {

        totalTarget += (item.installmentAmount ?? 0);
        totalCollected += item.totalPaid;

        if (status != 'PAID') {
          totalPending += (item.remaining ?? 0);
        }
      }
    }
    return {'target': totalTarget, 'collected': totalCollected, 'pending': totalPending};
  }

  @override
  Widget build(BuildContext context) {
    final overdueList = _getOverdueGroups();
    final stats = _calculateGlobalOverdueStats();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Overdue Players (${overdueList.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _loadData(forceRefresh: true, showLoading: true)
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),

          // 2. GLOWING ORBS
          Positioned(
            top: -50, right: -50,
            child: Container(
              height: 200, width: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 100, spreadRadius: 50)]),
            ),
          ),
          Positioned(
            bottom: 100, left: -50,
            child: Container(
              height: 200, width: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.2), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 100, spreadRadius: 50)]),
            ),
          ),

          // 3. MAIN CONTENT
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : overdueList.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text("No Overdue Players!", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Everything looks clean.", style: TextStyle(color: Colors.white.withOpacity(0.4))),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: () => _loadData(forceRefresh: true, showLoading: true),
              color: Colors.cyanAccent,
              backgroundColor: const Color(0xFF203A43),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 10, bottom: 80),
                itemCount: overdueList.length + 1,
                itemBuilder: (ctx, i) {
                  // 1. Show Header
                  if (i == 0) {
                    return FinancialSummaryCard(
                      title: "Total Past Dues",
                      totalTarget: stats['target']!,
                      totalCollected: stats['collected']!,
                      totalPending: stats['pending']!,
                      countLabel: "${overdueList.length} Active",
                    );
                  }

                  // 2. Show List Items
                  final data = overdueList[i - 1];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PlayerSummaryCard(
                      player: data['player'] as Player,
                      summary: data['summary'] as PlayerInstallmentSummary,
                      installments: data['installments'] as List<PlayerInstallmentSummary>,
                      nextScreenFilter: 'Overdue',
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