import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';

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
  bool _isActive = true; // Local state to update UI immediately if needed

  List<Group> _groups = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _fetchGroups();
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

  // --- STANDARD UPDATE (Name, Phone, Group etc.) ---
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

        // Send Updated Billing Info
        "paymentCycleMonths": _paymentCycleMonths,
        if (_newBillingDate != null)
          "firstInstallmentDate": _newBillingDate?.toIso8601String().split('T')[0],
      };

      await ApiService.updatePlayer(widget.player.id, data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated successfully'), backgroundColor: Colors.green));
        Navigator.pop(context, true); // Return true to refresh parent
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
        if (isJoin) {
          _joinDate = picked;
        } else {
          _newBillingDate = picked;
        }
      });
    }
  }

  // --- 🔥 FEATURE 1: HOLIDAY / PAUSE DIALOG ---
  void _showPauseDialog() {
    final noteCtl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          title: const Text("🏖️ Mark on Holiday", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Player will be marked INACTIVE. Future bills will NOT be generated automatically.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Date Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Start Date:", style: TextStyle(color: Colors.white)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent), borderRadius: BorderRadius.circular(4)),
                  child: Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.cyanAccent)),
                ),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2023), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => selectedDate = picked);
                },
              ),

              // Reason Input
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
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx); // Close Dialog
                _performLifecycleAction(
                    actionName: "Pause",
                    action: () => ApiService.pausePlayer(widget.player.id, selectedDate, noteCtl.text)
                );
              },
              child: const Text("CONFIRM PAUSE"),
            )
          ],
        ),
      ),
    );
  }

  // --- 🔥 FEATURE 2: ACTIVATE / RETURN DIALOG ---
  void _showActivateDialog() {
    DateTime selectedDate = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF203A43),
          title: const Text("▶️ Welcome Back!", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select the new Billing Start Date. A new cycle will begin from this date.",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Date Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Start Date:", style: TextStyle(color: Colors.white)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent), borderRadius: BorderRadius.circular(4)),
                  child: Text(DateFormat('dd MMM yyyy').format(selectedDate), style: const TextStyle(color: Colors.greenAccent)),
                ),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2023), lastDate: DateTime(2030));
                  if (picked != null) setDialogState(() => selectedDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx); // Close Dialog
                _performLifecycleAction(
                    actionName: "Activate",
                    action: () => ApiService.activatePlayer(widget.player.id, selectedDate)
                );
              },
              child: const Text("ACTIVATE"),
            )
          ],
        ),
      ),
    );
  }

  // Helper to handle API calls for Lifecycle actions
  Future<void> _performLifecycleAction({required String actionName, required Future<void> Function() action}) async {
    setState(() => _loading = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Player ${actionName}d Successfully!"), backgroundColor: Colors.green));
        Navigator.pop(context, true); // Close Screen & Refresh Parent
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');

    // Display strings
    String currentBillDayStr = widget.player.billingDay != null
        ? "${widget.player.billingDay}"
        : "Not Set";

    String currentCycleStr = (widget.player.paymentCycleMonths ?? 1) == 3
        ? "Quarterly (3 Months)"
        : "Monthly (1 Month)";

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
                            onTap: () => _pickDate(true), // Join Date
                            child: AbsorbPointer(child: _neonTextField(TextEditingController(text: _joinDate == null ? '' : DateFormat('yyyy-MM-dd').format(_joinDate!)), 'Join Date', Icons.calendar_today)),
                          ),
                          const SizedBox(height: 16),
                          _neonTextField(_ageCtl, 'Age', Icons.cake, type: TextInputType.number),

                          // --- BILLING SETTINGS ---
                          const SizedBox(height: 30),
                          const Divider(color: Colors.white24),
                          const Text("Billing Settings", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 15),

                          // Current Info
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.lightBlueAccent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Current Cycle: $currentCycleStr", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Text("Billing Day: $currentBillDayStr", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          DropdownButtonFormField<int>(
                            value: _paymentCycleMonths,
                            dropdownColor: const Color(0xFF2C5364),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDeco('Update Cycle', Icons.loop),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text("Monthly (Every Month)")),
                              DropdownMenuItem(value: 3, child: Text("Quarterly (Every 3 Months)")),
                            ],
                            onChanged: (v) => setState(() => _paymentCycleMonths = v!),
                          ),
                          const SizedBox(height: 16),

                          GestureDetector(
                            onTap: () => _pickDate(false), // Billing Date
                            child: Container(
                              height: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _newBillingDate != null ? Colors.cyanAccent : Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.event_repeat, color: Colors.cyanAccent.withOpacity(0.7)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _newBillingDate == null ? 'Update Billing Day' : 'New Start Date: ${df.format(_newBillingDate!)}',
                                      style: TextStyle(color: _newBillingDate == null ? Colors.white60 : Colors.white),
                                    ),
                                  ),
                                  if (_newBillingDate != null)
                                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                                ],
                              ),
                            ),
                          ),

                          // --- LIFECYCLE MANAGEMENT (FEATURE 1) ---
                          const SizedBox(height: 30),
                          const Divider(color: Colors.white24),
                          const Text("Status & Lifecycle", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 15),

                          if (_isActive)
                          // IF ACTIVE: SHOW PAUSE
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.beach_access, size: 20),
                                label: const Text("MARK ON HOLIDAY / PAUSE"),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orangeAccent,
                                    side: const BorderSide(color: Colors.orangeAccent),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                ),
                                onPressed: _showPauseDialog,
                              ),
                            )
                          else
                          // IF INACTIVE: SHOW ACTIVATE
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text("ACTIVATE PLAYER (RESUME)"),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.greenAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                ),
                                onPressed: _showActivateDialog,
                              ),
                            ),

                          // --- END LIFECYCLE SECTION ---

                          const SizedBox(height: 25),
                          const Divider(color: Colors.white24),

                          const SizedBox(height: 16),
                          _neonTextField(_notesCtl, 'Notes', Icons.note, maxLines: 2),
                          const SizedBox(height: 30),

                          // MAIN SAVE BUTTON
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