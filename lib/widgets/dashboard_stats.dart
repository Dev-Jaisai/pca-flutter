import 'dart:async';
import 'dart:ui'; // Glassmorphism
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/player_installment_summary.dart';
import '../screens/home/home_screen.dart';
import '../screens/installments/universal_list_screen.dart'; // ✅ Use Universal Screen
import '../services/api_service.dart';
import '../services/data_manager.dart';
import '../utils/event_bus.dart';

class DashboardStats extends StatefulWidget {
  const DashboardStats({super.key});

  @override
  DashboardStatsState createState() => DashboardStatsState();
}

class DashboardStatsState extends State<DashboardStats> with TickerProviderStateMixin {
  int _totalPlayers = 0;
  int _currentMonthDue = 0;
  int _upcomingCount = 0;
  double _overdueAmount = 0.0;
  bool _loading = true;
  int _overduePlayers = 0;

  late StreamSubscription<PlayerEvent> _playerEventsSubscription;
  final List<bool> _visible = [false, false, false, false];
  late AnimationController _numAnimController;
  late Animation<double> _numAnim;

  @override
  void initState() {
    super.initState();
    _numAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _numAnim = CurvedAnimation(parent: _numAnimController, curve: Curves.easeOut);
    _loadFromCache();
    _loadStats();

    _playerEventsSubscription = EventBus().stream.listen((event) {
      if (['added', 'deleted', 'updated', 'installment_created', 'installment_deleted', 'payment_recorded', 'installment_updated', 'overdue_paid'].contains(event.action)) {
        _loadStats();
      }
    });
  }

  @override
  void dispose() {
    _playerEventsSubscription.cancel();
    _numAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    final cachedInstallments = await DataManager().getCachedAllInstallments();
    final cachedPlayers = DataManager().getCachedData().players;
    if (cachedInstallments != null && cachedInstallments.isNotEmpty) {
      final stats = await compute(_calculateStats, cachedInstallments);
      if (mounted) setState(() {
        _totalPlayers = cachedPlayers?.length ?? 0;
        _currentMonthDue = stats['due']!;
        _upcomingCount = stats['upcoming']!;
        _overduePlayers = stats['overduePlayers']!;
        _overdueAmount = stats['overdueAmount']!;
        _loading = false;
      });
      _animateValues();
    }
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([ApiService.fetchAllInstallmentsSummary(), ApiService.fetchPlayers()]);
      final allRows = results[0] as List<PlayerInstallmentSummary>;
      final players = results[1] as List<dynamic>;
      await DataManager().saveAllInstallments(allRows);
      final stats = await compute(_calculateStats, allRows);
      if (mounted) setState(() {
        _totalPlayers = players.length;
        _currentMonthDue = stats['due']!;
        _upcomingCount = stats['upcoming']!;
        _overduePlayers = stats['overduePlayers']!;
        _overdueAmount = stats['overdueAmount']!;
        _loading = false;
      });
      _animateValues();
    } catch (e) {
      if (mounted && _totalPlayers == 0) setState(() => _loading = false);
    }
  }

  static Map<String, dynamic> _calculateStats(List<PlayerInstallmentSummary> rows) {
    Set<int> due = {}, upcoming = {}, overdue = {};
    double overdueAmt = 0.0;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    for (var r in rows) {
      if (r.playerId == null || r.dueDate == null) continue;

      final status = (r.status ?? '').toUpperCase();
      // Skip stats for Holiday/Left players
      if (status == 'SKIPPED' || status == 'CANCELLED') continue;

      bool isPaid = status == 'PAID';

      if (r.dueDate!.isBefore(startOfToday) && !isPaid) {
        overdue.add(r.playerId!);
        if ((r.remaining ?? 0) > 0) overdueAmt += (r.remaining ?? 0);
      }
      if (r.dueDate!.year == now.year && r.dueDate!.month == now.month && !isPaid) due.add(r.playerId!);
      if (r.dueDate!.year == nextMonth.year && r.dueDate!.month == nextMonth.month && !isPaid) upcoming.add(r.playerId!);
    }
    return {'due': due.length, 'upcoming': upcoming.length, 'overduePlayers': overdue.length, 'overdueAmount': overdueAmt};
  }

  void _animateValues() { _numAnimController.reset(); _numAnimController.forward(); _playStaggered(); }
  void _playStaggered() { for (int i = 0; i < 4; i++) { Future.delayed(Duration(milliseconds: 100 * i), () { if (mounted) setState(() => _visible[i] = true); }); } }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));

    final configs = [
      {
        'title': 'Total Players',
        'value': _totalPlayers,
        'amount': null,
        'icon': Icons.people,
        'gradient': [Colors.blueAccent.withOpacity(0.6), Colors.blue.withOpacity(0.3)],
        'color': Colors.blueAccent,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
      },
      {
        'title': 'This Month Due',
        'value': _currentMonthDue,
        'amount': null,
        'icon': Icons.calendar_month,
        'gradient': [Colors.orangeAccent.withOpacity(0.6), Colors.deepOrange.withOpacity(0.3)],
        'color': Colors.orangeAccent,
        // 🔥 Navigates to Universal List (Monthly)
        'onTap': () {
          final currentMonthStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
          Navigator.push(context, MaterialPageRoute(builder: (_) => UniversalListScreen(
              title: "This Month's Dues",
              filterType: "MONTHLY",
              targetMonth: currentMonthStr
          )));
        },
      },
      {
        'title': 'Upcoming',
        'value': _upcomingCount,
        'amount': null,
        'icon': Icons.next_plan,
        'gradient': [Colors.tealAccent.withOpacity(0.6), Colors.teal.withOpacity(0.3)],
        'color': Colors.tealAccent,
        // 🔥 Navigates to Universal List (Upcoming) -- Logic handled inside Universal List
        // Note: For simplicity, you might want to implement UPCOMING filter in Universal List or just keep separate screen if complex logic needed.
        // For now, let's assume Universal List handles it or we use old screen if preferred.
        // Let's use Universal List with a 'MONTHLY' filter for next month as "Upcoming"
        'onTap': () {
          final nextMonth = DateTime.now().add(const Duration(days: 30));
          final nextMonthStr = "${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}";
          Navigator.push(context, MaterialPageRoute(builder: (_) => UniversalListScreen(
              title: "Upcoming Dues",
              filterType: "MONTHLY",
              targetMonth: nextMonthStr
          )));
        },
      },
      {
        'title': 'Overdue',
        'value': _overduePlayers,
        'amount': _overdueAmount,
        'icon': Icons.warning_amber_rounded,
        'gradient': [Colors.redAccent.withOpacity(0.6), Colors.red.withOpacity(0.3)],
        'color': Colors.redAccent,
        // 🔥 Navigates to Universal List (Overdue)
        'onTap': _overduePlayers > 0 ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UniversalListScreen(
            title: "Overdue List",
            filterType: "OVERDUE"
        ))) : null,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Stats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: configs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6
          ),
          itemBuilder: (context, i) {
            final c = configs[i];
            return _buildGlassStatCard(c, i);
          },
        ),
      ],
    );
  }

  Widget _buildGlassStatCard(Map<String, dynamic> c, int index) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: _visible[index] ? 1.0 : 0.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: c['onTap'],
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c['gradient'], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Icon(c['icon'], color: Colors.white, size: 20)),
                      if (c['amount'] != null && c['amount'] > 0)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4)), child: Text('₹${(c['amount'] as double).toInt()}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _numAnim,
                        builder: (ctx, ch) => Text('${(_numAnim.value * c['value']).toInt()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      Text(c['title'], style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}