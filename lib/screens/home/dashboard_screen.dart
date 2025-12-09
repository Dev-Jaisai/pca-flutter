// lib/widgets/dashboard_stats.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../utils/event_bus.dart';


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

    // Listen to global events (player/installation/payment)
    _playerEventsSubscription = EventBus().stream.listen((event) {
      if (event.action == 'added' ||
          event.action == 'deleted' ||
          event.action == 'updated' ||
          event.action == 'installment_created' ||
          event.action == 'installment_deleted' ||
          event.action == 'payment_recorded') {
        debugPrint('DashboardStats: Received ${event.action} event, refreshing...');
        _loadStats();
      }
    });
  }

  @override
  void dispose() {
    _playerEventsSubscription.cancel();
    super.dispose();
  }

  // Public method to refresh stats
  Future<void> refreshStats() async => await _loadStats();

  /// Normalize backend status strings into canonical forms:
  /// - "PARTIALLY_PAID", "Partially Paid", "partially_paid" -> "partially paid"
  /// - "PENDING" / "Pending" -> "pending"
  /// - "NO_INSTALLMENT" -> "no installment"
  String _normalizeStatus(String? s) {
    if (s == null) return '';
    return s.toLowerCase().replaceAll('_', ' ').trim();
  }

  /// Call backend endpoint to get latest year/month. Fallback to current month if API fails.
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

    // fallback: current month
    final now = DateTime.now();
    final fallback = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    debugPrint('DashboardStats: using fallback month = $fallback');
    return fallback;
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loading = true);

    try {
      // determine which month to load (use latest-month endpoint if available)
      final targetMonth = await _getTargetYearMonth();

      // fetch month summary for the target month
      List<PlayerInstallmentSummary> monthSummary = <PlayerInstallmentSummary>[];
      try {
        monthSummary = await ApiService.fetchInstallmentSummary(targetMonth);
      } catch (e) {
        debugPrint('DashboardStats: fetchInstallmentSummary failed for $targetMonth: $e');
        monthSummary = <PlayerInstallmentSummary>[];
      }

      // fetch all players
      List<dynamic> playersRaw = <dynamic>[];
      try {
        playersRaw = await ApiService.fetchPlayers();
      } catch (e) {
        debugPrint('DashboardStats: fetchPlayers failed: $e');
        playersRaw = <dynamic>[];
      }

      // Debug: print a summary of what we received
      debugPrint('DashboardStats: monthSummary count=${monthSummary.length} for $targetMonth');
      for (final item in monthSummary) {
        debugPrint(
            'SUMMARY ROW: player=${item.playerName} id=${item.playerId} status=${item.status} due=${item.dueDate} amount=${item.installmentAmount} paid=${item.totalPaid}');
      }

      // Decide whether to count NO_INSTALLMENT as due.
      // Set to true if you want players with no installment to be considered "This Month Due".
      const bool includeNoInstallmentAsDue = false;

      // compute stats with normalization & null safety
      final int totalPlayers = playersRaw.length;

      int currentMonthDue = 0;
      int pendingPayments = 0;
      int overdueCount = 0;
      final now = DateTime.now();

      for (final item in monthSummary) {
        final st = _normalizeStatus(item.status);

        // current month due: pending or partially paid (and optionally no_installment)
        if (st.isNotEmpty) {
          if (st == 'no installment') {
            if (includeNoInstallmentAsDue) currentMonthDue++;
          } else if (st == 'pending' || st == 'partially paid') {
            currentMonthDue++;
          }
          if (st == 'pending') pendingPayments++;
        }

        // overdue: dueDate before now and not fully paid
        final due = item.dueDate;
        if (due != null && due.isBefore(now) && st != 'paid') {
          overdueCount++;
        }
      }

      if (mounted) {
        setState(() {
          _totalPlayers = totalPlayers;
          _currentMonthDue = currentMonthDue;
          _pendingPayments = pendingPayments;
          _overdue = overdueCount;
        });
        debugPrint(
            'DashboardStats: Updated - Total Players: $_totalPlayers, Due: $_currentMonthDue, Pending: $_pendingPayments, Overdue: $_overdue');
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
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Stats',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
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
