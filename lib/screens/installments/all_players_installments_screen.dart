import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart'; // Import DataManager
import '../payments/payment_list_screen.dart';

class AllPlayersInstallmentsScreen extends StatefulWidget {
  final String? initialMonth; // YYYY-MM format

  const AllPlayersInstallmentsScreen({super.key, this.initialMonth});

  @override
  State<AllPlayersInstallmentsScreen> createState() => _AllPlayersInstallmentsScreenState();
}

class _AllPlayersInstallmentsScreenState extends State<AllPlayersInstallmentsScreen> {
  late String _selectedMonth;
  bool _loading = true;
  List<PlayerInstallmentSummary> _installmentSummary = [];
  List<Player> _allPlayers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = widget.initialMonth ?? '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    _loadData();
  }

  // ---------------------------------------------------------
  // 🚀 OPTIMIZED LOAD LOGIC
  // ---------------------------------------------------------
  Future<void> _loadData() async {
    // 1. Try loading from RAM/Disk Cache first (Instant)
    final cachedPlayers = await DataManager().getPlayers();
    final cachedInstallments = await DataManager().getCachedAllInstallments();

    if (cachedPlayers.isNotEmpty && cachedInstallments != null) {
      if (mounted) {
        setState(() {
          _allPlayers = cachedPlayers;
          _filterAndSetSummaries(cachedInstallments);
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = true);
    }

    // 2. Fetch Fresh Data in Background
    try {
      // Use DataManager to fetch fresh data (it handles caching)
      final freshPlayers = await DataManager().getPlayers(forceRefresh: true);
      final freshInstallments = await DataManager().getAllInstallments(forceRefresh: true); // Make sure this method exists in your DataManager or use ApiService directly + Save

      if (mounted) {
        setState(() {
          _allPlayers = freshPlayers;
          _filterAndSetSummaries(freshInstallments);
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _allPlayers.isEmpty) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }
  void _filterAndSetSummaries(List<PlayerInstallmentSummary> allItems) {
    final parts = _selectedMonth.split('-');
    final targetYear = int.parse(parts[0]);
    final targetMonth = int.parse(parts[1]);

    final filtered = allItems.where((item) {
      // ✅ Only check Due Date (This is safer and fixes your logic issue)
      if (item.dueDate != null) {
        return item.dueDate!.year == targetYear && item.dueDate!.month == targetMonth;
      }
      return false; // If no date, don't show in monthly view
    }).toList();

    _installmentSummary = filtered;
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final parts = _selectedMonth.split('-');
    final initialYear = int.tryParse(parts[0]) ?? now.year;
    final initialMonth = int.tryParse(parts[1]) ?? now.month;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Select Month"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simple Dropdown for Year/Month (Faster than DatePicker for billing)
              DropdownButton<int>(
                value: initialYear,
                isExpanded: true,
                items: List.generate(5, (i) => DropdownMenuItem(value: now.year - 2 + i, child: Text('${now.year - 2 + i}'))),
                onChanged: (v) => Navigator.pop(ctx, DateTime(v!, initialMonth)),
              ),
              const SizedBox(height: 10),
              DropdownButton<int>(
                value: initialMonth,
                isExpanded: true,
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(DateFormat('MMMM').format(DateTime(2024, i + 1))))),
                onChanged: (v) => Navigator.pop(ctx, DateTime(initialYear, v!)),
              ),
            ],
          ),
        ),
      ),
    );

    // Or use the standard picker if you prefer
    // final picked = await showDatePicker(...)

    if (picked != null) {
      final newMonth = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      setState(() {
        _selectedMonth = newMonth;
        // Re-filter the existing data immediately (Instant)
        DataManager().getCachedAllInstallments().then((list) {
          if(list != null) _filterAndSetSummaries(list);
        });
      });
      // Then refresh from API
      _loadData();
    }
  }

  PlayerInstallmentSummary? _getPlayerSummary(int playerId) {
    // Look up in the FILTERED list
    try {
      return _installmentSummary.firstWhere((s) => s.playerId == playerId);
    } catch (e) {
      // Return a dummy "No Installment" object
      return PlayerInstallmentSummary(
        playerId: playerId,
        playerName: '',
        totalPaid: 0.0,
        status: 'NO_INSTALLMENT',
      );
    }
  }

  Widget _buildPlayerRow(Player player) {
    final summary = _getPlayerSummary(player.id);
    final df = DateFormat('dd MMM');

    Color getStatusColor(String status) {
      switch (status) {
        case 'PAID': return Colors.green;
        case 'PARTIALLY_PAID': return Colors.orange;
        case 'PENDING': return Colors.red;
        case 'NO_INSTALLMENT': return Colors.grey;
        default: return Colors.grey;
      }
    }

    String getStatusText(String status) {
      if (status == 'NO_INSTALLMENT') return 'Create';
      return status.replaceAll('_', ' ');
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.deepPurple.shade50,
              child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: TextStyle(color: Colors.deepPurple.shade700, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('${player.group ?? '-'} • ${player.phone ?? '-'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),

                  if (summary!.status != 'NO_INSTALLMENT') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Paid: ₹${summary.totalPaid?.toStringAsFixed(0) ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                        const SizedBox(width: 10),
                        Text('Left: ₹${summary.remaining?.toStringAsFixed(0) ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    )
                  ]
                ],
              ),
            ),

            // Status / Action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (summary.dueDate != null)
                  Text('Due: ${df.format(summary.dueDate!)}', style: TextStyle(fontSize: 11, color: Colors.grey[800])),

                const SizedBox(height: 6),

                InkWell(
                  onTap: () {
                    if (summary.status == 'NO_INSTALLMENT') {
                      _createInstallmentForPlayer(player);
                    } else {
                      _viewInstallmentDetails(player, summary);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: getStatusColor(summary.status!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: getStatusColor(summary.status!), width: 1),
                    ),
                    child: Text(
                      getStatusText(summary.status!),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: getStatusColor(summary.status!)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInstallmentForPlayer(Player player) async {
    final parts = _selectedMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    // Simple Dialog to confirm creation
    await ApiService.createInstallmentForPlayer(
      playerId: player.id,
      periodMonth: month,
      periodYear: year,
      dueDate: DateTime(year, month, 10),
      amount: 500.0, // Should be fetched from fee structure ideally
    );

    // Refresh Data
    _loadData();
  }

  void _viewInstallmentDetails(Player player, PlayerInstallmentSummary summary) {
    if (summary.installmentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentsListScreen(
              installmentId: summary.installmentId!,
              remainingAmount: summary.remaining
          ),
        ),
      ).then((_) => _loadData());
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = _selectedMonth.split('-');
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(int.parse(parts[0]), int.parse(parts[1])));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(monthLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        // ✅ Explicit Back Button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.deepPurple),
            onPressed: _pickMonth,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _allPlayers.isEmpty
          ? const Center(child: Text('No players found'))
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: _allPlayers.length,
          itemBuilder: (context, index) {
            return _buildPlayerRow(_allPlayers[index]);
          },
        ),
      ),
    );
  }
}