import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
// ✅ Note: Ensure these file names match your project (lowercase is standard)
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
  // ✅ FIX: This now calculates stats from ALL items, not just the filtered list
  Map<String, double> _calculateGlobalOverdueStats() {
    double totalTarget = 0;
    double totalCollected = 0;
    double totalPending = 0;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var item in _allItems) {
      // Logic: If the Due Date is in the past, include it in stats
      // (Even if it is fully PAID now, we want to show it in Collected)
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

    // ✅ Calculate Stats independently
    final stats = _calculateGlobalOverdueStats();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Overdue Players (${overdueList.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 0, bottom: 80),
          itemCount: overdueList.length + 1,
          itemBuilder: (ctx, i) {
            // 1. Show Header (Global Stats)
            if (i == 0) {
              return FinancialSummaryCard(
                title: "Total Past Dues", // Changed title to reflect data better
                totalTarget: stats['target']!,
                totalCollected: stats['collected']!,
                totalPending: stats['pending']!,
                countLabel: "${overdueList.length} Active", // Shows only currently pending count
              );
            }

            // 2. Show List Items (Active Overdue Only)
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
    );
  }
}