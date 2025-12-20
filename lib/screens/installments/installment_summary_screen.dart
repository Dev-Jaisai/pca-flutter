import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart'; // ✅ Import Player Model
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../models/player_installment_summary.dart';
import '../../widgets/PlayerSummaryCard.dart';

class InstallmentSummaryScreen extends StatefulWidget {
  final String? initialMonth;
  final String? initialFilter;

  const InstallmentSummaryScreen({super.key, this.initialMonth, this.initialFilter});

  @override
  State<InstallmentSummaryScreen> createState() => _InstallmentSummaryScreenState();
}

class _InstallmentSummaryScreenState extends State<InstallmentSummaryScreen> {
  late String _selectedMonth;
  String _filter = 'all';
  bool _loading = true;
  String? _error;
  List<PlayerInstallmentSummary> _items = [];

  // Stats Variables
  double _totalAmount = 0;
  double _totalPaid = 0;
  double _totalRemaining = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialMonth != null && widget.initialMonth!.isNotEmpty) {
      _selectedMonth = widget.initialMonth!;
    } else {
      final now = DateTime.now();
      _selectedMonth = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    }
    _filter = widget.initialFilter ?? 'all';
    _load();
  }

  Future<void> _load() async {
    // 1. Load from Cache
    final cachedData = await DataManager().getCachedAllInstallments();
    if (cachedData != null && cachedData.isNotEmpty) {
      if (mounted) {
        setState(() {
          _processAndDisplay(cachedData);
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = true);
    }

    // 2. Fetch Fresh Data
    try {
      final freshList = await ApiService.fetchAllInstallmentsSummary(page: 0, size: 5000);
      await DataManager().saveAllInstallments(freshList);
      if (mounted) {
        setState(() {
          _processAndDisplay(freshList);
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _items.isEmpty) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _processAndDisplay(List<PlayerInstallmentSummary> allData) {
    List<PlayerInstallmentSummary> filteredList = allData;

    // Filter by Selected Month
    final parts = _selectedMonth.split('-');
    final selYear = int.parse(parts[0]);
    final selMonth = int.parse(parts[1]);

    filteredList = allData.where((item) {
      if (item.dueDate != null) {
        return item.dueDate!.year == selYear && item.dueDate!.month == selMonth;
      }
      return false;
    }).toList();

    // Calculate Stats
    _totalAmount = 0;
    _totalPaid = 0;
    _totalRemaining = 0;
    _totalCount = filteredList.length;

    for (var item in filteredList) {
      _totalAmount += item.installmentAmount ?? 0;
      _totalPaid += item.totalPaid;
      _totalRemaining += item.remaining ?? 0;
    }

    // Update List
    _items = filteredList;
  }

  // ✅ FIXED: Missing _pickMonth Function Added Here
  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final parts = _selectedMonth.split('-');
    int currentYear = int.parse(parts[0]);
    int currentMonth = int.parse(parts[1]);

    await showDialog(
      context: context,
      builder: (context) {
        int tempYear = currentYear;
        int tempMonth = currentMonth;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Select Month", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Row(
                children: [
                  // Month Dropdown
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempMonth,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      items: List.generate(12, (index) {
                        final m = index + 1;
                        final name = DateFormat.MMM().format(DateTime(2024, m));
                        return DropdownMenuItem(value: m, child: Text(name));
                      }),
                      onChanged: (val) { if (val != null) setDialogState(() => tempMonth = val); },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Year Dropdown
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempYear,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                      items: List.generate(5, (index) {
                        final y = now.year - 2 + index;
                        return DropdownMenuItem(value: y, child: Text(y.toString()));
                      }),
                      onChanged: (val) { if (val != null) setDialogState(() => tempYear = val); },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newMonthStr = '$tempYear-${tempMonth.toString().padLeft(2, '0')}';
                    setState(() => _selectedMonth = newMonthStr);
                    Navigator.pop(context);
                    _load(); // Reload data for new month
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Select"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Header Widget (Total/Collected/Pending)
  Widget _buildSummaryHeader() {
    final date = DateTime.parse('$_selectedMonth-01');
    final monthName = DateFormat('MMMM yyyy').format(date);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  "Total: $_totalCount",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(Icons.monetization_on, "Target", _totalAmount),
              _buildSummaryItem(Icons.check_circle, "Collected", _totalPaid),
              _buildSummaryItem(Icons.pending, "Pending", _totalRemaining),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, double amount) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          "₹${amount >= 1000 ? (amount / 1000).toStringAsFixed(1) + 'k' : amount.toInt()}",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Monthly Summary', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 1. Beautiful Header
          _buildSummaryHeader(),

          // 2. List of Players using Shared Card
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text("No records for this month."))
                : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final item = _items[i];

                  // Convert to Player Object
                  final player = Player(
                      id: item.playerId ?? 0,
                      name: item.playerName,
                      group: item.groupName ?? '',
                      phone: item.phone ?? ''
                  );

                  // Reuse the Shared Card
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PlayerSummaryCard(
                      player: player,
                      summary: item,
                      installments: [item], // Pass single item for month pill
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // Floating Button to change month
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickMonth,
        label: const Text("Change Month"),
        icon: const Icon(Icons.calendar_month),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }
}