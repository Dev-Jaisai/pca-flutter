import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../utils/event_bus.dart';

class EditPlayerScreen extends StatefulWidget {
  final Player player;

  const EditPlayerScreen({super.key, required this.player});

  @override
  State<EditPlayerScreen> createState() => _EditPlayerScreenState();
}

class _EditPlayerScreenState extends State<EditPlayerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameCtl;
  late TextEditingController _phoneCtl;
  late TextEditingController _ageCtl;
  late TextEditingController _notesCtl;

  // State Variables
  DateTime? _joinDate;
  int? _selectedGroupId;
  int _paymentCycleMonths = 1;
  DateTime? _newBillingDate;

  // 🔥 Local State for Active/Inactive Toggle
  late bool _isActive;

  List<Group> _groups = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _fetchGroups();

    // Sync status from server
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkRealStatus();
    });
  }

  void _initializeFields() {
    _nameCtl = TextEditingController(text: widget.player.name);
    _phoneCtl = TextEditingController(text: widget.player.phone);
    _ageCtl = TextEditingController(text: widget.player.age?.toString() ?? '');
    _notesCtl = TextEditingController(text: widget.player.notes);
    _joinDate = widget.player.joinDate;
    _selectedGroupId = widget.player.groupId;
    _paymentCycleMonths = widget.player.paymentCycleMonths ?? 1;
    _isActive = widget.player.isActive;
  }

  Future<void> _fetchGroups() async {
    try {
      final groups = await ApiService.fetchGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (e) {
      debugPrint('Error fetching groups: $e');
    }
  }

  Future<void> _checkRealStatus() async {
    try {
      final freshPlayer = await ApiService.fetchPlayerById(widget.player.id);
      if (mounted) {
        setState(() {
          _isActive = freshPlayer.isActive;
          _nameCtl.text = freshPlayer.name;
          _phoneCtl.text = freshPlayer.phone;
          _ageCtl.text = freshPlayer.age?.toString() ?? '';
          _notesCtl.text = freshPlayer.notes ?? '';
          _joinDate = freshPlayer.joinDate;
          _selectedGroupId = freshPlayer.groupId;
          _paymentCycleMonths = freshPlayer.paymentCycleMonths ?? 1;
        });
      }
    } catch (e) {
      debugPrint("Error checking player status: $e");
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final Map<String, dynamic> data = {
        "name": _nameCtl.text.trim(),
        "phone": _phoneCtl.text.trim(),
        "age": int.tryParse(_ageCtl.text.trim()) ?? 0,
        "groupId": _selectedGroupId,
        "joinDate": _joinDate?.toIso8601String().split('T')[0],
        "notes": _notesCtl.text.trim(),
        "paymentCycleMonths": _paymentCycleMonths,
        if (_newBillingDate != null)
          "firstInstallmentDate": _newBillingDate?.toIso8601String().split('T')[0],
      };

      await ApiService.updatePlayer(widget.player.id, data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Updated successfully'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isJoin) async {
    final now = DateTime.now();
    final initial = isJoin ? (_joinDate ?? now) : (_newBillingDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: Colors.cyanAccent,
              onPrimary: Colors.black,
              surface: Color(0xFF203A43)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isJoin) {
          _joinDate = picked;
        } else {
          _newBillingDate = picked;
        }
      });
    }
  }

  // --- 🔥 UPDATED PAUSE DIALOG (Hybrid Logic) ---
  void _showPauseDialog() {
    final noteCtl = TextEditingController();
    final daysCtl = TextEditingController();
    final creditCtl = TextEditingController(); // For displaying/editing final credit

    DateTime selectedDate = DateTime.now();

    // Logic State Variables
    bool isAutoCalculate = true;
    double monthlyFee = 5000.0; // ⚠️ TODO: Fetch this dynamically if possible (e.g. from Group)
    double calculatedCredit = 0.0;
    int daysInMonth = 30;

    // Helper to calculate credit
    void calculateCredit(StateSetter setDialogState) {
      if (!isAutoCalculate) return;

      int absentDays = int.tryParse(daysCtl.text) ?? 0;

      // Calculate days in the target month (Month of 'selectedDate')
      // Logic: Get 1st day of next month, subtract 1 day.
      DateTime firstDayNextMonth = (selectedDate.month < 12)
          ? DateTime(selectedDate.year, selectedDate.month + 1, 1)
          : DateTime(selectedDate.year + 1, 1, 1);
      DateTime lastDayThisMonth = firstDayNextMonth.subtract(const Duration(days: 1));

      daysInMonth = lastDayThisMonth.day; // e.g., 28, 30, 31

      double perDay = monthlyFee / daysInMonth;
      double total = perDay * absentDays;

      setDialogState(() {
        calculatedCredit = total;
        creditCtl.text = total.toStringAsFixed(0); // Update the editable field
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          title: const Text("🏖️ Mark on Holiday", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Player will be INACTIVE. Advance credit will be applied to the next bill.",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // 1. Start Date Picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Start Date:", style: TextStyle(color: Colors.white)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.cyanAccent),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(DateFormat('dd MMM yyyy').format(selectedDate),
                        style: const TextStyle(color: Colors.cyanAccent)),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030));
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                        calculateCredit(setDialogState); // Recalculate if month changes
                      });
                    }
                  },
                ),

                const Divider(color: Colors.white24),

                // 2. Reason Input
                TextField(
                  controller: noteCtl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Reason (e.g. Village Trip)",
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.cyanAccent)),
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Auto-Calculate Toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Auto-calculate Credit?", style: TextStyle(color: Colors.white)),
                    Switch(
                      value: isAutoCalculate,
                      activeColor: Colors.cyanAccent,
                      onChanged: (val) {
                        setDialogState(() {
                          isAutoCalculate = val;
                          if (val) calculateCredit(setDialogState);
                        });
                      },
                    )
                  ],
                ),

                // 4. Days Input & Breakdown (Only if Auto is ON)
                if (isAutoCalculate) ...[
                  TextField(
                    controller: daysCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Days Absent",
                      suffixText: "days",
                      labelStyle: TextStyle(color: Colors.orangeAccent),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                    ),
                    onChanged: (_) => calculateCredit(setDialogState),
                  ),

                  // Calculation Breakdown Box
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12)
                    ),
                    child: Column(
                      children: [
                        _calcRow("Monthly Fee", "₹${monthlyFee.toInt()}"),
                        _calcRow("Days in Month", "$daysInMonth"),
                        _calcRow("Per Day", "₹${(monthlyFee/daysInMonth).toStringAsFixed(2)}"),
                        const Divider(color: Colors.white24, height: 10),
                        _calcRow("Calculated Credit", "₹${calculatedCredit.toStringAsFixed(0)}", isBold: true),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 5. Final Credit Amount (Always Editable)
                TextField(
                  controller: creditCtl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: "Final Credit Amount (₹)",
                    labelStyle: TextStyle(color: Colors.greenAccent),
                    prefixText: "₹ ",
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent, width: 2)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                try {
                  // Get credit amount from the text field
                  double finalCredit = double.tryParse(creditCtl.text) ?? 0.0;

                  await ApiService.pausePlayer(
                      widget.player.id,
                      selectedDate,
                      noteCtl.text,
                      advanceAmount: finalCredit // 🔥 Pass this new param
                  );

                  DataManager().clearCache();
                  await _checkRealStatus();

                  EventBus().fire(PlayerEvent('updated'));
                  EventBus().fire(PlayerEvent('installment_created'));

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Paused! Credit of ₹${finalCredit.toInt()} saved.'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: const Text("CONFIRM PAUSE"),
            )
          ],
        ),
      ),
    );
  }

  // Helper for breakdown rows
  Widget _calcRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(color: isBold ? Colors.cyanAccent : Colors.white, fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _showActivateDialog() {
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          title: const Text("▶️ Welcome Back!", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Player is returning! A new bill will be generated starting from this date.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Return Date:", style: TextStyle(color: Colors.white)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent), borderRadius: BorderRadius.circular(4)),
                  child: Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.greenAccent)),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2023),
                      lastDate: DateTime(2030));
                  if (picked != null)
                    setDialogState(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _loading = true);
                try {
                  await ApiService.activatePlayer(widget.player.id, selectedDate);
                  DataManager().clearCache();
                  await _checkRealStatus();
                  EventBus().fire(PlayerEvent('updated'));
                  EventBus().fire(PlayerEvent('installment_created'));

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Player Activated & Bill Generated!")));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: const Text("ACTIVATE"),
            )
          ],
        ),
      ),
    );
  }

  void _showMarkLeftDialog() {
    DateTime selectedDate = DateTime.now();
    String selectedOption = 'COLLECT_FULL';
    final amountCtl = TextEditingController();
    bool showAmountField = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          title: const Text("⛔ Mark as Left", style: TextStyle(color: Colors.redAccent)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Future bills will be deleted. Select the date they left:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Left Date:", style: TextStyle(color: Colors.white)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(4)),
                    child: Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.redAccent)),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030));
                    if (picked != null)
                      setDialogState(() => selectedDate = picked);
                  },
                ),
                const Divider(color: Colors.white24),
                const Text("Settlement Option:", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                RadioListTile<String>(
                  title: const Text("Collect Full Fee", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Keep original bill amount", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  value: 'COLLECT_FULL',
                  groupValue: selectedOption,
                  activeColor: Colors.cyanAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() { selectedOption = val!; showAmountField = false; }),
                ),
                RadioListTile<String>(
                  title: const Text("Collect Partial Fee", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Enter custom amount", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  value: 'COLLECT_PARTIAL',
                  groupValue: selectedOption,
                  activeColor: Colors.orangeAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() { selectedOption = val!; showAmountField = true; }),
                ),
                if (showAmountField)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      controller: amountCtl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Enter Final Amount (₹)",
                        labelStyle: TextStyle(color: Colors.orangeAccent),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                      ),
                    ),
                  ),
                RadioListTile<String>(
                  title: const Text("Waive Off (Cancel Bill)", style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text("Set amount to 0", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  value: 'WAIVE_OFF',
                  groupValue: selectedOption,
                  activeColor: Colors.redAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() { selectedOption = val!; showAmountField = false; }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                _confirmMarkLeft(selectedDate, selectedOption, amountCtl.text);
              },
              child: const Text("CONFIRM LEFT"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _confirmMarkLeft(DateTime date, String option, String amount) async {
    setState(() => _loading = true);
    try {
      await ApiService.markPlayerLeft(widget.player.id, date, option, amount);
      DataManager().clearCache();
      EventBus().fire(PlayerEvent('updated'));
      EventBus().fire(PlayerEvent('installment_created'));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Player Marked as LEFT!'), backgroundColor: Colors.red));
        Navigator.pop(context, true);
      }
    } catch (e) {
      String errorMsg = e.toString().replaceAll("Exception: ", "");
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("⚠️ Action Blocked", style: TextStyle(color: Colors.orangeAccent)),
            content: Text(errorMsg, style: const TextStyle(fontSize: 16)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ... (build and helper widgets same as before) ...
  @override
  Widget build(BuildContext context) {
    // Note: Same UI code as your previous version for build(), just referencing new methods
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Edit Player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]))),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
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
                          _neonTextField(_nameCtl, 'Full Name', Icons.person),
                          const SizedBox(height: 16),
                          _neonTextField(_phoneCtl, 'Mobile', Icons.phone, type: TextInputType.phone),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            value: _selectedGroupId,
                            dropdownColor: const Color(0xFF2C5364),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDeco('Group', Icons.group),
                            items: _groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
                            onChanged: (v) => setState(() => _selectedGroupId = v),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _pickDate(true),
                            child: AbsorbPointer(child: _neonTextField(TextEditingController(text: _joinDate == null ? '' : DateFormat('yyyy-MM-dd').format(_joinDate!)), 'Join Date', Icons.calendar_today)),
                          ),
                          const SizedBox(height: 16),
                          _neonTextField(_ageCtl, 'Age', Icons.cake, type: TextInputType.number),
                          const SizedBox(height: 30),
                          const Divider(color: Colors.white24),
                          const Text("Status & Lifecycle", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: _isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _isActive ? Colors.greenAccent : Colors.redAccent)),
                            child: Row(
                              children: [
                                Icon(_isActive ? Icons.check_circle : Icons.pause_circle_filled, color: _isActive ? Colors.greenAccent : Colors.redAccent),
                                const SizedBox(width: 8),
                                Text(_isActive ? "STATUS: ACTIVE" : "STATUS: ON HOLIDAY (INACTIVE)", style: TextStyle(color: _isActive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_isActive) ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.beach_access, size: 20),
                                label: const Text("MARK ON HOLIDAY / PAUSE"),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent, side: const BorderSide(color: Colors.orangeAccent), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                onPressed: _showPauseDialog,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.person_off, size: 20),
                                label: const Text("MARK AS LEFT ACADEMY"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2), foregroundColor: Colors.redAccent, side: BorderSide(color: Colors.redAccent.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                onPressed: _showMarkLeftDialog,
                              ),
                            ),
                          ] else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text("ACTIVATE PLAYER (RESUME)"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                onPressed: _showActivateDialog,
                              ),
                            ),
                          const SizedBox(height: 25),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 16),
                          _neonTextField(_notesCtl, 'Notes', Icons.note, maxLines: 2),
                          const SizedBox(height: 30),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurpleAccent])),
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: const Text('UPDATE DETAILS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          )
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

  Widget _neonTextField(TextEditingController ctl, String label, IconData icon, {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      controller: ctl,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDeco(label, icon),
      validator: (v) => (label == 'Full Name' && (v == null || v.isEmpty)) ? 'Required' : null,
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      prefixIcon: Icon(icon, color: Colors.cyanAccent.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent, width: 2)),
    );
  }
}