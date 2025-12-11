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

  // Statistics
  double _totalAmount = 0;
  double _totalPaid = 0;
  double _totalRemaining = 0;
  int _totalCount = 0;
  int _overdueCount = 0;

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

      if (_filter == 'overdue') {
        list = await ApiService.fetchAllInstallmentsSummary();
      } else {
        list = await ApiService.fetchInstallmentSummary(_selectedMonth);
      }

      final filtered = _applyFilter(list);
      _calculateStats(filtered);

      if (mounted) setState(() => _items = filtered);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _calculateStats(List<PlayerInstallmentSummary> items) {
    _totalAmount = 0;
    _totalPaid = 0;
    _totalRemaining = 0;
    _totalCount = items.length;
    _overdueCount = 0;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (var item in items) {
      _totalAmount += item.installmentAmount ?? 0;
      _totalPaid += item.totalPaid ?? 0;
      _totalRemaining += item.remaining ?? 0;

      final s = _normStatus(item.status);
      final isPaid = s == 'PAID';
      final dueDate = item.dueDate;
      if (!isPaid && dueDate != null && dueDate.isBefore(startOfToday)) {
        _overdueCount++;
      }
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                "Select Month",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Year",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        DropdownButton<int>(
                          value: tempYear,
                          underline: const SizedBox(),
                          items: List.generate(11, (index) {
                            final y = now.year - 5 + index;
                            return DropdownMenuItem(
                              value: y,
                              child: Text(
                                y.toString(),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => tempYear = val);
                          },
                          borderRadius: BorderRadius.circular(12),
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Month Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Month",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        DropdownButton<int>(
                          value: tempMonth,
                          underline: const SizedBox(),
                          items: List.generate(12, (index) {
                            final m = index + 1;
                            final name = DateFormat.MMMM().format(DateTime(2024, m));
                            return DropdownMenuItem(
                              value: m,
                              child: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => tempMonth = val);
                          },
                          borderRadius: BorderRadius.circular(12),
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cancel",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newMonthStr = '$tempYear-${tempMonth.toString().padLeft(2, '0')}';
                    setState(() {
                      _selectedMonth = newMonthStr;
                    });
                    _load();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Select",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openPayments(PlayerInstallmentSummary row) {
    if (row.installmentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentsListScreen(
            installmentId: row.installmentId!,
            remainingAmount: row.remaining,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No installment exists for this player.'),
          backgroundColor: Colors.orange.shade600,
        ),
      );
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Create Installment',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.playerName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtl,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
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
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Colors.deepPurple.shade600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                DateFormat.yMMMd().format(due),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx2, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create',
                  style: TextStyle(color: Colors.white),
                ),
              ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Installment created successfully'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      await _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Create failed: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _filter = value);
          _load();
        }
      },
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : Colors.grey.shade600,
      ),
      selectedColor: Colors.deepPurple.shade600,
      backgroundColor: Colors.grey.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildStatsCard() {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade600,
            Colors.purple.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.shade300.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getMonthLabel(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_totalCount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem(
                'Total Amount',
                money.format(_totalAmount),
                Icons.account_balance_wallet,
              ),
              _buildStatItem(
                'Total Paid',
                money.format(_totalPaid),
                Icons.payment,
                color: Colors.green.shade300,
              ),
              _buildStatItem(
                'Pending',
                money.format(_totalRemaining),
                Icons.pending_actions,
                color: Colors.orange.shade300,
              ),
            ],
          ),
          if (_overdueCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade600.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade400.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 16,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_overdueCount overdue payment${_overdueCount > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.red.shade100,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: color ?? Colors.white.withOpacity(0.8),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  String _getMonthLabel() {
    if (_filter == 'overdue') return 'Overdue Payments';

    final parts = _selectedMonth.split('-');
    final y = int.tryParse(parts[0]) ?? DateTime.now().year;
    final m = int.tryParse(parts[1]) ?? DateTime.now().month;
    return DateFormat.yMMMM().format(DateTime(y, m));
  }

  Widget _buildPlayerCard(PlayerInstallmentSummary p) {
    final df = DateFormat('dd MMM yyyy');
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    String moneyStr(double? v) {
      if (v == null) return '—';
      return money.format(v);
    }

    Color getStatusColor(String s) {
      switch (s) {
        case 'PAID': return Colors.green.shade600;
        case 'PARTIALLY_PAID':
        case 'PARTIALLY PAID': return Colors.orange.shade600;
        case 'PENDING': return Colors.blueGrey.shade600;
        case 'OVERDUE': return Colors.red.shade600;
        default: return Colors.redAccent.shade400;
      }
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final isOverdue = p.dueDate != null && p.dueDate!.isBefore(startOfToday) && _normStatus(p.status) != 'PAID';
    final displayStatus = isOverdue ? 'OVERDUE' : p.status;
    final statusColor = getStatusColor(displayStatus);
    final progress = p.installmentAmount != null && p.installmentAmount! > 0
        ? (p.totalPaid ?? 0) / p.installmentAmount!
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: p.installmentId != null ? () => _openPayments(p) : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Top row: Avatar, name, and status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade400,
                            Colors.purple.shade400,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          p.playerName.isNotEmpty ? p.playerName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Player info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.playerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.deepOrangeAccent,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.groupName ?? 'No group',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (p.phone != null && p.phone!.isNotEmpty)
                            Text(
                              p.phone!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        displayStatus.replaceAll('_', ' '),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Due date and progress
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Due: ${p.dueDate != null ? df.format(p.dueDate!) : 'Not set'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (progress > 0)
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: progress >= 1 ? Colors.green.shade600 : Colors.orange.shade600,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Progress bar
                if (p.installmentAmount != null && p.installmentAmount! > 0)
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1 ? Colors.green.shade400 : Colors.orange.shade400,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 6,
                  ),

                const SizedBox(height: 16),

                // Amount row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildAmountChip(
                      'Total',
                      moneyStr(p.installmentAmount),
                      Icons.currency_rupee,
                      Colors.blue.shade600,
                    ),
                    _buildAmountChip(
                      'Paid',
                      moneyStr(p.totalPaid),
                      Icons.check_circle,
                      Colors.green.shade600,
                    ),
                    _buildAmountChip(
                      'Remaining',
                      moneyStr(p.remaining),
                      Icons.pending,
                      Colors.orange.shade600,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openPayments(p),
                        icon: Icon(
                          Icons.receipt_long,
                          size: 18,
                          color: Colors.grey.shade700,
                        ),
                        label: Text(
                          p.installmentId == null ? 'No Payments' : 'View Payments',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (p.installmentId == null)
                      ElevatedButton.icon(
                        onPressed: () => _createInstallment(p),
                        icon: const Icon(Icons.add_circle, size: 18),
                        label: const Text('Create'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
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

  Widget _buildAmountChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade50,
                    Colors.deepPurple.shade100.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.deepPurple.shade100, width: 2),
              ),
              child: Icon(
                Icons.people,
                size: 70,
                color: Colors.deepPurple.shade400,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _filter == 'overdue' ? 'No Overdue Payments' : 'No Installments Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _filter == 'overdue'
                  ? 'Great! All payments are up to date.'
                  : 'No players found for the selected month and filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: Column(
        children: [
          // Stats Card (only show when not loading and not overdue filter)
          if (!_loading && _filter != 'overdue' && _items.isNotEmpty)
            _buildStatsCard(),

          // Filter chips
          if (!_loading && _items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', Icons.all_inclusive),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', 'pending', Icons.pending),
                    const SizedBox(width: 8),
                    _buildFilterChip('Due', 'due', Icons.schedule),
                    const SizedBox(width: 8),
                    _buildFilterChip('Overdue', 'overdue', Icons.warning),
                  ],
                ),
              ),
            ),

          // Main content
          Expanded(
            child: _loading
                ? Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple.shade600,
                strokeWidth: 2.5,
              ),
            )
                : _error != null
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
                : _items.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _load,
              color: Colors.deepPurple.shade600,
              backgroundColor: Colors.white,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_filter != 'overdue')
                    const SizedBox(height: 8),
                  ..._items.map((player) => _buildPlayerCard(player)),
                  const SizedBox(height: 80), // Space for scroll
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _filter != 'overdue'
          ? FloatingActionButton.extended(
        onPressed: _pickMonth,
        backgroundColor: Colors.deepPurple.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        icon: const Icon(Icons.calendar_today, size: 24),
        label: const Text(
          'Change Month',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      )
          : null,
    );
  }
}