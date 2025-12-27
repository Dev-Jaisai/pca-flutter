import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/data_manager.dart';
import '../../widgets/PlayerSummaryCard.dart';
import '../../utils/event_bus.dart';
import '../home/edit_player_screen.dart';

class ThisMonthScreen extends StatefulWidget {
  const ThisMonthScreen({super.key});

  @override
  State<ThisMonthScreen> createState() => _ThisMonthScreenState();
}

class _ThisMonthScreenState extends State<ThisMonthScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _displayList = [];

  late StreamSubscription<PlayerEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initialLoad();

    // 🔥 FIX: Live Update Logic Improved
    _eventSubscription = EventBus().stream.listen((event) {
      if (['updated', 'payment_recorded', 'installment_created'].contains(event.action)) {
        debugPrint("🔄 Auto-refreshing Screen: ${event.action}");

        // ✅ CHANGE: Show Loading IMMEDIATELY (Don't show old data)
        _loadThisMonthData(forceRefresh: true, showLoading: true);
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    // 1. Show Cache immediately (Instant)
    await _loadThisMonthData(forceRefresh: false, showLoading: true);

    // 2. Fetch Fresh Data (Background)
    await _loadThisMonthData(forceRefresh: true, showLoading: false);
  }

  Future<void> _loadThisMonthData({required bool forceRefresh, bool showLoading = false}) async {
    if (!mounted) return;

    // ✅ FIX: Force Loading Indicator if requested (Even if data exists)
    if (showLoading) {
      setState(() => _loading = true);
    }

    try {
      // DataManager call
      final allInstallments = await DataManager().getAllInstallments(forceRefresh: forceRefresh);

      if (!forceRefresh && allInstallments.isEmpty) return;

      final allPlayers = await DataManager().getPlayers();

      // --- Processing Logic ---
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      final Map<int, List<PlayerInstallmentSummary>> playerInstallmentsMap = {};

      for (var inst in allInstallments) {
        if (inst.playerId == null) continue;
        playerInstallmentsMap.putIfAbsent(inst.playerId!, () => []).add(inst);
      }

      final List<Map<String, dynamic>> result = [];

      for (final player in allPlayers) {
        final playerId = player.id;
        final playerInstallments = playerInstallmentsMap[playerId] ?? [];

        // Current Month Installments
        final currentMonthInstallments = playerInstallments.where((inst) {
          final dueDate = inst.dueDate;
          if (dueDate == null) return false;
          final status = (inst.status ?? '').toUpperCase();

          return dueDate.month == currentMonth &&
              dueDate.year == currentYear &&
              status != 'SKIPPED' &&
              status != 'CANCELLED';
        }).toList();

        if (currentMonthInstallments.isNotEmpty) {
          final primaryInstallment = currentMonthInstallments.first;

          final currentMonthChips = currentMonthInstallments
              .where((inst) => inst.dueDate != null)
              .toList()
            ..sort((a, b) => (a.dueDate!).compareTo(b.dueDate!));

          result.add({
            'player': player,
            'summary': primaryInstallment,
            'installments': currentMonthChips,
          });
        }
      }

      if (mounted) {
        setState(() {
          _displayList = result;
          _loading = false; // ✅ Data loaded, hide spinner
        });
      }

    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) setState(() => _loading = false);
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
            if (!_loading && _displayList.isNotEmpty) // Hide count while loading
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _loadThisMonthData(forceRefresh: true, showLoading: true),
          )
        ],
      ),
      body: Stack(
        children: [
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
            // ✅ Loading Indicator (Visible during refresh)
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _displayList.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 60, color: Colors.white.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text('No dues this month', style: TextStyle(color: Colors.white54)),
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
                  child: GestureDetector(
                    // 🔥 CLICK ACTION: Go to Edit Player
                    onTap: () async {
                      // Navigate to Edit Screen
                      await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditPlayerScreen(player: item['player']))
                      );
                      // 🔥 Refresh when coming back (if user changed something)
                      _loadThisMonthData(forceRefresh: true, showLoading: true);
                    },
                    child: PlayerSummaryCard(
                      player: item['player'] as Player,
                      summary: item['summary'] as PlayerInstallmentSummary,
                      installments: item['installments'] as List<PlayerInstallmentSummary>,
                      nextScreenFilter: 'ThisMonth',
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