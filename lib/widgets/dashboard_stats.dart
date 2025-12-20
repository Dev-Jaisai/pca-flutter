import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/player_installment_summary.dart';
import '../screens/home/home_screen.dart';
// ✅ Make sure this file exists!
import '../screens/installments/OverduePlayersScreen.dart';
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
    _numAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _numAnim = CurvedAnimation(
      parent: _numAnimController,
      curve: Curves.easeOut,
    );

    _loadFromCache();
    _loadStats();

    _playerEventsSubscription = EventBus().stream.listen((event) {
      if ([
        'added',
        'deleted',
        'updated',
        'installment_created',
        'installment_deleted',
        'payment_recorded',
        'installment_updated',
        'overdue_paid',
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

  Future<void> _loadFromCache() async {
    final cachedInstallments = await DataManager().getCachedAllInstallments();
    final cachedPlayers = DataManager().getCachedData().players;

    if (cachedInstallments != null && cachedInstallments.isNotEmpty) {
      final stats = await compute(_calculateStats, cachedInstallments);
      if (mounted) {
        setState(() {
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
  }

  Future<void> _loadStats() async {
    try {
      final results = await Future.wait([
        ApiService.fetchAllInstallmentsSummary(),
        ApiService.fetchPlayers(),
      ]);

      final allRows = results[0] as List<PlayerInstallmentSummary>;
      final players = results[1] as List<dynamic>;

      await DataManager().saveAllInstallments(allRows);
      final stats = await compute(_calculateStats, allRows);

      if (mounted) {
        setState(() {
          _totalPlayers = players.length;
          _currentMonthDue = stats['due']!;
          _upcomingCount = stats['upcoming']!;
          _overduePlayers = stats['overduePlayers']!;
          _overdueAmount = stats['overdueAmount']!;
          _loading = false;
        });
        _animateValues();
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted && _totalPlayers == 0) {
        setState(() => _loading = false);
      }
    }
  }

  static Map<String, dynamic> _calculateStats(List<PlayerInstallmentSummary> rows) {
    Set<int> playersWithThisMonthDue = {};
    Set<int> playersWithUpcoming = {};
    Set<int> playersWithOverdue = {};

    double overdueAmount = 0.0;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    final Map<int, List<PlayerInstallmentSummary>> playersMap = {};
    for (final r in rows) {
      if (r.playerId != null) {
        playersMap.putIfAbsent(r.playerId!, () => []).add(r);
      }
    }

    playersMap.forEach((playerId, playerRows) {
      bool playerHasThisMonthDue = false;
      bool playerHasUpcoming = false;
      bool playerHasOverdue = false;
      double playerOverdueAmount = 0.0;

      for (final r in playerRows) {
        final st = (r.status ?? '').toUpperCase().replaceAll('_', ' ').trim();
        final bool isPaid = st == 'PAID';

        if (r.dueDate == null) continue;

        if (r.dueDate!.isBefore(startOfToday) && !isPaid) {
          playerHasOverdue = true;
          final totalAmount = r.installmentAmount ?? 0.0;
          final paidAmount = r.totalPaid;
          final remaining = totalAmount - paidAmount;
          if (remaining > 0) {
            playerOverdueAmount += remaining;
          }
        }

        if (r.dueDate!.year == now.year && r.dueDate!.month == now.month && !isPaid) {
          playerHasThisMonthDue = true;
        }

        final nextMonthDate = DateTime(now.year, now.month + 1, 1);
        if (r.dueDate!.year == nextMonthDate.year && r.dueDate!.month == nextMonthDate.month && !isPaid) {
          playerHasUpcoming = true;
        }
      }

      if (playerHasOverdue) {
        playersWithOverdue.add(playerId);
        overdueAmount += playerOverdueAmount;
      }
      if (playerHasThisMonthDue) {
        playersWithThisMonthDue.add(playerId);
      }
      if (playerHasUpcoming) {
        playersWithUpcoming.add(playerId);
      }
    });

    return {
      'due': playersWithThisMonthDue.length,
      'upcoming': playersWithUpcoming.length,
      'overduePlayers': playersWithOverdue.length,
      'overdueAmount': overdueAmount,
    };
  }

  void _animateValues() {
    _numAnimController.reset();
    _numAnimController.forward();
    _playStaggered();
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

  Widget _animatedAmount(double value, TextStyle style) {
    return AnimatedBuilder(
      animation: _numAnim,
      builder: (context, child) {
        final v = (_numAnim.value * value).round();
        return Text('₹$v', style: style);
      },
    );
  }

  Widget _statCard({
    required String title,
    required int value,
    required double? amountValue,
    required IconData icon,
    required List<Color> gradient,
    required Color accent,
    required int index,
    VoidCallback? onTap,
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
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
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
                            offset: Offset(0, 4),
                          ),
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
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (amountValue != null)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: amountValue > 0
                                  ? _animatedAmount(
                                amountValue,
                                const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              )
                                  : const Text(
                                '₹0',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                      child: const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.white70,
                      ),
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
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final configs = [
      {
        'title': 'Total Players',
        'value': _totalPlayers,
        'amount': null,
        'icon': Icons.people,
        'gradient': [Colors.blue.shade400, Colors.blue.shade200],
        'accent': Colors.blue.shade50,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        ),
      },
      {
        'title': 'This Month Due',
        'value': _currentMonthDue,
        'amount': null,
        'icon': Icons.calendar_month,
        'gradient': [Colors.orange.shade400, Colors.orange.shade200],
        'accent': Colors.orange.shade50,
        'onTap': () => Navigator.pushNamed(
          context,
          '/all-installments',
          arguments: {'filter': 'Due (Month)'},
        ),
      },
      {
        'title': 'Upcoming',
        'value': _upcomingCount,
        'amount': null,
        'icon': Icons.next_plan,
        'gradient': [Colors.teal.shade400, Colors.teal.shade200],
        'accent': Colors.teal.shade50,
        'onTap': () => Navigator.pushNamed(
          context,
          '/all-installments',
          arguments: {'filter': 'Upcoming'},
        ),
      },
      {
        'title': 'Overdue',
        'value': _overduePlayers,
        'amount': _overdueAmount,
        'icon': Icons.warning,
        'gradient': [Colors.purple.shade400, Colors.purple.shade200],
        'accent': Colors.purple.shade50,
        // ✅ Corrected Navigation to OverduePlayersScreen
        'onTap': _overduePlayers > 0
            ? () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const OverduePlayersScreen(),
          ),
        )
            : null,
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
        const Text(
          'Quick Stats',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
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
                amountValue: c['amount'] as double?,
                icon: c['icon'] as IconData,
                gradient: c['gradient'] as List<Color>,
                accent: c['accent'] as Color,
                index: i,
                onTap: c['onTap'] as VoidCallback?,
              );
            },
          ),
        ),
      ],
    );
  }
}