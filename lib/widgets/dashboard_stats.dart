// lib/widgets/dashboard_stats.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/player_installment_summary.dart';
import '../services/api_service.dart';
import '../utils/event_bus.dart';
// If you want to navigate directly to screens instead of using named routes, import them here:
// import '../screens/installments/installment_summary_screen.dart';

class DashboardStats extends StatefulWidget {
  const DashboardStats({super.key});

  @override
  DashboardStatsState createState() => DashboardStatsState();
}

class DashboardStatsState extends State<DashboardStats> with TickerProviderStateMixin {
  int _totalPlayers = 0;
  int _currentMonthDue = 0;
  int _pendingPayments = 0;
  int _overdue = 0;
  bool _loading = true;
  late StreamSubscription<PlayerEvent> _playerEventsSubscription;

  // For staggered card reveals
  final List<bool> _visible = [false, false, false, false];

  // For smooth number anims
  late AnimationController _numAnimController;
  Animation<double> _numAnim = AlwaysStoppedAnimation<double>(1.0);

  @override
  void initState() {
    super.initState();

    _numAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _numAnim = CurvedAnimation(parent: _numAnimController, curve: Curves.easeOut);

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
        return '${year}-${month.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      debugPrint('DashboardStats: fetchLatestInstallmentMonth failed: $e');
    }
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _loadStats() async {
    if (mounted) setState(() => _loading = true);

    try {
      final targetMonth = await _getTargetYearMonth();

      List<PlayerInstallmentSummary> monthRows = [];
      try {
        monthRows = await ApiService.fetchInstallmentSummary(targetMonth);
      } catch (e) {
        monthRows = [];
      }

      List<dynamic> playersRaw = [];
      try {
        playersRaw = await ApiService.fetchPlayers();
      } catch (e) {
        playersRaw = [];
      }

      final Map<int, List<PlayerInstallmentSummary>> rowsByPlayer = {};
      for (final r in monthRows) {
        if (r.playerId == null || r.installmentId == null) continue;
        rowsByPlayer.putIfAbsent(r.playerId, () => []).add(r);
      }

      final now = DateTime.now();
      int dueCount = 0;
      int pendingCount = 0;
      int overdueCount = 0;

      rowsByPlayer.forEach((playerId, rows) {
        String chosenStatus = 'no_installment';
        DateTime? chosenDue;
        for (final r in rows) {
          final st = _normalizeStatus(r.status);
          if (st == 'pending') {
            chosenStatus = 'pending';
            chosenDue = r.dueDate;
            break;
          }
          if (st == 'partially paid' || st == 'partially_paid') {
            if (chosenStatus != 'partially paid' && chosenStatus != 'pending') {
              chosenStatus = 'partially paid';
              chosenDue = r.dueDate;
            }
            continue;
          }
          if (st == 'paid') {
            if (chosenStatus == 'no_installment') {
              chosenStatus = 'paid';
              chosenDue = r.dueDate;
            }
          }
        }

        if (chosenStatus == 'pending' || chosenStatus == 'partially paid') dueCount++;
        if (chosenStatus == 'pending') pendingCount++;
        if (chosenDue != null && chosenDue.isBefore(now) && chosenStatus != 'paid') overdueCount++;
      });

      if (mounted) {
        _numAnimController.reset();
        _numAnimController.forward();

        setState(() {
          _totalPlayers = playersRaw.length;
          _currentMonthDue = dueCount;
          _pendingPayments = pendingCount;
          _overdue = overdueCount;
        });

        _playStaggered();
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _playStaggered() {
    for (int i = 0; i < _visible.length; i++) _visible[i] = false;
    for (int i = 0; i < _visible.length; i++) {
      Future.delayed(Duration(milliseconds: 140 * i), () {
        if (mounted) setState(() => _visible[i] = true);
      });
    }
  }

  Widget _animatedNumber(int value, TextStyle style) {
    return AnimatedBuilder(
      animation: _numAnim,
      builder: (context, child) {
        final v = (_numAnim.value * value).round();
        return Text(v.toString(), style: style);
      },
    );
  }

  Widget _statCard({
    required String title,
    required int value,
    required IconData icon,
    required List<Color> gradient,
    required Color accent,
    required int index,
    VoidCallback? onTap, // Added onTap callback
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: _visible[index] ? 1.0 : 0.0,
      child: Transform.translate(
        offset: Offset(0, _visible[index] ? 0 : 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 10,
                  offset: Offset(0, 6)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap, // Hook up the tap event
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x11000000),
                              blurRadius: 6,
                              offset: Offset(0, 4))
                        ],
                      ),
                      child: Icon(icon, size: 26, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _animatedNumber(
                                value,
                                const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                          const SizedBox(height: 2),
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_right,
                          size: 20, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }

    // Helper to get current month string "YYYY-MM"
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final configs = [
      {
        'title': 'Total Players',
        'value': _totalPlayers,
        'icon': Icons.people,
        'gradient': [Colors.blue.shade400, Colors.blue.shade200],
        'accent': Colors.blue.shade50,
        'onTap': () => Navigator.pushNamed(context, '/players'),
      },
      {
        'title': 'This Month Due',
        'value': _currentMonthDue,
        'icon': Icons.calendar_month,
        'gradient': [Colors.orange.shade400, Colors.orange.shade200],
        'accent': Colors.orange.shade50,
        // ACTION: Open Summary for Current Month
        'onTap': () => Navigator.pushNamed(context, '/installment-summary', arguments: currentMonth),
      },
      {
        'title': 'Pending',
        'value': _pendingPayments,
        'icon': Icons.pending,
        'gradient': [Colors.red.shade400, Colors.red.shade200],
        'accent': Colors.red.shade50,
        // ACTION: Open Summary for Current Month
        'onTap': () => Navigator.pushNamed(context, '/installment-summary', arguments: currentMonth),
      },
      {
        'title': 'Overdue',
        'value': _overdue,
        'icon': Icons.warning,
        'gradient': [Colors.purple.shade400, Colors.purple.shade200],
        'accent': Colors.purple.shade50,
        // ACTION: Open Summary for Current Month
        'onTap': () => Navigator.pushNamed(context, '/installment-summary', arguments: currentMonth),
      },
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final crossCount = screenWidth > 600 ? 4 : 2;
    final cardHeight = screenWidth > 600 ? 110.0 : 100.0;
    const mainAxisSpacing = 12.0;
    const crossAxisSpacing = 12.0;
    final rows = (configs.length / crossCount).ceil();
    final gridHeight = rows * cardHeight + (rows - 1) * mainAxisSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: gridHeight,
          child: GridView.builder(
            itemCount: configs.length,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              childAspectRatio: (screenWidth / crossCount) / cardHeight,
            ),
            itemBuilder: (context, i) {
              final c = configs[i];
              return _statCard(
                title: c['title'] as String,
                value: c['value'] as int,
                icon: c['icon'] as IconData,
                gradient: c['gradient'] as List<Color>,
                accent: c['accent'] as Color,
                index: i,
                onTap: c['onTap'] as VoidCallback?, // Pass the onTap
              );
            },
          ),
        ),
      ],
    );
  }
}
