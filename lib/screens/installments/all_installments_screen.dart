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
  double totalAmount;
  double totalPaid;
  double totalRemaining;
  List<PlayerInstallmentSummary> installments;

  PlayerConsolidatedSummary({
    required this.playerId,
    required this.playerName,
    required this.groupName,
    required this.phone,
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
    final cachedData = await DataManager().getCachedAllInstallments();
    if (cachedData != null && cachedData.isNotEmpty) {
      if (mounted) setState(() { _allItems = cachedData; _isLoading = false; });
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final List<PlayerInstallmentSummary> list = await ApiService.fetchAllInstallmentsSummary(page: 0, size: 2000);
      await DataManager().saveAllInstallments(list);
      if (mounted) setState(() { _allItems = list; _isLoading = false; _error = null; });
    } catch (e) {
      if (mounted && _allItems.isEmpty) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _pickMonthForFilter() async {
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        int selectedYear = _selectedMonth.year;
        int selectedMonth = _selectedMonth.month;
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Select Month"),
            content: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedMonth,
                    items: List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text(DateFormat('MMM').format(DateTime(2024, i+1))))),
                    onChanged: (v) => setStateDialog(() => selectedMonth = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedYear,
                    items: List.generate(5, (i) => DropdownMenuItem(value: now.year - 2 + i, child: Text('${now.year - 2 + i}'))),
                    onChanged: (v) => setStateDialog(() => selectedYear = v!),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
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

  List<PlayerInstallmentSummary> _getFilteredRawItems() {
    if (_currentFilter == 'All') return _allItems;

    if (_currentFilter == 'Upcoming') {
      return _allItems.where((p) {
        if (p.dueDate == null) return false;
        final st = (p.status ?? '').toUpperCase().replaceAll('_', ' ').trim();
        if (st == 'PAID') return false;
        return p.dueDate!.year == _selectedMonth.year && p.dueDate!.month == _selectedMonth.month;
      }).toList();
    }

    if (_currentFilter == 'Due (Month)') {
      return _allItems.where((p) {
        if (p.dueDate == null) return false;
        return p.dueDate!.year == _selectedMonth.year && p.dueDate!.month == _selectedMonth.month;
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
      if (!groupedMap.containsKey(item.playerId)) {
        groupedMap[item.playerId!] = PlayerConsolidatedSummary(
          playerId: item.playerId!,
          playerName: item.playerName,
          groupName: item.groupName ?? '',
          phone: item.phone ?? '',
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
      summary.installments.sort((a, b) => (a.dueDate ?? DateTime(2000)).compareTo(b.dueDate ?? DateTime(2000)));
    }

    return groupedMap.values.toList()..sort((a, b) => b.totalRemaining.compareTo(a.totalRemaining));
  }

  // Calculate Header Stats
  Map<String, double> _calculateSummary(List<PlayerConsolidatedSummary> items) {
    double expected = 0;
    double collected = 0;
    double pending = 0;
    for(var i in items) {
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          if (_currentFilter == 'Due (Month)' || _currentFilter == 'Upcoming')
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.deepPurple),
              onPressed: _pickMonthForFilter,
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
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
              const PopupMenuItem(value: 'All', child: Text('All Installments')),
              const PopupMenuItem(value: 'Due (Month)', child: Text('This Month Due')),
              const PopupMenuItem(value: 'Upcoming', child: Text('Upcoming (Next Month)')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'Paid', child: Text('Paid Players')),
              const PopupMenuItem(value: 'Pending', child: Text('Pending Players')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : groupedItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("No records found for $_currentFilter", style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 0, bottom: 80),
          itemCount: groupedItems.length + 1,
          itemBuilder: (ctx, i) {

            // 1. Show Header
            if (i == 0) {
              return FinancialSummaryCard(
                title: headerTitle,
                totalTarget: stats['expected']!,
                totalCollected: stats['collected']!,
                totalPending: stats['pending']!,
                countLabel: "${groupedItems.length} Players",
              );
            }

            // 2. Show List
            final group = groupedItems[i - 1];

            final player = Player(
                id: group.playerId,
                name: group.playerName,
                group: group.groupName,
                phone: group.phone
            );

            final summary = PlayerInstallmentSummary(
              playerId: group.playerId,
              playerName: group.playerName,
              totalPaid: group.totalPaid,
              installmentAmount: group.totalAmount,
              remaining: group.totalRemaining,
              status: group.totalRemaining > 0 ? 'PENDING' : 'PAID',
            );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PlayerSummaryCard(
                player: player,
                summary: summary,
                installments: group.installments,
              ),
            );
          },
        ),
      ),
    );
  }
}