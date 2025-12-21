import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../widgets/FinancialSummaryCard.dart';
import '../../widgets/PlayerSummaryCard.dart';

class OverduePlayersScreen extends StatefulWidget {
  const OverduePlayersScreen({super.key});

  @override
  State<OverduePlayersScreen> createState() => _OverduePlayersScreenState();
}

class _OverduePlayersScreenState extends State<OverduePlayersScreen> {
  List<PlayerInstallmentSummary> _allItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cached = await DataManager().getCachedAllInstallments();
    if (cached != null && cached.isNotEmpty) {
      if (mounted) setState(() { _allItems = cached; _isLoading = false; });
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final list = await ApiService.fetchAllInstallmentsSummary(page: 0, size: 5000);
      await DataManager().saveAllInstallments(list);
      if (mounted) setState(() { _allItems = list; _isLoading = false; _error = null; });
    } catch (e) {
      if (mounted && _allItems.isEmpty) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  // --- 1. LIST LOGIC (Only Pending Items) ---
  List<Map<String, dynamic>> _getOverdueGroups() {
    final Map<int, List<PlayerInstallmentSummary>> grouped = {};
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var item in _allItems) {
      if (item.playerId == null) continue;

      // Condition: Past Date AND Not Paid
      final bool isPastDue = item.dueDate != null && item.dueDate!.isBefore(startOfToday);
      final bool isNotPaid = (item.status ?? '').toUpperCase() != 'PAID';

      if (isPastDue && isNotPaid) {
        if (!grouped.containsKey(item.playerId)) {
          grouped[item.playerId!] = [];
        }
        grouped[item.playerId!]!.add(item);
      }
    }

    List<Map<String, dynamic>> result = [];
    grouped.forEach((pid, installments) {
      final first = installments.first;

      double totalOverdue = 0;
      double totalPaidSoFar = 0;
      double totalRemaining = 0;

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
        ),
        'summary': PlayerInstallmentSummary(
          playerId: pid,
          playerName: first.playerName,
          totalPaid: totalPaidSoFar,
          installmentAmount: totalOverdue,
          remaining: totalRemaining,
          status: 'PENDING',
        ),
        'installments': installments
      });
    });

    result.sort((a, b) {
      final remA = (a['summary'] as PlayerInstallmentSummary).remaining ?? 0;
      final remB = (b['summary'] as PlayerInstallmentSummary).remaining ?? 0;
      return remB.compareTo(remA);
    });

    return result;
  }

  // --- 2. HEADER LOGIC (All History Stats) ---
  Map<String, double> _calculateGlobalOverdueStats() {
    double totalTarget = 0;
    double totalCollected = 0;
    double totalPending = 0;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var item in _allItems) {
      if (item.dueDate != null && item.dueDate!.isBefore(startOfToday)) {
        totalTarget += (item.installmentAmount ?? 0);
        totalCollected += item.totalPaid;
        totalPending += (item.remaining ?? 0);
      }
    }
    return {'target': totalTarget, 'collected': totalCollected, 'pending': totalPending};
  }

  @override
  Widget build(BuildContext context) {
    final overdueList = _getOverdueGroups();
    final stats = _calculateGlobalOverdueStats();

    return Scaffold(
      extendBodyBehindAppBar: true, // Needed for gradient background
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
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadData),
        ],
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT (Deep Space)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027), // Deep Black-Blue
                  Color(0xFF203A43), // Slate
                  Color(0xFF2C5364), // Teal-Dark
                ],
              ),
            ),
          ),

          // 2. GLOWING ORBS (Visual Effects)
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
              onRefresh: _loadData,
              color: Colors.cyanAccent,
              backgroundColor: const Color(0xFF203A43),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 10, bottom: 80),
                itemCount: overdueList.length + 1,
                itemBuilder: (ctx, i) {
                  // 1. Show Header (Global Stats)
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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