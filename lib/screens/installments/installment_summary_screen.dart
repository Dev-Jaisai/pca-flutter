// lib/screens/installments/installment_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/player_installment_summary.dart';
import '../payments/payment_list_screen.dart';

class InstallmentSummaryScreen extends StatefulWidget {
  // month format "YYYY-MM" (optional initial)
  final String? initialMonth;

  const InstallmentSummaryScreen({super.key, this.initialMonth});

  @override
  State<InstallmentSummaryScreen> createState() => _InstallmentSummaryScreenState();
}

class _InstallmentSummaryScreenState extends State<InstallmentSummaryScreen> {
  late String _selectedMonth; // YYYY-MM
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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.fetchInstallmentSummary(_selectedMonth);
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMonth() async {
    // Simple month-year picker using showDatePicker limiting to month selection
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
                      setStateDialog(() {}); // refresh due date shown
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
        case 'PAID':
          return Colors.green;
        case 'PARTIALLY_PAID':
          return Colors.orange;
        case 'PENDING':
          return Colors.blueGrey;
        case 'NO_INSTALLMENT':
        default:
          return Colors.redAccent;
      }
    }

    // Left column: name, group, phone
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name (allow long names but ellipsize)
        Text(
          p.playerName,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        // group + phone small line - allow wrap but prefer single line
        Text(
          '${p.groupName ?? ''} • ${p.phone ?? ''}'.trim(),
          style: TextStyle(color: Colors.grey[700], fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        // Due date + status small line (wraps if needed)
        Row(
          children: [
            Flexible(
              child: Text('Due: ${p.dueDate != null ? df.format(p.dueDate!) : '—'}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                p.status,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              backgroundColor: statusColor(p.status),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            ),
          ],
        ),
      ],
    );

    // Right column: amount / paid / left (align end)
    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Amount line
        Flexible(
          child: Text(
            moneyStr(p.installmentAmount),
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(height: 6),
        // Paid / Left - allow these to be small and wrap if necessary
        Flexible(
          child: Text(
            'Paid: ${moneyStr(p.totalPaid)}',
            style: TextStyle(color: Colors.grey[800]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            'Left: ${p.remaining == null ? '—' : '₹ ${p.remaining!.toStringAsFixed(0)}'}',
            style: TextStyle(color: Colors.grey[800]),
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
            // Avatar circle (initial)
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                (p.playerName.isNotEmpty ? p.playerName[0].toUpperCase() : '?'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),

            // Left column expands and takes remaining width
            Expanded(child: leftColumn),

            const SizedBox(width: 8),

            // Right column constrained width so it cannot push beyond screen
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
              child: rightColumn,
            ),

            const SizedBox(width: 8),

            // trailing action
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                p.installmentId == null
                    ? IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Create installment',
                  onPressed: () => _createInstallment(p),
                )
                    : IconButton(
                  icon: const Icon(Icons.payment),
                  tooltip: 'View payments',
                  onPressed: () => _openPayments(p),
                ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Installments — $yearMonthLabel'),
        actions: [
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
