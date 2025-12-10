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

      // ---------------------------------------------------------
      // FIX IS HERE:
      // If we want OVERDUE, we must ignore the month and fetch ALL data.
      // Otherwise, we fetch the specific month.
      // ---------------------------------------------------------
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
      // Checks strictly before TODAY (ignoring time)
        final startOfToday = DateTime(now.year, now.month, now.day);
        return list.where((p) {
          final s = _normStatus(p.status);
          final isPaid = s == 'PAID';
          final dueDate = p.dueDate;
          // Return items that are NOT Paid AND due date is before today
          return !isPaid && dueDate != null && dueDate.isBefore(startOfToday);
        }).toList();

      case 'all':
      default:
        return list;
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final initial = DateTime(int.parse(_selectedMonth.split('-')[0]), int.parse(_selectedMonth.split('-')[1]));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Select month',
      fieldLabelText: 'Month',
      initialEntryMode: DatePickerEntryMode.calendar,
    );

    if (picked != null) {
      final newMonth = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      setState(() => _selectedMonth = newMonth);
      // If user picks a month, we should probably switch back to 'all' or 'due' mode
      // if they were in 'overdue' mode, but for now we just reload:
      await _load();
    }
  }

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
        case 'OVERDUE': return Colors.red; // Added specific Overdue color if API sends it
        default: return Colors.redAccent;
      }
    }

    // Dynamic coloring for Overdue status (calculated on client side)
    final isOverdue = p.dueDate != null && p.dueDate!.isBefore(DateTime.now()) && _normStatus(p.status) != 'PAID';
    final displayStatus = isOverdue && _filter == 'overdue' ? 'OVERDUE' : p.status;
    final displayColor = isOverdue && _filter == 'overdue' ? Colors.red : statusColor(p.status);

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.playerName, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text('${p.groupName ?? ''} • ${p.phone ?? ''}'.trim(), style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
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
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(moneyStr(p.installmentAmount), style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
                  const SizedBox(height: 6),
                  Flexible(child: Text('Paid: ${moneyStr(p.totalPaid)}', style: TextStyle(color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
                  const SizedBox(height: 4),
                  Flexible(child: Text('Left: ${p.remaining == null ? '—' : '₹ ${p.remaining!.toStringAsFixed(0)}'}', style: TextStyle(color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
                ],
              ),
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
    final yearMonthLabel = () {
      final parts = _selectedMonth.split('-');
      final y = int.tryParse(parts[0]) ?? DateTime.now().year;
      final m = int.tryParse(parts[1]) ?? DateTime.now().month;
      return DateFormat.yMMMM().format(DateTime(y, m));
    }();

    final filterLabel = {
      'all': '',
      'pending': ' — Pending',
      'due': ' — Due',
      'overdue': ' — All Overdue',
    }[_filter] ?? '';

    // Hide calendar if we are looking at All Overdue items
    final bool showCalendar = _filter != 'overdue';

    return Scaffold(
      appBar: AppBar(
        // If overdue, show generic title, otherwise show Month
        title: Text(_filter == 'overdue' ? 'Overdue Payments' : 'Installments — $yearMonthLabel$filterLabel'),
        actions: [
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