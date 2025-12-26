// lib/screens/universal_list_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/data_manager.dart';
import '../../utils/event_bus.dart';
import '../../widgets/PlayerSummaryCard.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
    _eventSubscription = EventBus().stream.listen((event) {
      if (['updated', 'installment_created', 'payment_recorded', 'added'].contains(event.action)) {
        debugPrint("🔄 Auto-refreshing Universal List due to event: ${event.action}");
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final allInstallments = await DataManager().getAllInstallments(forceRefresh: true);
      final allPlayers = await DataManager().getPlayers();
      final playerMap = {for (var p in allPlayers) p.id: p};

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 🔥 CRITICAL CHANGE: Group by Player ID
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

        // 🔥 Filter: Find matching installments based on filter type
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
                (inst.remaining ?? 0) > 0) {
              include = true;
            }
          }
          else if (widget.filterType == 'MONTHLY' && widget.targetMonth != null) {
            final parts = widget.targetMonth!.split('-');
            if (dueDate.year == int.parse(parts[0]) &&
                dueDate.month == int.parse(parts[1]) &&
                status != 'SKIPPED' &&
                status != 'CANCELLED') {
              include = true;
            }
          }
          else if (widget.filterType == 'HOLIDAY') {
            if (status == 'SKIPPED' || status == 'CANCELLED') {
              include = true;
            }
          }

          if (include) {
            matchingInstallments.add(inst);
          }
        }

        // 🔥 Only add player if they have matching installments
        if (matchingInstallments.isNotEmpty) {
          // Get the MOST RECENT matching installment
          matchingInstallments.sort((a, b) => (b.dueDate ?? DateTime(2000))
              .compareTo(a.dueDate ?? DateTime(2000)));

          final primaryInstallment = matchingInstallments.first;

          // Get chips: all unpaid installments for this player
          final unpaidInstallments = playerInstallments.where((inst) {
            final status = (inst.status ?? '').toUpperCase();
            return status != 'PAID' &&
                status != 'SKIPPED' &&
                status != 'CANCELLED' &&
                (inst.remaining ?? 0) > 0;
          }).toList()
            ..sort((a, b) => (a.dueDate ?? DateTime(2000))
                .compareTo(b.dueDate ?? DateTime(2000)));

          result.add({
            'player': player,
            'summary': primaryInstallment,
            'installments': unpaidInstallments.take(4).toList(), // Max 4 chips
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
      debugPrint("Error: $e");
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
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
            Text(widget.title, style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18
            )),
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
                  end: Alignment.bottomRight
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
                        color: Colors.white.withOpacity(0.2)
                    ),
                    const SizedBox(height: 16),
                    const Text(
                        "No records found",
                        style: TextStyle(color: Colors.white54)
                    ),
                  ],
                )
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