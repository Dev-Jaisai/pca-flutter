import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../utils/event_bus.dart';
import '../payments/payment_list_screen.dart';
import 'installments_screen.dart';

// Helper class to hold grouped data
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
  final df = DateFormat('dd MMM yyyy');
  final chipDateFormat = DateFormat('dd MMM'); // e.g. 02 Sep

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
    _loadFromCache();
    _loadAllData();
  }

  Future<void> _loadFromCache() async {
    final cached = await DataManager().getCachedAllInstallments();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() => _allItems = cached);
    }
  }

  Future<void> _loadAllData() async {
    if (_allItems.isEmpty) setState(() => _isLoading = true);
    try {
      final List<PlayerInstallmentSummary> list =
      await ApiService.fetchAllInstallmentsSummary(page: 0, size: 2000);
      await DataManager().saveAllInstallments(list);
      if (mounted) {
        setState(() {
          _allItems = list;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  // --- Date Picker Logic ---
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
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  // --- 1. EXTEND DATE LOGIC ---
  Future<void> _showExtendDialog(int installmentId, DateTime? currentDueDate) async {
    DateTime? selectedDate;
    final now = DateTime.now();
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
                  const Text('Pick a new due date for this installment.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate ?? initialDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        helpText: 'Select New Due Date',
                      );
                      if (picked != null) setStateDialog(() => selectedDate = picked);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null ? 'Pick Date' : df.format(selectedDate!),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: selectedDate == null ? Colors.grey : Colors.black87),
                          ),
                          const Icon(Icons.calendar_month, color: Colors.deepPurple),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: selectedDate == null
                      ? null
                      : () async {
                    Navigator.pop(dialogContext);
                    try {
                      await ApiService.extendInstallmentDate(
                          installmentId: installmentId,
                          newDate: selectedDate!);
                      EventBus().fire(PlayerEvent('installment_updated'));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Updated to ${df.format(selectedDate!)}')));
                        _loadAllData();
                      }
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')));
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

  // --- 2. INSTALLMENT OPTIONS (Triggered by clicking a chip) ---
  void _showInstallmentOptions(PlayerInstallmentSummary inst) {
    if (inst.installmentId == null) return;

    final isPaid = (inst.status ?? '').toUpperCase() == 'PAID';
    String headerDate = "No Date";
    String headerLabel = "Due Date";

    if (isPaid) {
      headerLabel = "Paid On";
      // Use lastPaymentDate if available, else fall back
      headerDate = inst.lastPaymentDate != null
          ? df.format(inst.lastPaymentDate!)
          : (inst.dueDate != null ? df.format(inst.dueDate!) : 'Completed');
    } else {
      headerLabel = "Due Date";
      headerDate = inst.dueDate != null ? df.format(inst.dueDate!) : 'No Date';
    }

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$headerLabel: $headerDate", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text("Amount: ₹${inst.installmentAmount}  •  Paid: ₹${inst.totalPaid}", style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 24),

                if(!isPaid) // Only show extend option if NOT paid
                  ListTile(
                    leading: const Icon(Icons.edit_calendar, color: Colors.blue),
                    title: const Text("Extend Due Date"),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showExtendDialog(inst.installmentId!, inst.dueDate);
                    },
                  ),

                ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.green),
                  title: const Text("View / Pay This Installment"),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Navigate to payments just for this installment
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PaymentsListScreen(
                                installmentId: inst.installmentId!,
                                remainingAmount: inst.remaining)));
                  },
                ),
              ],
            ),
          );
        }
    );
  }


  // --- 3. PAY DIALOG FUNCTION ---
  Future<void> _showPayDialog(PlayerConsolidatedSummary player) async {
    final amountCtl = TextEditingController(text: player.totalRemaining.toStringAsFixed(0));
    bool paying = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Pay for ${player.playerName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('This payment will be allocated to the oldest dues first.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder(), prefixText: '₹ '),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: paying ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: paying ? null : () async {
                  final amt = double.tryParse(amountCtl.text) ?? 0.0;
                  if (amt <= 0) return;
                  setDialogState(() => paying = true);
                  try {
                    await ApiService.payOverdue(playerId: player.playerId, amount: amt);
                    EventBus().fire(PlayerEvent('payment_recorded'));
                    EventBus().fire(PlayerEvent('installment_updated'));
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Recorded Successfully!')));
                      _loadAllData();
                    }
                  } catch (e) {
                    if (mounted) {
                      setDialogState(() => paying = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: paying ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Pay Now'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Filtering & Grouping Logic ---
  List<PlayerInstallmentSummary> _getFilteredRawItems() {
    if (_currentFilter == 'All') return _allItems;

    if (_currentFilter == 'Upcoming') {
      final sel = _selectedMonth;
      return _allItems.where((p) {
        if (p.dueDate == null) return false;
        final st = (p.status ?? '').toUpperCase().replaceAll('_', ' ').trim();
        if (st == 'PAID') return false;
        return p.dueDate!.year == sel.year && p.dueDate!.month == sel.month;
      }).toList();
    }

    if (_currentFilter == 'Due (Month)') {
      return _allItems.where((p) {
        if (p.dueDate == null) return false;
        final st = (p.status ?? '').toUpperCase().replaceAll('_', ' ').trim();
        if (st == 'PAID') return false;
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
      summary.installments.sort((a, b) {
        if(a.dueDate == null) return 1;
        if(b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });
    }

    final resultList = groupedMap.values.toList();
    resultList.sort((a, b) => b.totalRemaining.compareTo(a.totalRemaining));

    return resultList;
  }

  void _navigateToPlayerDetails(PlayerConsolidatedSummary summary) {
    final player = Player(
        id: summary.playerId,
        name: summary.playerName,
        phone: summary.phone,
        group: summary.groupName);
    Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => InstallmentsScreen(player: player)))
        .then((_) => _loadAllData());
  }

  Color _getGroupStatusColor(PlayerConsolidatedSummary summary) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    bool hasOverdue = summary.installments.any((i) =>
    i.dueDate != null &&
        i.dueDate!.isBefore(startOfToday) &&
        (i.status?.toUpperCase() != 'PAID')
    );

    if (hasOverdue) return Colors.red;
    if (summary.totalRemaining <= 0 && summary.totalAmount > 0) return Colors.green;
    return Colors.blue;
  }

  Widget _buildGroupedCard(PlayerConsolidatedSummary summary) {
    final statusColor = _getGroupStatusColor(summary);
    final count = summary.installments.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border(left: BorderSide(color: statusColor, width: 6)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToPlayerDetails(summary),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                          Text(summary.playerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                          const SizedBox(height: 2),
                          Text(summary.groupName, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Items: $count",
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildFinanceColumn("Total", "₹${summary.totalAmount.toStringAsFixed(0)}", Colors.black87),
                    _buildFinanceColumn("Paid", "₹${summary.totalPaid.toStringAsFixed(0)}", Colors.green[700]!),
                    _buildFinanceColumn("Remaining", "₹${summary.totalRemaining.toStringAsFixed(0)}", Colors.red[700]!),
                  ],
                ),

                const SizedBox(height: 16),

                // In the chips section of _buildGroupedCard method
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: summary.installments.take(5).map<Widget>((inst) {
                    final isPaid = (inst.status ?? '').toUpperCase() == 'PAID';
                    final isOverdue = !isPaid && inst.dueDate != null && inst.dueDate!.isBefore(DateTime.now());

                    String dueDateLabel = 'N/A';
                    String paidDateLabel = '';

                    // Get due date text
                    if (inst.dueDate != null) {
                      dueDateLabel = chipDateFormat.format(inst.dueDate!);
                    }

                    // Get paid date text if paid
                    if (isPaid && inst.lastPaymentDate != null) {
                      paidDateLabel = ' ✅ ${chipDateFormat.format(inst.lastPaymentDate!)}';
                    }

                    Color chipColor = Colors.grey.shade100;
                    Color textColor = Colors.grey.shade800;

                    if (isPaid) {
                      chipColor = Colors.green.shade50;
                      textColor = Colors.green.shade800;
                    } else if (isOverdue) {
                      chipColor = Colors.red.shade50;
                      textColor = Colors.red.shade800;
                    }

                    return InkWell(
                      onTap: () => _showInstallmentOptions(inst),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: chipColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: chipColor.withOpacity(1), width: 0.5)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Due date with strikethrough if paid
                            Text(
                              dueDateLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                                decoration: isPaid ? TextDecoration.lineThrough : TextDecoration.none,
                                decorationColor: textColor,
                                decorationThickness: 2,
                              ),
                            ),
                            // Paid date if available
                            if (paidDateLabel.isNotEmpty)
                              Text(
                                paidDateLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList()
                    ..add(summary.installments.length > 5
                        ? Text("+${summary.installments.length - 5} more", style: const TextStyle(fontSize: 10, color: Colors.grey))
                        : const SizedBox.shrink()),
                ),
                const SizedBox(height: 16),

                // --- BUTTONS ---
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _navigateToPlayerDetails(summary),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text("View Details"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: summary.totalRemaining > 0
                            ? () => _showPayDialog(summary)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text("Pay Now"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinanceColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedItems = _getGroupedItems();

    String titleText = 'All Installments';
    if (_currentFilter == 'Due (Month)') {
      titleText = 'Due: ${DateFormat('MMM yyyy').format(_selectedMonth)}';
    } else if (_currentFilter == 'Upcoming') {
      titleText = 'Upcoming: ${DateFormat('MMM yyyy').format(_selectedMonth)}';
    } else if (_currentFilter != 'All') {
      titleText = '$_currentFilter List';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(titleText),
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
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Installments')),
              const PopupMenuItem(value: 'Due (Month)', child: Text('Due (Specific Month)')),
              const PopupMenuItem(value: 'Upcoming', child: Text('Upcoming')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'Paid', child: Text('Paid Players')),
              const PopupMenuItem(value: 'Pending', child: Text('Pending Players')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text("Error: $_error"))
          : groupedItems.isEmpty
          ? const Center(child: Text("No records found", style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 80),
          itemCount: groupedItems.length,
          itemBuilder: (ctx, i) {
            return _buildGroupedCard(groupedItems[i]);
          },
        ),
      ),
    );
  }
}