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
  final String? initialFilter;

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

  // ✅ NEW: To manage Year Selection
  List<int> _availableYears = [];
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _currentFilter = widget.initialFilter!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    final cached = await DataManager().getInstallmentsForPlayer(widget.player.id);
    if (cached.isNotEmpty) {
      _processData(cached);
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final freshData = await DataManager().getInstallmentsForPlayer(widget.player.id, forceRefresh: true);
      _processData(freshData);
    } catch (e) {
      if (mounted && _installments.isEmpty) {
        setState(() { _isLoading = false; _error = e.toString(); });
      }
    }
  }

  // ✅ NEW: Extract Years and Sort Data
  void _processData(List<Installment> list) {
    if (!mounted) return;

    // 1. Sort Descending
    list.sort((a, b) {
      int yearComp = (b.periodYear ?? 0).compareTo(a.periodYear ?? 0);
      if (yearComp != 0) return yearComp;
      return (b.periodMonth ?? 0).compareTo(a.periodMonth ?? 0);
    });

    // 2. Extract Unique Years
    final years = list.map((e) => e.periodYear ?? DateTime.now().year).toSet().toList();
    years.sort((a, b) => b.compareTo(a)); // Newest year first

    setState(() {
      _installments = list;
      _availableYears = years;

      // Select the first available year if current selection is invalid
      if (_availableYears.isNotEmpty && !_availableYears.contains(_selectedYear)) {
        _selectedYear = _availableYears.first;
      }
      _isLoading = false;
      _error = null;
    });
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
  }void _openBulkPayment(double maxPayableAmount) {
    final amountCtl = TextEditingController();
    final methodCtl = TextEditingController();
    final refCtl = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8), // Background dimming
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent, // Custom Background sathi transparent
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F2027), // Deep Black-Blue
                Color(0xFF203A43), // Slate
                Color(0xFF2C5364), // Teal-Dark
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER ---
                  Text(
                    _currentFilter == 'Overdue' ? "PAY OVERDUE" : "BULK PAYMENT",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "₹${maxPayableAmount.toStringAsFixed(0)}",
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                        shadows: [Shadow(color: Colors.cyanAccent.withOpacity(0.6), blurRadius: 15)]
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text("Total Payable", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- INPUTS ---
                  TextField(
                    controller: amountCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    decoration: _neonInputDecoration("Enter Amount", Icons.attach_money),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: methodCtl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _neonInputDecoration("Payment Method (e.g. Cash)", Icons.payment),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: refCtl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _neonInputDecoration("Reference / Note", Icons.note_alt_outlined),
                  ),

                  const SizedBox(height: 30),

                  // --- BUTTONS ---
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text("CANCEL", style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                              boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 10)]
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              final amount = double.tryParse(amountCtl.text);
                              final method = methodCtl.text.trim().isEmpty ? null : methodCtl.text.trim();
                              final ref = refCtl.text.trim().isEmpty ? null : refCtl.text.trim();

                              if (amount == null || amount <= 0) return;
                              if (amount > maxPayableAmount) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Amount cannot exceed displayed dues"), backgroundColor: Colors.red)
                                );
                                return;
                              }

                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Processing ₹$amount..."), backgroundColor: Colors.blueAccent)
                              );

                              try {
                                if (_currentFilter == 'Overdue') {
                                  await ApiService.payOverdue(
                                      playerId: widget.player.id,
                                      amount: amount,
                                      paymentMethod: method,
                                      reference: ref
                                  );
                                } else {
                                  await ApiService.payUnpaid(
                                      playerId: widget.player.id,
                                      amount: amount,
                                      paymentMethod: method,
                                      reference: ref
                                  );
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("Payment Successful!"), backgroundColor: Colors.green)
                                  );
                                  DataManager().invalidatePlayerDetails(widget.player.id);
                                  _loadData();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.redAccent)
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: const Text("CONFIRM PAYMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
// --- HELPER: NEON INPUT DECORATION ---
  InputDecoration _neonInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      prefixIcon: Icon(icon, color: Colors.cyanAccent.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 2), // GLOW EFFECT
      ),
    );
  }
  // ✅ FILTER LOGIC: Apply Overdue Filter AND Year Filter
  List<Installment> _getFilteredList() {
    return _installments.where((it) {
      // 1. Year Filter
      if (it.periodYear != _selectedYear) return false;

      // 2. Overdue Filter (if active)
      if (_currentFilter == 'Overdue') {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final double remaining = (it.amount ?? 0) - (it.paidAmount ?? 0);
        final bool isPaid = (it.status ?? '').toUpperCase() == 'PAID';

        return remaining > 0 && !isPaid && it.dueDate != null && it.dueDate!.isBefore(today);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF5F7FA);
    final displayList = _getFilteredList();

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
              _currentFilter == 'Overdue' ? 'Overdue Installments' : 'History',
              style: TextStyle(fontSize: 12, color: _currentFilter == 'Overdue' ? Colors.red : Colors.grey),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _currentFilter = _currentFilter == 'Overdue' ? 'All' : 'Overdue'),
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

          // ✅ NEW: Year Selection Chips
          if (_availableYears.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.white,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableYears.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final year = _availableYears[index];
                  final isSelected = year == _selectedYear;

                  return ChoiceChip(
                    label: Text(year.toString()),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _selectedYear = year);
                      }
                    },
                    selectedColor: Colors.deepPurple,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold
                    ),
                  );
                },
              ),
            ),

          // Total Header
          if (totalPendingOnScreen > 0)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Added margin
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12), // Rounded corners
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Total Pending ($_selectedYear)", // Show year in label
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
                    label: const Text("Pay Now"),
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

          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: displayList.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('No data for $_selectedYear', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                itemCount: displayList.length,
                itemBuilder: (context, i) {
                  final item = displayList[i];
                  return _buildInstallmentCard(item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentCard(Installment it) {
    // ... (Keep existing UI logic exactly same) ...
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