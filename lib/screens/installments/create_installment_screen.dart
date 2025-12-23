import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/fee_structure.dart';
import '../../models/installment.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../utils/event_bus.dart';

class CreateInstallmentScreen extends StatefulWidget {
  final Player player;
  const CreateInstallmentScreen({super.key, required this.player});

  @override
  State<CreateInstallmentScreen> createState() => _CreateInstallmentScreenState();
}

class _CreateInstallmentScreenState extends State<CreateInstallmentScreen> {
  final _formKey = GlobalKey<FormState>();

  int _selectedMonth = 1;
  final _yearCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  DateTime? _dueDate;

  bool _submitting = false;
  bool _loadingFee = true;
  bool _loadingHistory = true;
  List<Installment> _recentBills = [];

  FeeStructure? _effectiveFee;
  String? _feeError;

  final List<String> _monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  @override
  void initState() {
    super.initState();
    _loadEffectiveFee();
    _loadPlayerHistory();
  }

  Future<void> _loadPlayerHistory() async {
    try {
      List<Installment> list = await DataManager().getInstallmentsForPlayer(widget.player.id);

      list.sort((a, b) {
        int yearComp = (b.periodYear ?? 0).compareTo(a.periodYear ?? 0);
        if (yearComp != 0) return yearComp;
        return (b.periodMonth ?? 0).compareTo(a.periodMonth ?? 0);
      });

      // 1. Calculate Next Month based on History & Cycle
      int nextMonth = DateTime.now().month;
      int nextYear = DateTime.now().year;

      if (list.isNotEmpty) {
        final last = list.first;
        int lastMonth = last.periodMonth ?? 0;
        int lastYear = last.periodYear ?? 0;

        // 🔥 FIX: Use Player's Cycle instead of always +1
        int cycle = widget.player.paymentCycleMonths ?? 1; // Default to 1 if null

        // Calculate raw next month
        int calculatedMonth = lastMonth + cycle;
        int calculatedYear = lastYear;

        // Handle Year Overflow (e.g., 12 + 3 = 15 -> Month 3, Next Year)
        while (calculatedMonth > 12) {
          calculatedMonth -= 12;
          calculatedYear++;
        }

        nextMonth = calculatedMonth;
        nextYear = calculatedYear;
      }

      if (mounted) {
        setState(() {
          _recentBills = list.take(3).toList();
          _loadingHistory = false;

          _selectedMonth = nextMonth;
          _yearCtl.text = nextYear.toString();

          // Auto-Set Due Date based on Billing Day
          _updateDueDate(nextMonth, nextYear);
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _updateDueDate(int month, int year) {
    int billDay = widget.player.billingDay ?? 1;
    int maxDays = DateTime(year, month + 1, 0).day;
    if (billDay > maxDays) billDay = maxDays;

    setState(() {
      _dueDate = DateTime(year, month, billDay);
    });
  }

  @override
  void dispose() {
    _yearCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  Future<void> _loadEffectiveFee() async {
    setState(() {
      _loadingFee = true;
      _feeError = null;
    });

    try {
      final groupId = widget.player.groupId;
      if (groupId == null) {
        _feeError = 'Player has no group assigned';
        _effectiveFee = null;
      } else {
        final fee = await ApiService.fetchEffectiveFee(groupId);
        _effectiveFee = fee;
        if (fee != null) {
          _amountCtl.text = fee.monthlyFee.toStringAsFixed(2);
        }
      }
    } catch (e) {
      _feeError = 'Failed to load group fee';
    } finally {
      if (mounted) setState(() => _loadingFee = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent, onPrimary: Colors.black, surface: Color(0xFF203A43)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick a due date'), backgroundColor: Colors.redAccent));
      return;
    }

    final int month = _selectedMonth;
    final int year = int.parse(_yearCtl.text.trim());
    final double? amount = _amountCtl.text.trim().isEmpty ? null : double.tryParse(_amountCtl.text.trim());

    bool isDuplicate = _recentBills.any((i) => i.periodMonth == month && i.periodYear == year);
    if (isDuplicate) {
      bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            title: const Text("Warning: Duplicate Bill", style: TextStyle(color: Colors.orangeAccent)),
            content: Text("A bill for ${_monthNames[month-1]} $year already exists.\nCreate anyway?", style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Create", style: TextStyle(color: Colors.redAccent))),
            ],
          )
      ) ?? false;
      if (!confirm) return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.createInstallment(
        playerId: widget.player.id,
        periodMonth: month,
        periodYear: year,
        dueDate: _dueDate!,
        amount: amount,
      );

      EventBus().fire(PlayerEvent('installment_created'));
      DataManager().invalidatePlayerDetails(widget.player.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill Created Successfully!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Manual Bill Generation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),

          SafeArea(
            child: _submitting
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                                child: const Icon(Icons.person, color: Colors.cyanAccent),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Generating Bill For", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                                  const SizedBox(height: 4),
                                  Text(widget.player.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          const Text("Existing Bills (Last 3)", style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _loadingHistory
                              ? const LinearProgressIndicator(minHeight: 2, color: Colors.orangeAccent)
                              : _recentBills.isEmpty
                              ? const Text("No previous bills found.", style: TextStyle(color: Colors.white38, fontSize: 12))
                              : Wrap(
                            spacing: 8,
                            children: _recentBills.map((b) {
                              final monthName = DateFormat('MMM').format(DateTime(0, b.periodMonth ?? 1));
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24)
                                ),
                                child: Text(
                                    "$monthName ${b.periodYear}",
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)
                                ),
                              );
                            }).toList(),
                          ),

                          const Divider(color: Colors.white24, height: 40),

                          const Text("Billing Period", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  value: _selectedMonth,
                                  dropdownColor: const Color(0xFF203A43),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Month",
                                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                                    prefixIcon: Icon(Icons.calendar_month, color: Colors.cyanAccent.withOpacity(0.7)),
                                    filled: true,
                                    fillColor: Colors.black.withOpacity(0.3),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent, width: 2)),
                                  ),
                                  items: List.generate(12, (index) {
                                    return DropdownMenuItem(
                                      value: index + 1,
                                      child: Text(_monthNames[index]),
                                    );
                                  }),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedMonth = val);
                                      int y = int.tryParse(_yearCtl.text) ?? DateTime.now().year;
                                      _updateDueDate(val, y);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                  flex: 1,
                                  child: _neonTextField(_yearCtl, 'Year', Icons.calendar_today, type: TextInputType.number)
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          const Text("Payment Details", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _neonTextField(
                              _amountCtl,
                              'Amount',
                              Icons.currency_rupee,
                              type: const TextInputType.numberWithOptions(decimal: true),
                              suffix: _loadingFee ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)) : null
                          ),
                          if (_effectiveFee != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, left: 5),
                              child: Text("Auto-fetched from Group Fee: ₹${_effectiveFee!.monthlyFee}", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                            ),

                          const SizedBox(height: 24),

                          GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _dueDate == null ? Colors.white.withOpacity(0.1) : Colors.cyanAccent),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event_available, color: Colors.cyanAccent.withOpacity(0.7)),
                                  const SizedBox(width: 16),
                                  Text(
                                    _dueDate == null ? 'Select Due Date' : df.format(_dueDate!),
                                    style: TextStyle(fontSize: 16, color: _dueDate == null ? Colors.white54 : Colors.white),
                                  ),
                                  const Spacer(),
                                  if (_dueDate != null) const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Colors.cyan, Colors.blueAccent])),
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: const Text('GENERATE BILL MANUALLY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _neonTextField(TextEditingController ctl, String label, IconData icon, {TextInputType type = TextInputType.text, Widget? suffix}) {
    return TextFormField(
      controller: ctl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: Colors.cyanAccent.withOpacity(0.7)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent, width: 2)),
      ),
      onChanged: (val) {
        if (label == 'Year') {
          int? y = int.tryParse(val);
          if (y != null && y > 2000) {
            _updateDueDate(_selectedMonth, y);
          }
        }
      },
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        return null;
      },
    );
  }
}