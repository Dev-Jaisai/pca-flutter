import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../widgets/FinancialSummaryCard.dart';
import '../../widgets/PlayerSummaryCard.dart';

class PlayerConsolidatedSummary {
  final int playerId;
  final String playerName;
  final String groupName;
  final String phone;
  final int? billingDay; // 🔥 ADDED THIS
  double totalAmount;
  double totalPaid;
  double totalRemaining;
  List<PlayerInstallmentSummary> installments;

  PlayerConsolidatedSummary({
    required this.playerId,
    required this.playerName,
    required this.groupName,
    required this.phone,
    this.billingDay, // 🔥
    this.totalAmount = 0.0,
    this.totalPaid = 0.0,
    this.totalRemaining = 0.0,
    required this.installments,
  });
}

class AllInstallmentsScreen extends StatefulWidget {
  final String? initialFilter;

  const AllInstallmentsScreen({super.key, this.initialFilter});

  @override
  State<AllInstallmentsScreen> createState() => _AllInstallmentsScreenState();
}

class _AllInstallmentsScreenState extends State<AllInstallmentsScreen> {
  List<PlayerInstallmentSummary> _allItems = [];
  Map<int, Player> _playerMap = {}; // 🔥 Store full player details here
  bool _isLoading = true;
  String? _error;
  String _currentFilter = 'All';
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _currentFilter = widget.initialFilter!;
    }
    if (_currentFilter == 'Upcoming') {
      final now = DateTime.now();
      _selectedMonth = DateTime(now.year, now.month + 1, 1);
    }
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch Players (to get billing day)
      // Try cache first for players
      var players = await DataManager().getPlayers();
      if (players.isEmpty) {
        players = await ApiService.fetchPlayers();
        await DataManager().saveData(players, []);
      }

      // Create a map for fast lookup: ID -> Player
      _playerMap = {for (var p in players) p.id: p};

      // 2. Fetch Installments
      final cachedData = await DataManager().getCachedAllInstallments();
      if (cachedData != null && cachedData.isNotEmpty) {
        _allItems = cachedData;
      }

      // Fetch fresh in background or foreground if empty
      final List<PlayerInstallmentSummary> list = await ApiService.fetchAllInstallmentsSummary(page: 0, size: 2000);
      await DataManager().saveAllInstallments(list);

      if (mounted) {
        setState(() {
          _allItems = list;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Don't show error if we have some data
          if (_allItems.isEmpty) _error = e.toString();
        });
      }
    }
  }

  // ... _pickMonthForFilter ... (Keep as is)
  Future<void> _pickMonthForFilter() async {
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        int selectedYear = _selectedMonth.year;
        int selectedMonth = _selectedMonth.month;
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            title: const Text("Select Month", style: TextStyle(color: Colors.white)),
            content: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedMonth,
                    dropdownColor: const Color(0xFF2C5364),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54))),
                    items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMM').format(DateTime(2024, i + 1))))),
                    onChanged: (v) => setStateDialog(() => selectedMonth = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedYear,
                    dropdownColor: const Color(0xFF2C5364),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54))),
                    items: List.generate(5, (i) => DropdownMenuItem(value: now.year - 2 + i, child: Text('${now.year - 2 + i}'))),
                    onChanged: (v) => setStateDialog(() => selectedYear = v!),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context, DateTime(selectedYear, selectedMonth, 1)),
                child: const Text("Select"),
              ),
            ],
          );
        });
      },
    );
    if (picked != null) {
      setState(() => _selectedMonth = picked);
    }
  }

  // ... _getFilteredRawItems ... (Keep as is)
  List<PlayerInstallmentSummary> _getFilteredRawItems() {
    if (_currentFilter == 'All') return _allItems;

    if (_currentFilter == 'Upcoming') {
      return _allItems.where((p) {
        if (p.dueDate == null) return false;
        final st = (p.status ?? '').toUpperCase().replaceAll('_', ' ').trim();
        if (st == 'PAID') return false;
        return p.dueDate!.year == _selectedMonth.year &&
            p.dueDate!.month == _selectedMonth.month;
      }).toList();
    }

    if (_currentFilter == 'Due (Month)') {
      return _allItems.where((p) {
        if (p.dueDate == null) return false;
        return p.dueDate!.year == _selectedMonth.year &&
            p.dueDate!.month == _selectedMonth.month;
      }).toList();
    }

    final filterUpper = _currentFilter.toUpperCase();
    return _allItems.where((p) {
      final st = (p.status ?? '').toUpperCase().replaceAll('_', ' ').trim();
      return st == filterUpper;
    }).toList();
  }

  List<PlayerConsolidatedSummary> _getGroupedItems() {
    final rawItems = _getFilteredRawItems();
    final Map<int, PlayerConsolidatedSummary> groupedMap = {};

    for (var item in rawItems) {
      if (item.playerId == null) continue;

      // 🔥 Retrieve billing day from Player Map
      int? billDay;
      if (_playerMap.containsKey(item.playerId)) {
        billDay = _playerMap[item.playerId]!.billingDay;
      }

      if (!groupedMap.containsKey(item.playerId)) {
        groupedMap[item.playerId!] = PlayerConsolidatedSummary(
          playerId: item.playerId!,
          playerName: item.playerName,
          groupName: item.groupName ?? '',
          phone: item.phone ?? '',
          billingDay: billDay, // 🔥 Pass it here
          installments: [],
        );
      }
      final summary = groupedMap[item.playerId]!;
      summary.totalAmount += (item.installmentAmount ?? 0.0);
      summary.totalPaid += (item.totalPaid ?? 0.0);
      summary.installments.add(item);
    }

    for (var summary in groupedMap.values) {
      summary.totalRemaining = summary.totalAmount - summary.totalPaid;

      // Sorting Logic (Unpaid Top, then Paid)
      summary.installments.sort((a, b) {
        bool isPaidA = (a.status ?? '').toUpperCase() == 'PAID';
        bool isPaidB = (b.status ?? '').toUpperCase() == 'PAID';

        if (isPaidA != isPaidB) {
          return isPaidA ? 1 : -1;
        }

        DateTime dateA = a.dueDate ?? DateTime(2000);
        DateTime dateB = b.dueDate ?? DateTime(2000);

        if (isPaidA) {
          return dateB.compareTo(dateA);
        } else {
          return dateA.compareTo(dateB);
        }
      });
    }

    return groupedMap.values.toList()
      ..sort((a, b) => b.totalRemaining.compareTo(a.totalRemaining));
  }

  // ... _calculateSummary ... (Keep as is)
  Map<String, double> _calculateSummary(List<PlayerConsolidatedSummary> items) {
    double expected = 0;
    double collected = 0;
    double pending = 0;
    for (var i in items) {
      expected += i.totalAmount;
      collected += i.totalPaid;
      pending += i.totalRemaining;
    }
    return {'expected': expected, 'collected': collected, 'pending': pending};
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = _getGroupedItems();
    final stats = _calculateSummary(groupedItems);

    String titleText = 'All Installments';
    String headerTitle = "Total Summary";

    if (_currentFilter == 'Due (Month)') {
      titleText = 'Due: ${DateFormat('MMM yyyy').format(_selectedMonth)}';
      headerTitle = DateFormat('MMMM yyyy').format(_selectedMonth);
    } else if (_currentFilter == 'Upcoming') {
      titleText = 'Upcoming: ${DateFormat('MMM yyyy').format(_selectedMonth)}';
      headerTitle = "Upcoming (${DateFormat('MMM').format(_selectedMonth)})";
    } else if (_currentFilter != 'All') {
      titleText = '$_currentFilter Players';
      headerTitle = "$_currentFilter List";
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_currentFilter == 'Due (Month)' || _currentFilter == 'Upcoming')
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.cyanAccent),
              onPressed: _pickMonthForFilter,
            ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadAllData),

          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            color: const Color(0xFF203A43),
            initialValue: _currentFilter,
            onSelected: (String val) {
              setState(() {
                _currentFilter = val;
                if (_currentFilter == 'Upcoming') {
                  final now = DateTime.now();
                  if (_selectedMonth.isBefore(DateTime(now.year, now.month + 1, 1))) {
                    _selectedMonth = DateTime(now.year, now.month + 1, 1);
                  }
                }
                if (_currentFilter == 'Due (Month)') {
                  _selectedMonth = DateTime.now();
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Installments', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'Due (Month)', child: Text('This Month Due', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'Upcoming', child: Text('Upcoming (Next Month)', style: TextStyle(color: Colors.white))),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(value: 'Paid', child: Text('Paid Players', style: TextStyle(color: Colors.greenAccent))),
              const PopupMenuItem(value: 'Pending', child: Text('Pending Players', style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),
          Positioned(
            top: -50, right: -50,
            child: Container(height: 200, width: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.2), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 100, spreadRadius: 50)])),
          ),
          Positioned(
            bottom: 100, left: -50,
            child: Container(height: 200, width: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.2), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 100, spreadRadius: 50)])),
          ),

          SafeArea(
            child: _isLoading && groupedItems.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : groupedItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_alt_off, size: 60, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text("No records found for $_currentFilter", style: const TextStyle(color: Colors.white54)),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadAllData,
              color: Colors.cyanAccent,
              backgroundColor: const Color(0xFF203A43),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 10, bottom: 80),
                itemCount: groupedItems.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return FinancialSummaryCard(
                      title: headerTitle,
                      totalTarget: stats['expected']!,
                      totalCollected: stats['collected']!,
                      totalPending: stats['pending']!,
                      countLabel: "${groupedItems.length} Players",
                    );
                  }

                  final group = groupedItems[i - 1];

                  final player = Player(
                      id: group.playerId,
                      name: group.playerName,
                      group: group.groupName,
                      phone: group.phone,
                      billingDay: group.billingDay // 🔥 PASS BILLING DAY TO PLAYER OBJECT
                  );

                  final summary = PlayerInstallmentSummary(
                    playerId: group.playerId,
                    playerName: group.playerName,
                    totalPaid: group.totalPaid,
                    installmentAmount: group.totalAmount,
                    remaining: group.totalRemaining,
                    status: group.totalRemaining > 0 ? 'PENDING' : 'PAID',
                    lastPaymentDate: group.installments.isNotEmpty
                        ? group.installments.first.lastPaymentDate
                        : null,
                  );

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PlayerSummaryCard(
                      player: player,
                      summary: summary,
                      installments: group.installments,
                      nextScreenFilter: _currentFilter == 'Overdue' ? 'Overdue' : null,
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