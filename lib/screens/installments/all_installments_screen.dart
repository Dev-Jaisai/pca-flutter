import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../widgets/FinancialSummaryCard.dart';
import '../../widgets/PlayerSummaryCard.dart'; // ✅ हे widget अपडेटेड असावे

class AllInstallmentsScreen extends StatefulWidget {
  final String? initialFilter;

  const AllInstallmentsScreen({super.key, this.initialFilter});

  @override
  State<AllInstallmentsScreen> createState() => _AllInstallmentsScreenState();
}

class _AllInstallmentsScreenState extends State<AllInstallmentsScreen> {
  // 🔥 Data Structure: List of Maps containing Player + Summary + List of Installments
  List<Map<String, dynamic>> _groupedList = [];

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
      // 1. Fetch Players (Billing Day साठी हे गरजेचे आहे)
      var players = await DataManager().getPlayers();
      if (players.isEmpty) {
        players = await ApiService.fetchPlayers();
        await DataManager().saveData(players, []);
      }
      // Player Map बनवला (Fast Lookup साठी)
      final playerMap = {for (var p in players) p.id: p};

      // 2. Fetch Installments
      final cachedData = await DataManager().getCachedAllInstallments();
      List<PlayerInstallmentSummary> rawList = [];

      if (cachedData != null && cachedData.isNotEmpty) {
        rawList = cachedData;
      } else {
        // Cache नसेल तर API कॉल करा
        rawList = await ApiService.fetchAllInstallmentsSummary(page: 0, size: 5000);
        await DataManager().saveAllInstallments(rawList);
      }

      // 3. Process & Group Data
      if (mounted) {
        _processGroupedData(rawList, playerMap);
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_groupedList.isEmpty) _error = e.toString();
        });
      }
    }
  }

  void _processGroupedData(List<PlayerInstallmentSummary> rawList, Map<int, Player> playerMap) {
    // A. Filter Raw List based on selection
    List<PlayerInstallmentSummary> filteredList = [];

    if (_currentFilter == 'Due (Month)' || _currentFilter == 'Upcoming') {
      filteredList = rawList.where((p) {
        if (p.dueDate == null) return false;
        return p.dueDate!.year == _selectedMonth.year &&
            p.dueDate!.month == _selectedMonth.month;
      }).toList();
    } else {
      // 'All' filter -> Sagle gheun taka, group logic handle karel
      filteredList = rawList;
    }

    // B. Group By Player ID
    Map<int, List<PlayerInstallmentSummary>> grouped = {};
    for (var item in filteredList) {
      if (item.playerId == null) continue;
      if (!grouped.containsKey(item.playerId)) {
        grouped[item.playerId!] = [];
      }
      grouped[item.playerId!]!.add(item);
    }

    // C. Convert to Display List
    List<Map<String, dynamic>> result = [];

    grouped.forEach((pid, installments) {
      if (!playerMap.containsKey(pid)) return;

      final player = playerMap[pid]!;

      // Calculate Totals per Player
      double totalPaid = 0;
      double totalRemaining = 0;
      double totalAmount = 0;

      // Find 'Main' status logic
      String mainStatus = 'PAID';
      DateTime? latestPaymentDate;

      // Sort Installments: Latest First (Newest Month Top)
      installments.sort((a, b) {
        DateTime dateA = a.dueDate ?? DateTime(2000);
        DateTime dateB = b.dueDate ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      for (var inst in installments) {
        totalAmount += (inst.installmentAmount ?? 0);
        totalPaid += inst.totalPaid;
        totalRemaining += (inst.remaining ?? 0);

        // Status Logic: Jar ekjari pending asel tar status PENDING
        if ((inst.remaining ?? 0) > 0) {
          mainStatus = 'PENDING';
        }

        // Jar Latest Payment Date update karaychi asel
        if (inst.lastPaymentDate != null) {
          if (latestPaymentDate == null || inst.lastPaymentDate!.isAfter(latestPaymentDate)) {
            latestPaymentDate = inst.lastPaymentDate;
          }
        }
      }

      // Special: Jar overdue asel tar status OVERDUE kara (Check latest due date)
      if (installments.isNotEmpty && totalRemaining > 0) {
        if (installments.first.dueDate != null && installments.first.dueDate!.isBefore(DateTime.now())) {
          // mainStatus logic PlayerSummaryCard madhye ahe, pan ethe PENDING thevla tari chalel
        }
      }

      // Latest Installment (Header saathi)
      final latestInst = installments.isNotEmpty ? installments.first : null;

      // Create Aggregate Summary
      final summary = PlayerInstallmentSummary(
          playerId: pid,
          playerName: player.name,
          totalPaid: totalPaid,
          installmentAmount: totalAmount,
          remaining: totalRemaining,
          status: mainStatus,
          lastPaymentDate: latestPaymentDate,
          dueDate: latestInst?.dueDate, // Latest date pass kara
          installmentId: latestInst?.installmentId
      );

      result.add({
        'player': player,
        'summary': summary,
        'installments': installments // 🔥 List pass kara chips sathi
      });
    });

    // D. Final Sort (Jyanche paise baki ahet te var)
    result.sort((a, b) {
      double remA = (a['summary'] as PlayerInstallmentSummary).remaining ?? 0;
      double remB = (b['summary'] as PlayerInstallmentSummary).remaining ?? 0;
      return remB.compareTo(remA);
    });

    _groupedList = result;
  }

  // ... (Summary Stats Calculation) ...
  Map<String, double> _calculateStats() {
    double expected = 0, collected = 0, pending = 0;
    for (var item in _groupedList) {
      final s = item['summary'] as PlayerInstallmentSummary;
      expected += (s.installmentAmount ?? 0);
      collected += s.totalPaid;
      pending += (s.remaining ?? 0);
    }
    return {'expected': expected, 'collected': collected, 'pending': pending};
  }

  // ... (Date Picker Logic) ...
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
      setState(() {
        _selectedMonth = picked;
        _loadAllData(); // Reload
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    // Title Logic
    String titleText = 'All Installments';
    String headerTitle = "Total Summary";
    if (_currentFilter == 'Due (Month)') {
      titleText = 'Due: ${DateFormat('MMM yyyy').format(_selectedMonth)}';
      headerTitle = DateFormat('MMMM yyyy').format(_selectedMonth);
    } else if (_currentFilter == 'Upcoming') {
      titleText = 'Upcoming: ${DateFormat('MMM yyyy').format(_selectedMonth)}';
      headerTitle = "Upcoming (${DateFormat('MMM').format(_selectedMonth)})";
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
                _loadAllData();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Installments', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'Due (Month)', child: Text('This Month Due', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'Upcoming', child: Text('Upcoming', style: TextStyle(color: Colors.white))),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),

          SafeArea(
            child: _isLoading && _groupedList.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _groupedList.isEmpty
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
                // Header + List Items
                itemCount: _groupedList.length + 1,
                itemBuilder: (ctx, i) {
                  // 0th Index = Financial Summary Card
                  if (i == 0) {
                    return FinancialSummaryCard(
                      title: headerTitle,
                      totalTarget: stats['expected']!,
                      totalCollected: stats['collected']!,
                      totalPending: stats['pending']!,
                      countLabel: "${_groupedList.length} Players",
                    );
                  }

                  // Player Cards
                  final item = _groupedList[i - 1];
                  final player = item['player'] as Player;
                  final summary = item['summary'] as PlayerInstallmentSummary;
                  final installments = item['installments'] as List<PlayerInstallmentSummary>;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: PlayerSummaryCard(
                      player: player,
                      summary: summary,
                      installments: installments, // 🔥 LIST PASSED HERE
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