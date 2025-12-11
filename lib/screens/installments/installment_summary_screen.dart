// lib/screens/installments/installment_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/player_installment_summary.dart';
import '../payments/payment_list_screen.dart';

class InstallmentSummaryScreen extends StatefulWidget {
  final String? initialMonth;
  final String? initialFilter; // 'all'|'due'|'pending'|'overdue'

  const InstallmentSummaryScreen({super.key, this.initialMonth, this.initialFilter});

  @override
  State<InstallmentSummaryScreen> createState() => _InstallmentSummaryScreenState();
}

class _InstallmentSummaryScreenState extends State<InstallmentSummaryScreen> {
  late String _selectedMonth; // YYYY-MM
  String _filter = 'all';
  bool _loading = true;
  String? _error;
  List<PlayerInstallmentSummary> _items = [];

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<PlayerInstallmentSummary> list;

      // If viewing "Overdue", we usually want GLOBAL overdue (past months).
      // But if the user deliberately picks a month while in "All" or "Due" mode,
      // we fetch that specific month's data.
      if (_filter == 'overdue') {
        list = await ApiService.fetchAllInstallmentsSummary();
      } else {
        list = await ApiService.fetchInstallmentSummary(_selectedMonth);
      }

      final filtered = _applyFilter(list);
      if (mounted) setState(() => _items = filtered);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normStatus(String? s) {
    if (s == null) return '';
    return s.toUpperCase().replaceAll('_', ' ').trim();
  }
  List<PlayerInstallmentSummary> _applyFilter(List<PlayerInstallmentSummary> list) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    switch (_filter) {
      case 'pending':
        return list.where((p) {
          final s = _normStatus(p.status);
          return s == 'PENDING';
        }).toList();

      case 'due':
        return list.where((p) {
          final s = _normStatus(p.status);
          return s == 'PENDING' || s == 'PARTIALLY PAID';
        }).toList();

      case 'overdue':
      // ENHANCED: Include ALL past unpaid installments
        return list.where((p) {
          final s = _normStatus(p.status);
          final isPaid = s == 'PAID';
          final dueDate = p.dueDate;
          return !isPaid && dueDate != null && dueDate.isBefore(startOfToday);
        }).toList();

      case 'all':
      default:
        return list;
    }
  }
  // --- RESTORED: Month Picker Logic ---
  // ... inside _InstallmentSummaryScreenState class ...

  // NEW: Custom Month/Year Picker using Dropdowns
  Future<void> _pickMonth() async {
    final now = DateTime.now();
    // Parse current selection to set initial values in dropdowns
    final parts = _selectedMonth.split('-');
    int currentYear = int.parse(parts[0]);
    int currentMonth = int.parse(parts[1]);

    await showDialog(
      context: context,
      builder: (context) {
        // Local state variables for the dialog
        int tempYear = currentYear;
        int tempMonth = currentMonth;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Select Month"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Year:", style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<int>(
                        value: tempYear,
                        // Generate years from (Current - 5) to (Current + 5)
                        items: List.generate(11, (index) {
                          final y = now.year - 5 + index;
                          return DropdownMenuItem(value: y, child: Text(y.toString()));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => tempYear = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Month Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Month:", style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<int>(
                        value: tempMonth,
                        items: List.generate(12, (index) {
                          final m = index + 1;
                          // Format month name (e.g., "January", "February")
                          final name = DateFormat.MMMM().format(DateTime(2024, m));
                          return DropdownMenuItem(value: m, child: Text(name));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => tempMonth = val);
                        },
                      ),
                    ],
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
                    // Logic: "Internally select data for that month"
                    // We construct "YYYY-MM" which the API uses to fetch the whole month's data
                    final newMonthStr = '$tempYear-${tempMonth.toString().padLeft(2, '0')}';

                    setState(() {
                      _selectedMonth = newMonthStr;
                    });

                    // Refresh data for the new selected month
                    _load();
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ... rest of the code remains the same ...

  void _openPayments(PlayerInstallmentSummary row) {
    if (row.installmentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PaymentsListScreen(installmentId: row.installmentId!, remainingAmount: row.remaining)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No installment exists for this player.')));
    }
  }

  Future<void> _createInstallment(PlayerInstallmentSummary p) async {
    final year = int.parse(_selectedMonth.split('-')[0]);
    final month = int.parse(_selectedMonth.split('-')[1]);
    final amountCtl = TextEditingController(text: p.installmentAmount?.toString() ?? '500');
    DateTime due = DateTime(year, month, 10);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setStateDialog) {
          return AlertDialog(
            title: Text('Create installment for ${p.playerName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  title: Text('Due date: ${DateFormat.yMMMd().format(due)}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx2,
                      initialDate: due,
                      firstDate: DateTime(year - 1),
                      lastDate: DateTime(year + 1),
                    );
                    if (d != null) {
                      due = d;
                      setStateDialog(() {});
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx2, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx2, true), child: const Text('Create')),
            ],
          );
        });
      },
    );

    if (ok != true) return;
    final amount = double.tryParse(amountCtl.text.trim()) ?? double.parse((p.installmentAmount ?? 500).toString());

    try {
      await ApiService.createInstallmentForPlayer(
        playerId: p.playerId,
        periodMonth: month,
        periodYear: year,
        dueDate: due,
        amount: amount,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Installment created')));
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  Widget _buildRow(PlayerInstallmentSummary p) {
    final df = DateFormat('dd MMM yyyy');

    String moneyStr(double? v, {int fractionDigits = 0}) {
      if (v == null) return '—';
      return '₹ ${v.toStringAsFixed(fractionDigits)}';
    }

    Color statusColor(String s) {
      switch (s) {
        case 'PAID': return Colors.green;
        case 'PARTIALLY_PAID':
        case 'PARTIALLY PAID': return Colors.orange;
        case 'PENDING': return Colors.blueGrey;
        case 'OVERDUE': return Colors.red;
        default: return Colors.redAccent;
      }
    }

    final isOverdue = p.dueDate != null && p.dueDate!.isBefore(DateTime.now()) && _normStatus(p.status) != 'PAID';
    final displayStatus = isOverdue && _filter == 'overdue' ? 'OVERDUE' : p.status;
    final displayColor = isOverdue && _filter == 'overdue' ? Colors.red : statusColor(p.status);

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.playerName,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          '${p.groupName ?? ''} • ${p.phone ?? ''}'.trim(),
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: Text('Due: ${p.dueDate != null ? df.format(p.dueDate!) : '—'}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(displayStatus, style: const TextStyle(fontSize: 12, color: Colors.white)),
              backgroundColor: displayColor,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            ),
          ],
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // FITTED BOX FIX: Prevents overflow
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              'Total: ${moneyStr(p.installmentAmount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Flexible(
          child: Text(
            'Paid: ${moneyStr(p.totalPaid)}',
            style: TextStyle(color: Colors.grey[800], fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            'Left: ${p.remaining == null ? '—' : '₹ ${p.remaining!.toStringAsFixed(0)}'}',
            style: TextStyle(color: Colors.grey[800], fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                (p.playerName.isNotEmpty ? p.playerName[0].toUpperCase() : '?'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: leftColumn),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 70, maxWidth: 140),
              child: rightColumn,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                p.installmentId == null
                    ? IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'Create installment', onPressed: () => _createInstallment(p))
                    : IconButton(icon: const Icon(Icons.payment), tooltip: 'View payments', onPressed: () => _openPayments(p)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Title Logic based on Selected Month
    final yearMonthLabel = () {
      final parts = _selectedMonth.split('-');
      final y = int.tryParse(parts[0]) ?? DateTime.now().year;
      final m = int.tryParse(parts[1]) ?? DateTime.now().month;
      return DateFormat.yMMMM().format(DateTime(y, m));
    }();

    String titleText;
    if (_filter == 'overdue') {
      titleText = 'Overdue Payments';
    } else if (_filter == 'due') {
      titleText = '$yearMonthLabel Dues';
    } else if (_filter == 'pending') {
      titleText = '$yearMonthLabel Pending';
    } else {
      titleText = 'Installments — $yearMonthLabel';
    }

    // Only show calendar if NOT in "Global Overdue" mode
    final bool showCalendar = _filter != 'overdue';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          // --- RESTORED: Calendar Icon ---
          if (showCalendar)
            IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickMonth),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _items.isEmpty
          ? const Center(child: Text('No players found'))
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: _items.length,
          itemBuilder: (ctx, i) => _buildRow(_items[i]),
        ),
      ),
    );
  }
}