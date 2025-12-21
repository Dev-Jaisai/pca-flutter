import 'dart:ui';
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

  void _processData(List<Installment> list) {
    if (!mounted) return;

    list.sort((a, b) {
      int yearComp = (b.periodYear ?? 0).compareTo(a.periodYear ?? 0);
      if (yearComp != 0) return yearComp;
      return (b.periodMonth ?? 0).compareTo(a.periodMonth ?? 0);
    });

    final years = list.map((e) => e.periodYear ?? DateTime.now().year).toSet().toList();
    years.sort((a, b) => b.compareTo(a));

    setState(() {
      _installments = list;
      _availableYears = years;
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
  }

  void _openBulkPayment(double maxPayableAmount) {
    final amountCtl = TextEditingController();
    final methodCtl = TextEditingController();
    final refCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("BULK PAYMENT", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 20),
              _neonDialogInput(amountCtl, "Amount (Max ₹${maxPayableAmount.toInt()})", Icons.attach_money, isNumber: true),
              const SizedBox(height: 12),
              _neonDialogInput(methodCtl, "Payment Method (e.g. UPI)", Icons.payment),
              const SizedBox(height: 12),
              _neonDialogInput(refCtl, "Reference (Optional)", Icons.note),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtl.text);
                      final method = methodCtl.text.trim().isEmpty ? null : methodCtl.text.trim();
                      final ref = refCtl.text.trim().isEmpty ? null : refCtl.text.trim();

                      if (amount == null || amount <= 0 || amount > maxPayableAmount) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Amount"), backgroundColor: Colors.red));
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        if (_currentFilter == 'Overdue') {
                          await ApiService.payOverdue(playerId: widget.player.id, amount: amount, paymentMethod: method, reference: ref);
                        } else {
                          await ApiService.payUnpaid(playerId: widget.player.id, amount: amount, paymentMethod: method, reference: ref);
                        }
                        DataManager().invalidatePlayerDetails(widget.player.id);
                        _loadData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful!"), backgroundColor: Colors.green));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    child: const Text("PAY NOW"),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _neonDialogInput(TextEditingController ctl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.cyanAccent),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
        filled: true,
        fillColor: Colors.black26,
      ),
    );
  }

  List<Installment> _getFilteredList() {
    return _installments.where((it) {
      if (it.periodYear != _selectedYear) return false;
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
    final displayList = _getFilteredList();
    double totalPendingOnScreen = 0;
    for (var i in displayList) {
      double total = i.amount ?? 0;
      double paid = i.paidAmount ?? 0;
      totalPendingOnScreen += (total - paid);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(
              _currentFilter == 'Overdue' ? 'Overdue Only' : 'History',
              style: TextStyle(fontSize: 12, color: _currentFilter == 'Overdue' ? Colors.redAccent : Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _currentFilter = _currentFilter == 'Overdue' ? 'All' : 'Overdue'),
            icon: Icon(_currentFilter == 'Overdue' ? Icons.list : Icons.warning_amber_rounded, color: _currentFilter == 'Overdue' ? Colors.white : Colors.orangeAccent),
          ),
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]))),

          SafeArea(
            child: Column(
              children: [
                // Year Chips
                // Year List Section (Horizontal Scroll)
                if (_availableYears.isNotEmpty)
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableYears.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final year = _availableYears[index];
                        final isSelected = year == _selectedYear;

                        return ChoiceChip(
                          label: Text(year.toString()),
                          selected: isSelected,
                          showCheckmark: false, // Checkmark नको, क्लीन लूकसाठी

                          onSelected: (val) { if (val) setState(() => _selectedYear = year); },

                          // --- COLORS ---
                          selectedColor: Colors.cyanAccent,
                          // Unselected असताना Dark Translucent रंग (आता White दिसणार नाही)
                          backgroundColor: Colors.black.withOpacity(0.3),

                          // --- BORDER ---
                          // Unselected असताना White Border, Selected असताना Cyan Border
                          side: BorderSide(
                              color: isSelected ? Colors.cyanAccent : Colors.white.withOpacity(0.3),
                              width: 1.5
                          ),

                          // --- TEXT STYLE ---
                          labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white, // Selected: Black, Unselected: White
                              fontWeight: FontWeight.bold
                          ),

                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        );
                      },
                    ),
                  ),

                // Total Pending Card
                if (totalPendingOnScreen > 0)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Total Pending ($_selectedYear)", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text("₹${totalPendingOnScreen.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _openBulkPayment(totalPendingOnScreen),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                          icon: const Icon(Icons.payment, size: 18),
                          label: const Text("PAY ALL"),
                        )
                      ],
                    ),
                  ),

                // List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                      : displayList.isEmpty
                      ? const Center(child: Text("No records found", style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: displayList.length,
                    itemBuilder: (ctx, i) => _buildGlassCard(displayList[i]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(Installment it) {
    final double total = it.amount ?? 0.0;
    final double paid = it.paidAmount ?? 0.0;
    final bool isPaid = (total - paid) <= 0;
    final bool isOverdue = !isPaid && it.dueDate != null && it.dueDate!.isBefore(DateTime.now());

    Color statusColor = isPaid ? Colors.greenAccent : (isOverdue ? Colors.redAccent : Colors.orangeAccent);
    String statusText = isPaid ? "PAID" : (isOverdue ? "OVERDUE" : "PENDING");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${DateFormat('MMM').format(DateTime(0, it.periodMonth ?? 1))} ${it.periodYear}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor)),
                      child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoCol("Amount", "₹${total.toInt()}", Colors.white),
                    _infoCol("Paid", "₹${paid.toInt()}", Colors.greenAccent),
                    _infoCol("Due Date", it.dueDate != null ? df.format(it.dueDate!) : "-", isOverdue ? Colors.redAccent : Colors.white70),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentsListScreen(installmentId: it.id, remainingAmount: total - paid))),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white24), foregroundColor: Colors.white),
                        child: const Text("History"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!isPaid)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => RecordPaymentScreen(installmentId: it.id, remainingAmount: total - paid)));
                            if (res == true) { DataManager().invalidatePlayerDetails(widget.player.id); _loadData(); }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, foregroundColor: Colors.white),
                          child: const Text("Record"),
                        ),
                      )
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCol(String label, String value, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}