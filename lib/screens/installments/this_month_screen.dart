import 'package:flutter/material.dart';

import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/data_manager.dart';
import '../../widgets/PlayerSummaryCard.dart';


class ThisMonthScreen extends StatefulWidget {
  const ThisMonthScreen({super.key});

  @override
  State<ThisMonthScreen> createState() => _ThisMonthScreenState();
}

class _ThisMonthScreenState extends State<ThisMonthScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _displayList = [];

  @override
  void initState() {
    super.initState();
    _loadThisMonthData();
  }

  Future<void> _loadThisMonthData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final allInstallments = await DataManager().getAllInstallments(forceRefresh: true);
      final allPlayers = await DataManager().getPlayers();

      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      // Group installments by player
      final Map<int, List<PlayerInstallmentSummary>> playerInstallmentsMap = {};

      for (var inst in allInstallments) {
        if (inst.playerId == null) continue;

        final playerId = inst.playerId!;
        if (!playerInstallmentsMap.containsKey(playerId)) {
          playerInstallmentsMap[playerId] = [];
        }
        playerInstallmentsMap[playerId]!.add(inst);
      }

      final List<Map<String, dynamic>> result = [];

      for (final player in allPlayers) {
        final playerId = player.id;
        final playerInstallments = playerInstallmentsMap[playerId] ?? [];

        // Find installments for CURRENT MONTH ONLY
        final currentMonthInstallments = playerInstallments.where((inst) {
          final dueDate = inst.dueDate;
          if (dueDate == null) return false;

          final status = (inst.status ?? '').toUpperCase();

          // CURRENT MONTH च्या installments
          return dueDate.month == currentMonth &&
              dueDate.year == currentYear &&
              status != 'SKIPPED' &&
              status != 'CANCELLED';
          // 🔥 CHANGE: PAID asel tari dakhavu (status wise color change hounar)
        }).toList();

        if (currentMonthInstallments.isNotEmpty) {
          // Take the FIRST installment for this month
          final primaryInstallment = currentMonthInstallments.first;

          // 🔥 CHANGE: Get ONLY current month installments for chips
          final currentMonthChips = currentMonthInstallments
              .where((inst) => inst.dueDate != null)
              .toList()
            ..sort((a, b) => (a.dueDate!).compareTo(b.dueDate!));

          result.add({
            'player': player,
            'summary': primaryInstallment,
            'installments': currentMonthChips, // 🔥 फक्त current month चे chips
          });
        }
      }

      if (mounted) {
        setState(() {
          _displayList = result;
          _loading = false;
        });
      }

    } catch (e) {
      debugPrint("Error loading This Month data: $e");
      if (mounted) {
        setState(() {
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
            const Text(
              'This Month Due',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_displayList.isNotEmpty)
              Text(
                  "${_displayList.length} Players",
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12
                  )
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
                  Icon(
                    Icons.check_circle_outline,
                    size: 60,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No dues this month',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _displayList.length,
              itemBuilder: (ctx, i) {
                final item = _displayList[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PlayerSummaryCard(
                    player: item['player'] as Player,
                    summary: item['summary'] as PlayerInstallmentSummary,
                    installments: item['installments'] as List<PlayerInstallmentSummary>,
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