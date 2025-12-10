import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../utils/event_bus.dart';
import '../payments/payment_list_screen.dart';
import 'installments_screen.dart';

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
  final df = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _currentFilter = widget.initialFilter!;
    }
    _loadFromCache();
    _loadAllData();
  }

  Future<void> _loadFromCache() async {
    final cached = await DataManager().getCachedAllInstallments();
    if (cached != null && cached.isNotEmpty) {
      if (mounted) setState(() => _allItems = cached);
    }
  }

  Future<void> _loadAllData() async {
    if (_allItems.isEmpty) setState(() => _isLoading = true);
    try {
      final list = await ApiService.fetchAllInstallmentsSummary(page: 0, size: 2000);
      await DataManager().saveAllInstallments(list);
      if (mounted) {
        setState(() {
          _allItems = list;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 1. FILTER PICKER: MONTH/YEAR DROPDOWNS (As requested for filtering) ---
  Future<DateTime?> _showMonthYearPicker(DateTime initial) async {
    int selectedYear = initial.year;
    int selectedMonth = initial.month;

    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Select Month & Year"),
              content: SizedBox(
                width: 300,
                height: 80,
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedMonth,
                        decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                        items: List.generate(12, (index) {
                          int month = index + 1;
                          String name = DateFormat('MMM').format(DateTime(2024, month));
                          return DropdownMenuItem(value: month, child: Text(name));
                        }),
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => selectedMonth = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedYear,
                        decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                        items: List.generate(11, (index) {
                          int year = 2020 + index;
                          return DropdownMenuItem(value: year, child: Text(year.toString()));
                        }),
                        onChanged: (val) {
                          if (val != null) setStateDialog(() => selectedYear = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text("Select"),
                  onPressed: () {
                    Navigator.of(context).pop(DateTime(selectedYear, selectedMonth, 1));
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickMonthForFilter() async {
    final picked = await _showMonthYearPicker(_selectedMonth);
    if (picked != null) {
      setState(() => _selectedMonth = picked);
    }
  }

  // --- 2. EXTEND DATE PICKER: STANDARD CALENDAR (As requested for Extending) ---
  Future<void> _showExtendDialog(int installmentId, DateTime? currentDueDate) async {
    DateTime? selectedDate;
    final now = DateTime.now();
    // Default to start from current due date or tomorrow
    final initialDate = (currentDueDate != null && currentDueDate.isAfter(now))
        ? currentDueDate
        : now.add(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setStateDialog) {
            return AlertDialog(
              title: const Text('Extend Due Date'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pick a new due date from the calendar.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      // SHOW CALENDAR PICKER HERE
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate ?? initialDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        helpText: 'Select New Due Date',
                      );

                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null ? 'Pick Date' : df.format(selectedDate!),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: selectedDate == null ? Colors.grey : Colors.black87
                            ),
                          ),
                          const Icon(Icons.calendar_month, color: Colors.deepPurple),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedDate == null ? null : () async {
                    Navigator.pop(dialogContext); // Close dialog
                    try {
                      await ApiService.extendInstallmentDate(installmentId: installmentId, newDate: selectedDate!);
                      EventBus().fire(PlayerEvent('installment_updated'));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated to ${df.format(selectedDate!)}')));
                        _loadAllData();
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FILTER LOGIC ---
  // ... inside _getFilteredItems ...
  List<PlayerInstallmentSummary> _getFilteredItems() {
    String status(PlayerInstallmentSummary p) => p.status.toUpperCase().replaceAll('_', ' ').trim();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    // Define Next Month
    final nextMonthDate = DateTime(now.year, now.month + 1, 1);
    final nextMonth = nextMonthDate.month;
    final nextYear = nextMonthDate.year;

    if (_currentFilter == 'All') return _allItems;

    // 1. Upcoming (Next Month)
    if (_currentFilter == 'Upcoming') {
      return _allItems.where((p) {
        if (p.dueDate == null) return false;
        if (status(p) == 'PAID') return false;

        return p.dueDate!.year == nextYear &&
            p.dueDate!.month == nextMonth;
      }).toList();
    }

    // 2. Overdue
    if (_currentFilter == 'Overdue') {
      return _allItems.where((p) {
        if (p.dueDate == null) return false;
        if (status(p) == 'PAID') return false;
        return p.dueDate!.isBefore(startOfToday);
      }).toList();
    }

    // 3. Due (Month) - Defaults to current month, or selected from calendar
    if (_currentFilter == 'Due (Month)') {
      return _allItems.where((p) {
        if (p.dueDate == null) return false;
        if (status(p) == 'PAID') return false;
        return p.dueDate!.year == _selectedMonth.year &&
            p.dueDate!.month == _selectedMonth.month;
      }).toList();
    }

    // Standard Filters (Pending global, etc.)
    // Note: If you want 'Pending' to still mean Global 0 Paid, keep it:
    if (_currentFilter == 'Pending') {
      return _allItems.where((p) => p.totalPaid == 0).toList();
    }

    return _allItems.where((p) => status(p) == _currentFilter.toUpperCase()).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PAID': return Colors.green;
      case 'PARTIALLY_PAID': return Colors.orange;
      case 'PENDING': return Colors.blue;
      case 'OVERDUE': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _navigateToPlayerDetails(PlayerInstallmentSummary p) {
    final player = Player(id: p.playerId, name: p.playerName, phone: p.phone ?? '', group: p.groupName ?? '');
    Navigator.push(context, MaterialPageRoute(builder: (_) => InstallmentsScreen(player: player)))
        .then((_) => _loadAllData());
  }

  Future<void> _openPayments(PlayerInstallmentSummary row) async {
    if (row.installmentId != null) {
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => PaymentsListScreen(installmentId: row.installmentId!, remainingAmount: row.remaining)));
      _loadAllData();
    }
  }

  Widget _buildRow(PlayerInstallmentSummary p) {
    Color statusColor = _getStatusColor(p.status);
    final isPaid = p.status == 'PAID';
    final dueText = p.dueDate != null ? df.format(p.dueDate!) : '—';
    final paidDateText = p.lastPaymentDate != null ? df.format(p.lastPaymentDate!) : '—';

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final isOverdue = !isPaid && p.dueDate != null && p.dueDate!.isBefore(startOfToday);

    if (isOverdue) statusColor = Colors.red;

    final total = p.installmentAmount ?? 0.0;
    final paid = p.totalPaid;
    final progress = total == 0 ? 0.0 : (paid / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.playerName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text("${p.groupName ?? ''}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ),
                          if (!isPaid)
                            SizedBox(
                              height: 30, width: 30,
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                                onSelected: (val) {
                                  if (val == 'extend') _showExtendDialog(p.installmentId!, p.dueDate);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'extend', child: Row(children: [
                                    Icon(Icons.edit_calendar, color: Colors.blue, size: 20),
                                    SizedBox(width: 8),
                                    Text('Extend Due Date'),
                                  ])),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Paid: ₹${p.totalPaid.toStringAsFixed(0)}", style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                          Text("Total: ₹${total.toStringAsFixed(0)}", style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(isPaid ? Icons.check_circle : (isOverdue ? Icons.warning_amber_rounded : Icons.calendar_today), size: 18, color: statusColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: isPaid
                                ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Paid: $paidDateText", style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                Text("Due: $dueText", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                              ],
                            )
                                : Text(
                              isOverdue ? "Overdue $dueText" : "Due $dueText",
                              style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (p.installmentId != null)
                            SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: () => _openPayments(p),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text("View / Pay", style: TextStyle(fontSize: 12)),
                              ),
                            ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _getFilteredItems();
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);

    String titleText = 'All Installments (${_currentFilter})';
    if (_currentFilter == 'Due (Month)') {
      titleText = 'Due: ${DateFormat('MMMM yyyy').format(_selectedMonth)}';
    } else if (_currentFilter == 'Upcoming') {
      final next = DateTime.now().add(const Duration(days: 30));
      titleText = 'Upcoming: ${DateFormat('MMMM yyyy').format(next)}';
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          if (_currentFilter == 'Due (Month)')
            IconButton(
              icon: const Icon(Icons.calendar_month, color: Colors.deepPurple),
              onPressed: _pickMonthForFilter,
              tooltip: "Select Month",
            ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (String val) => setState(() => _currentFilter = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'Due (Month)', child: Text('Due (Month)')),
              const PopupMenuItem(value: 'Upcoming', child: Text('Upcoming (Next Month)')), // ADDED
              const PopupMenuItem(value: 'Pending', child: Text('Pending (Global)')),
              const PopupMenuItem(value: 'Partially Paid', child: Text('Partially Paid')),
              const PopupMenuItem(value: 'Overdue', child: Text('Overdue')),
              const PopupMenuItem(value: 'Paid', child: Text('Paid')),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text("Error: $_error"))
          : filteredItems.isEmpty
          ? Center(child: Text("No players found for $_currentFilter"))
          : RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          itemCount: filteredItems.length,
          itemBuilder: (ctx, i) => _buildRow(filteredItems[i]),
        ),
      ),
    );
  }
}