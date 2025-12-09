// lib/widgets/dashboard_stats.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/player_installment_summary.dart';
import '../services/api_service.dart';
import '../utils/event_bus.dart';

class DashboardStats extends StatefulWidget {
  const DashboardStats({super.key});

  @override
  DashboardStatsState createState() => DashboardStatsState();
}

class DashboardStatsState extends State<DashboardStats> {
  int _totalPlayers = 0;
  int _currentMonthDue = 0;
  int _pendingPayments = 0;
  int _overdue = 0;
  bool _loading = true;
  late StreamSubscription<PlayerEvent> _playerEventsSubscription;

  @override
  void initState() {
    super.initState();
    _loadStats();

    _playerEventsSubscription = EventBus().stream.listen((event) {
      if ([
        'added',
        'deleted',
        'updated',
        'installment_created',
        'installment_deleted',
        'payment_recorded'
      ].contains(event.action)) {
        debugPrint('DashboardStats: received ${event.action} -> refresh');
        _loadStats();
      }
    });
  }

  @override
  void dispose() {
    _playerEventsSubscription.cancel();
    super.dispose();
  }

  String _normalizeStatus(String? s) {
    if (s == null) return '';
    return s.toLowerCase().replaceAll('_', ' ').trim();
  }

  Future<String> _getTargetYearMonth() async {
    try {
      final latest = await ApiService.fetchLatestInstallmentMonth();
      if (latest != null && latest['year'] != null && latest['month'] != null) {
        final int year = latest['year'] as int;
        final int month = latest['month'] as int;
        final monthStr = '${year}-${month.toString().padLeft(2, '0')}';
        debugPrint('DashboardStats: latest month from API = $monthStr');
        return monthStr;
      }
    } catch (e) {
      debugPrint('DashboardStats: fetchLatestInstallmentMonth failed: $e');
    }

    final now = DateTime.now();
    final fallback = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    debugPrint('DashboardStats: using fallback month = $fallback');
    return fallback;
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loading = true);

    try {
      final targetMonth = await _getTargetYearMonth();

      // fetch summary rows
      List<PlayerInstallmentSummary> monthRows = <PlayerInstallmentSummary>[];
      try {
        monthRows = await ApiService.fetchInstallmentSummary(targetMonth);
      } catch (e) {
        debugPrint('DashboardStats: fetchInstallmentSummary failed: $e');
        monthRows = [];
      }

      // fetch players to calculate total players
      List<dynamic> playersRaw = <dynamic>[];
      try {
        playersRaw = await ApiService.fetchPlayers();
      } catch (e) {
        debugPrint('DashboardStats: fetchPlayers failed: $e');
        playersRaw = [];
      }

      debugPrint('DashboardStats: monthRows count=${monthRows.length} for $targetMonth');
      for (final r in monthRows) {
        debugPrint('ROW: pid=${r.playerId} name=${r.playerName} instId=${r.installmentId} status=${r.status} due=${r.dueDate} amt=${r.installmentAmount} paid=${r.totalPaid}');
      }

      // Group rows by playerId but IGNORE rows with installmentId == null (NO_INSTALLMENT)
      final Map<int, List<PlayerInstallmentSummary>> rowsByPlayer = {};
      for (final r in monthRows) {
        if (r.playerId == null) continue;
        // ignore NO_INSTALLMENT filler rows which have null installmentId
        if (r.installmentId == null) continue;
        rowsByPlayer.putIfAbsent(r.playerId, () => []).add(r);
      }

      // For each player, compute effective status: PENDING > PARTIALLY_PAID > PAID
      final now = DateTime.now();
      int dueCount = 0;
      int pendingCount = 0;
      int overdueCount = 0;

      rowsByPlayer.forEach((playerId, rows) {
        // prefer status priorities
        String chosenStatus = 'no_installment';
        DateTime? chosenDue;
        // scan rows
        for (final r in rows) {
          final st = _normalizeStatus(r.status);
          if (st == 'pending') {
            chosenStatus = 'pending';
            chosenDue = r.dueDate;
            break; // highest priority
          }
          if (st == 'partially paid' || st == 'partially_paid') {
            // choose partial if no pending found yet
            if (chosenStatus != 'partially paid' && chosenStatus != 'pending') {
              chosenStatus = 'partially paid';
              chosenDue = r.dueDate;
            }
            // continue scanning in case a pending exists
            continue;
          }
          if (st == 'paid') {
            // choose paid only if nothing else chosen
            if (chosenStatus == 'no_installment') {
              chosenStatus = 'paid';
              chosenDue = r.dueDate;
            }
          }
        }

        // Logging for debug
        debugPrint('AGG: player=$playerId chosenStatus=$chosenStatus due=$chosenDue');

        // Count logic: due = pending or partially paid
        if (chosenStatus == 'pending' || chosenStatus == 'partially paid') {
          dueCount++;
        }
        if (chosenStatus == 'pending') pendingCount++;

        // Overdue: if chosenDue < now and not fully paid
        if (chosenDue != null && chosenDue.isBefore(now) && chosenStatus != 'paid') {
          overdueCount++;
        }
      });

      if (mounted) {
        setState(() {
          _totalPlayers = playersRaw.length;
          _currentMonthDue = dueCount;
          _pendingPayments = pendingCount;
          _overdue = overdueCount;
        });
        debugPrint('DashboardStats: totals players=$_totalPlayers due=$_currentMonthDue pending=$_pendingPayments overdue=$_overdue');
      }
    } catch (e, st) {
      debugPrint('DashboardStats: unexpected error: $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _statCard(String title, int value, Color color, IconData icon) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _statCard('Total Players', _totalPlayers, Colors.blue, Icons.people),
            _statCard('This Month Due', _currentMonthDue, Colors.orange, Icons.calendar_month),
            _statCard('Pending', _pendingPayments, Colors.red, Icons.pending),
            _statCard('Overdue', _overdue, Colors.deepPurple, Icons.warning),
          ],
        ),
      ],
    );
  }
}
