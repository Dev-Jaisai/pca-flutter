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

  late TextEditingController _nameCtl;
  late TextEditingController _phoneCtl;
  late TextEditingController _ageCtl;
  late TextEditingController _notesCtl;

  DateTime? _joinDate;
  int? _selectedGroupId;
  int _paymentCycleMonths = 1;
  DateTime? _newBillingDate;

  late bool _isActive;
  List<Group> _groups = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _fetchGroups();
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
      };

      // Billing date only if set
      if (_newBillingDate != null) {
        data["firstInstallmentDate"] = _newBillingDate?.toIso8601String().split('T')[0];
      }

      await ApiService.updatePlayer(widget.player.id, data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
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
          colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent, onPrimary: Colors.black, surface: Color(0xFF203A43)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isJoin) _joinDate = picked;
        else _newBillingDate = picked;
      });
    }
  }

  // --- PAUSE DIALOG ---
  void _showPauseDialog() {
    final noteCtl = TextEditingController();
    final daysCtl = TextEditingController();
    final creditCtl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isAutoCalculate = true;
    double monthlyFee = 5000.0;
    double calculatedCredit = 0.0;
    int daysInMonth = 30;

    void calculateCredit(StateSetter setDialogState) {
      if (!isAutoCalculate) return;
      int absentDays = int.tryParse(daysCtl.text) ?? 0;
      DateTime firstDayNextMonth = (selectedDate.month < 12) ? DateTime(selectedDate.year, selectedDate.month + 1, 1) : DateTime(selectedDate.year + 1, 1, 1);
      DateTime lastDayThisMonth = firstDayNextMonth.subtract(const Duration(days: 1));
      daysInMonth = lastDayThisMonth.day;
      double perDay = monthlyFee / daysInMonth;
      double total = perDay * absentDays;
      setDialogState(() {
        calculatedCredit = total;
        creditCtl.text = total.toStringAsFixed(0);
      });
    }

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            title: const Text("🏖️ Mark on Holiday", style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Player will be INACTIVE. Advance credit will be applied.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Start Date:", style: TextStyle(color: Colors.white)),
                    trailing: Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.cyanAccent)),
                    onTap: () async {
                      final picked = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2023), lastDate: DateTime(2030));
                      if(picked != null) setDialogState(() { selectedDate = picked; calculateCredit(setDialogState); });
                    },
                  ),
                  TextField(
                    controller: noteCtl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "Reason", labelStyle: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Auto-calculate?", style: TextStyle(color: Colors.white)),
                      Switch(
                        value: isAutoCalculate,
                        activeColor: Colors.cyanAccent,
                        onChanged: (val) { setDialogState(() { isAutoCalculate = val; if(val) calculateCredit(setDialogState); }); },
                      )
                    ],
                  ),
                  if(isAutoCalculate)
                    TextField(
                      controller: daysCtl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: "Days Absent", labelStyle: TextStyle(color: Colors.orangeAccent)),
                      onChanged: (_) => calculateCredit(setDialogState),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: creditCtl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(labelText: "Credit Amount (₹)", labelStyle: TextStyle(color: Colors.greenAccent)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _loading = true);
                  try {
                    String dateStr = DateFormat('dd MMM yyyy').format(selectedDate);
                    String finalNote = "${noteCtl.text.isEmpty ? "Holiday" : noteCtl.text} (From: $dateStr)";
                    double finalCredit = double.tryParse(creditCtl.text) ?? 0.0;

                    await ApiService.pausePlayer(widget.player.id, selectedDate, finalNote, advanceAmount: finalCredit);
                    DataManager().clearCache();
                    await _checkRealStatus();
                    EventBus().fire(PlayerEvent('updated'));
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paused!'), backgroundColor: Colors.green));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: const Text("CONFIRM PAUSE"),
              )
            ],
          ),
        )
    );
  }

  // --- ACTIVATE DIALOG ---
  void _showActivateDialog() {
    DateTime selectedDate = DateTime.now();
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            title: const Text("▶️ Welcome Back!", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Player is returning! New bill will be generated.", style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Return Date:", style: TextStyle(color: Colors.white)),
                  trailing: Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.greenAccent)),
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2023), lastDate: DateTime(2030));
                    if(picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player Activated!'), backgroundColor: Colors.green));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: const Text("ACTIVATE"),
              )
            ],
          ),
        )
    );
  }

  // --- MARK LEFT DIALOG ---
  void _showMarkLeftDialog() {
    DateTime? existingDate = _getExistingLeftDate();
    DateTime selectedDate = existingDate ?? DateTime.now();
    // DateTime selectedDate = DateTime.now();
    String selectedOption = 'COLLECT_FULL';
    final amountCtl = TextEditingController();
    bool showAmountField = false;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF203A43),
            title: Text(
              !widget.player.isActive ? "🖊️ Update Exit Details" : "⛔ Mark as Left",
              style: const TextStyle(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.player.isActive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueAccent)
                      ),
                      child: const Text(
                        "ℹ️ You are updating details. If you change the MONTH, please use 'Undo Left' instead.",
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Left Date:", style: TextStyle(color: Colors.white)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(8)),
                      child: Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2030)
                      );
                      if (picked != null) setDialogState(() => selectedDate = picked);
                    },
                  ),

                  // ... (Radio Buttons code same as before) ...
                  RadioListTile<String>(title: const Text("Collect Full Fee", style: TextStyle(color: Colors.white, fontSize: 14)), value: 'COLLECT_FULL', groupValue: selectedOption, activeColor: Colors.cyanAccent, onChanged: (val) => setDialogState(() { selectedOption = val!; showAmountField = false; })),
                  RadioListTile<String>(title: const Text("Collect Partial Fee", style: TextStyle(color: Colors.white, fontSize: 14)), value: 'COLLECT_PARTIAL', groupValue: selectedOption, activeColor: Colors.orangeAccent, onChanged: (val) => setDialogState(() { selectedOption = val!; showAmountField = true; })),

                  if(showAmountField)
                    TextField(
                        controller: amountCtl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            labelText: "Final Total Settlement Amount (₹)",
                            helperText: "Enter the final agreed amount",
                            labelStyle: TextStyle(color: Colors.orangeAccent)
                        )
                    ),

                  RadioListTile<String>(title: const Text("Waive Off", style: TextStyle(color: Colors.white, fontSize: 14)), value: 'WAIVE_OFF', groupValue: selectedOption, activeColor: Colors.redAccent, onChanged: (val) => setDialogState(() { selectedOption = val!; showAmountField = false; })),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: !widget.player.isActive ? Colors.blueAccent : Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () async {

                  // 🔥🔥🔥 SMART WARNING LOGIC (NEW) 🔥🔥🔥
                  // जर प्लेयर आधीच Inactive असेल (Update Mode) आणि महिना बदलला असेल
                  if (!widget.player.isActive && existingDate != null) {
                    if (existingDate.month != selectedDate.month || existingDate.year != selectedDate.year) {

                      // ⚠️ Show Blocking Alert
                      showDialog(
                          context: context,
                          builder: (alertCtx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E2A38),
                            title: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 10), Text("Month Changed!", style: TextStyle(color: Colors.white))]),
                            content: const Text(
                              "You are changing the billing month (e.g. Sep -> Oct).\n\nDirect update is risky for accounting.\nPlease use 'UNDO LEFT' first, then mark left with the new date.",
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(alertCtx),
                                  child: const Text("OK, I'll Undo", style: TextStyle(color: Colors.cyanAccent))
                              )
                            ],
                          )
                      );
                      return; // ⛔ Stop here. Don't call API.
                    }
                  }
                  // ---------------------------------------------

                  Navigator.pop(ctx);
                  _confirmMarkLeft(selectedDate, selectedOption, amountCtl.text);
                },
                child: Text(!widget.player.isActive ? "UPDATE" : "CONFIRM"),
              )
            ],
          ),
        )
    );
  }

  Future<void> _confirmMarkLeft(DateTime date, String option, String amount) async {
    setState(() => _loading = true);
    try {
      double? amt = double.tryParse(amount);

      // 🔥 Capture the message returned by API
      String message = await ApiService.markPlayerLeft(widget.player.id, date, option, amt);

      DataManager().clearCache();
      EventBus().fire(PlayerEvent('updated'));

      if (mounted) {
        // 🔥 Show the Backend Message in SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: message.contains("REFUND") ? Colors.redAccent : Colors.green, // Refund असेल तर लाल, नाहीतर हिरवा
              duration: const Duration(seconds: 4), // थोडा जास्त वेळ ठेवा
            )
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Action Blocked"), content: Text(e.toString()), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
// 🔥 Helper: जुन्या Note मधून 'LEFT Date' शोधणे
  DateTime? _getExistingLeftDate() {
    if (widget.player.notes == null) return null;
    try {
      // Note format: "... | LEFT: 2025-09-12"
      final regex = RegExp(r'LEFT: (\d{4}-\d{2}-\d{2})');
      final match = regex.firstMatch(widget.player.notes!);
      if (match != null) {
        return DateTime.parse(match.group(1)!);
      }
    } catch (e) {
      debugPrint("Error parsing date: $e");
    }
    return null;
  }
  void _undoLeftProcess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A38),
        title: const Text("Undo 'Left' Status?", style: TextStyle(color: Colors.white)),
        content: const Text("This will restore the player to ACTIVE state and un-cancel future bills.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                await ApiService.undoPlayerLeft(widget.player.id);
                DataManager().clearCache();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action Undone! Player is Active."), backgroundColor: Colors.green));
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
            child: const Text("CONFIRM UNDO"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                                Text(_isActive ? "STATUS: ACTIVE" : "STATUS: INACTIVE / LEFT", style: TextStyle(color: _isActive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 🔥🔥🔥 UPDATED BUTTON LOGIC (FULL) 🔥🔥🔥
                          // 🔥🔥🔥 SIMPLIFIED & POWERFUL LOGIC 🔥🔥🔥
                          if (_isActive) ...[
                            // 1. ACTIVE STATE
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.beach_access, size: 20),
                                label: const Text("MARK ON HOLIDAY / PAUSE"),
                                onPressed: _showPauseDialog,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.person_off, size: 20),
                                label: const Text("MARK AS LEFT ACADEMY"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                onPressed: _showMarkLeftDialog,
                              ),
                            ),
                          ] else ...[
                            // 2. INACTIVE STATE (Holiday OR Left)

                            // A. UPDATE / OVERWRITE EXIT (Works for both Holiday & Left)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.edit_note, size: 20),
                                label: const Text("UPDATE EXIT / MARK LEFT"), // 🔥 हे नाव बदलले
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                ),
                                onPressed: _showMarkLeftDialog, // 🔥 हेच डायलॉग वापरा!
                              ),
                            ),
                            const SizedBox(height: 12),

                            // B. UNDO ACTIONS (Smart Switch)
                            if ((widget.player.notes ?? "").contains("Holiday") || (widget.player.notes ?? "").contains("Paused"))
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.restore, size: 20),
                                  label: const Text("CANCEL HOLIDAY (Undo)"),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.cyanAccent, side: const BorderSide(color: Colors.cyanAccent)),
                                  onPressed: _undoPauseProcess,
                                ),
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.undo, size: 20),
                                  label: const Text("UNDO LEFT (Restore Active)"),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent, side: const BorderSide(color: Colors.orangeAccent)),
                                  onPressed: _undoLeftProcess,
                                ),
                              ),

                            const SizedBox(height: 12),

                            // C. ACTIVATE (Common)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text("ACTIVATE PLAYER (RESUME)"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                                onPressed: _showActivateDialog,
                              ),
                            ),
                          ],

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
// 🔥🔥🔥 NEW: UNDO PAUSE / HOLIDAY FUNCTION 🔥🔥🔥
  void _undoPauseProcess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A38),
        title: const Text("Cancel Holiday?", style: TextStyle(color: Colors.white)),
        content: const Text("This will restore the skipped bill to PENDING and activate the player.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                // Call API
                await ApiService.undoPause(widget.player.id);

                DataManager().clearCache();
                EventBus().fire(PlayerEvent('updated'));

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Holiday Cancelled! Bill Restored."), backgroundColor: Colors.green));
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
            child: const Text("CONFIRM"),
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