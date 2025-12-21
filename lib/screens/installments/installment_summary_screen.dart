import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
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
    List<PlayerInstallmentSummary> filteredList = [];

    final parts = _selectedMonth.split('-');
    final selYear = int.parse(parts[0]);
    final selMonth = int.parse(parts[1]);

    filteredList = allData.where((item) {
      if (item.dueDate != null) {
        return item.dueDate!.year == selYear && item.dueDate!.month == selMonth;
      }
      return false;
    }).toList();

    _totalAmount = 0;
    _totalPaid = 0;
    _totalRemaining = 0;
    _totalCount = filteredList.length;

    for (var item in filteredList) {
      _totalAmount += item.installmentAmount ?? 0;
      _totalPaid += item.totalPaid;
      _totalRemaining += item.remaining ?? 0;
    }

    _items = filteredList;
  }

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
              backgroundColor: const Color(0xFF203A43), // Dark Dialog
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.white.withOpacity(0.1))),
              title: const Text("Select Month", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              content: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempMonth,
                      dropdownColor: const Color(0xFF2C5364),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
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
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: tempYear,
                      dropdownColor: const Color(0xFF2C5364),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
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
                  child: Text("Cancel", style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newMonthStr = '$tempYear-${tempMonth.toString().padLeft(2, '0')}';
                    setState(() => _selectedMonth = newMonthStr);
                    Navigator.pop(context);
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  child: const Text("Select", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryHeader() {
    final date = DateTime.parse('$_selectedMonth-01');
    final monthName = DateFormat('MMMM yyyy').format(date);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08), // Glass Effect
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName.toUpperCase(),
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  "Count: $_totalCount",
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(Icons.monetization_on, "Target", _totalAmount, Colors.blueAccent),
              _buildSummaryItem(Icons.check_circle, "Collected", _totalPaid, Colors.greenAccent),
              _buildSummaryItem(Icons.pending, "Pending", _totalRemaining, Colors.orangeAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, double amount, Color color) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.8), size: 22),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Monthly Summary', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _load),
        ],
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),

          // 2. ORBS
          Positioned(
            top: -60, left: -60,
            child: Container(
              height: 220, width: 220,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.cyan.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 90, spreadRadius: 40)]),
            ),
          ),

          // 3. CONTENT
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : Column(
              children: [
                _buildSummaryHeader(),

                Expanded(
                  child: _items.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_view_month, size: 60, color: Colors.white.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text("No records found for this month", style: TextStyle(color: Colors.white.withOpacity(0.5))),
                      ],
                    ),
                  )
                      : RefreshIndicator(
                    onRefresh: _load,
                    color: Colors.cyanAccent,
                    backgroundColor: const Color(0xFF203A43),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final item = _items[i];
                        final player = Player(
                            id: item.playerId ?? 0,
                            name: item.playerName,
                            group: item.groupName ?? '',
                            phone: item.phone ?? ''
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: PlayerSummaryCard(
                            player: player,
                            summary: item,
                            installments: [item],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickMonth,
        label: const Text("Change Month", style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.calendar_month),
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
      ),
    );
  }
}