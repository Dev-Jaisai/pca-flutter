import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/installment.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../payments/payment_list_screen.dart';
import '../payments/record_payment_screen.dart';
import 'create_installment_screen.dart';

class InstallmentsScreen extends StatefulWidget {
  final Player player;
  final String? initialFilter; // 'Overdue' or null

  const InstallmentsScreen({
    super.key,
    required this.player,
    this.initialFilter,
  });

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  List<Installment> _installments = [];
  bool _isLoading = true;
  String? _error;
  final df = DateFormat('dd MMM yyyy');

  String _currentFilter = 'All';

  @override
  void initState() {
    super.initState();
    // If passed from Overdue Screen, set filter to 'Overdue'
    if (widget.initialFilter != null) {
      _currentFilter = widget.initialFilter!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final cached = await DataManager().getInstallmentsForPlayer(widget.player.id);
    if (cached.isNotEmpty) {
      if (mounted) setState(() { _installments = cached; _isLoading = false; });
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final freshData = await DataManager().getInstallmentsForPlayer(widget.player.id, forceRefresh: true);
      if (mounted) setState(() { _installments = freshData; _isLoading = false; _error = null; });
    } catch (e) {
      if (mounted && _installments.isEmpty) {
        setState(() { _isLoading = false; _error = e.toString(); });
      }
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateInstallmentScreen(player: widget.player)),
    );
    if (created == true) {
      DataManager().invalidatePlayerDetails(widget.player.id);
      _loadData();
    }
  }

  // ✅ Updated Bulk Payment to take amount dynamically
  void _openBulkPayment(double maxPayableAmount) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_currentFilter == 'Overdue' ? "Pay Overdue Amount" : "Pay Bulk Amount"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Payable: ₹${maxPayableAmount.toStringAsFixed(0)}",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Enter Amount (₹)", border: OutlineInputBorder(), prefixText: "₹ "),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              _currentFilter == 'Overdue'
                  ? "Payment will strictly clear OVERDUE installments first."
                  : "Payment will clear oldest dues first.",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) return;

              if (amount > maxPayableAmount) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Amount cannot exceed total payable")));
                return;
              }

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Processing ₹$amount...")));

              try {
                // ✅ Decide API based on Filter
                if (_currentFilter == 'Overdue') {
                  await ApiService.payOverdue(playerId: widget.player.id, amount: amount);
                } else {
                  await ApiService.payUnpaid(playerId: widget.player.id, amount: amount);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful!")));
                  DataManager().invalidatePlayerDetails(widget.player.id);
                  _loadData();
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            child: const Text("Pay"),
          )
        ],
      ),
    );
  }

  // ✅ STRICT FILTER LOGIC
  List<Installment> _getFilteredList() {
    if (_currentFilter == 'Overdue') {
      final now = DateTime.now();
      // Reset to start of today to match backend logic strictly
      final today = DateTime(now.year, now.month, now.day);

      return _installments.where((it) {
        final double remaining = (it.amount ?? 0) - (it.paidAmount ?? 0);

        // Strict Check: Due Date MUST be BEFORE today (not including today)
        // Also status must NOT be PAID
        final bool isPaid = (it.status ?? '').toUpperCase() == 'PAID';

        return remaining > 0 &&
            !isPaid &&
            it.dueDate != null &&
            it.dueDate!.isBefore(today);
      }).toList();
    }
    return _installments;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF5F7FA);

    // ✅ Get Only Filtered Items
    final displayList = _getFilteredList();

    // ✅ Calculate Total ONLY for Displayed Items
    double totalPendingOnScreen = 0;
    for (var i in displayList) {
      double total = i.amount ?? 0;
      double paid = i.paidAmount ?? 0;
      totalPendingOnScreen += (total - paid);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              _currentFilter == 'Overdue' ? 'Overdue Installments Only' : 'All History',
              style: TextStyle(fontSize: 12, color: _currentFilter == 'Overdue' ? Colors.red : Colors.grey),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          // ✅ Toggle Button
          TextButton.icon(
            onPressed: () {
              setState(() {
                _currentFilter = _currentFilter == 'Overdue' ? 'All' : 'Overdue';
              });
            },
            icon: Icon(_currentFilter == 'Overdue' ? Icons.list : Icons.warning, size: 18),
            label: Text(_currentFilter == 'Overdue' ? "Show All" : "Show Overdue"),
          ),

          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_circle_outline, color: Colors.deepPurple, size: 28),
            ),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Column(
        children: [
          // ✅ TOTAL HEADER
          if (totalPendingOnScreen > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _currentFilter == 'Overdue' ? "Total Overdue" : "Total Pending",
                          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "₹${totalPendingOnScreen.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.redAccent),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openBulkPayment(totalPendingOnScreen),
                    icon: const Icon(Icons.payments, size: 18),
                    label: Text(_currentFilter == 'Overdue' ? "Pay Overdue" : "Pay Bulk"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

          // ✅ LIST
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: displayList.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                    const SizedBox(height: 16),
                    Text(
                        _currentFilter == 'Overdue' ? 'No overdue items!' : 'No installments.',
                        style: TextStyle(color: Colors.grey.shade600)
                    ),
                    if (_currentFilter == 'Overdue')
                      TextButton(
                        onPressed: () => setState(() => _currentFilter = 'All'),
                        child: const Text("View Full History"),
                      )
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                itemCount: displayList.length,
                itemBuilder: (context, i) {
                  return _buildInstallmentCard(displayList[i]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentCard(Installment it) {
    final double total = it.amount ?? 0.0;
    final double paid = it.paidAmount ?? 0.0;
    final double remaining = total - paid;
    final bool isPaid = remaining <= 0;
    final bool isOverdue = !isPaid && it.dueDate != null && it.dueDate!.isBefore(DateTime.now());

    String statusText = (it.status ?? 'PENDING').replaceAll('_', ' ');
    Color statusColor = Colors.blue;
    Color statusBg = Colors.blue.shade50;

    if (isPaid) {
      statusText = "PAID";
      statusColor = Colors.green;
      statusBg = Colors.green.shade50;
    } else if (isOverdue) {
      statusText = "OVERDUE";
      statusColor = Colors.red;
      statusBg = Colors.red.shade50;
    } else if (paid > 0) {
      statusText = "PARTIAL";
      statusColor = Colors.orange;
      statusBg = Colors.orange.shade50;
    }

    final periodLabel = '${it.periodMonth}/${it.periodYear}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  periodLabel,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Paid', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${paid.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Due Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        it.dueDate != null ? df.format(it.dueDate!) : '—',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isOverdue ? Colors.red : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentsListScreen(
                            installmentId: it.id,
                            remainingAmount: remaining,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.history, size: 18, color: Colors.grey),
                    label: const Text('History'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPaid
                        ? null
                        : () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecordPaymentScreen(
                            installmentId: it.id,
                            remainingAmount: remaining,
                          ),
                        ),
                      );
                      if (result == true) {
                        DataManager().invalidatePlayerDetails(widget.player.id);
                        _loadData();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_card, size: 18),
                    label: const Text('Record'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}