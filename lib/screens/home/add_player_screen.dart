import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';
import '../../utils/event_bus.dart';

class AddPlayerScreen extends StatefulWidget {
  const AddPlayerScreen({super.key});

  @override
  State<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends State<AddPlayerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _ageCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  final _photoCtl = TextEditingController();

  List<Group> _groups = [];
  int? _selectedGroupId;
  DateTime? _joinDate = DateTime.now();
  DateTime? _installmentDueDate;
  bool _isLoading = false;
  int _paymentCycleMonths = 1;

  @override
  void initState() {
    super.initState();
    _loadGroupsAndFees();
    // Default First Installment Date = Next Month (Monthly Logic)
    _installmentDueDate = DateTime.now().add(const Duration(days: 30));
  }

  Future<void> _loadGroupsAndFees() async {
    try {
      final apiGroups = await ApiService.fetchGroups();
      if (mounted) {
        setState(() {
          _groups = apiGroups;
          if (_groups.isNotEmpty) _selectedGroupId = _groups.first.id;
        });
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
    }
  }

  Future<void> _pickDate(bool isJoin) async {
    final now = DateTime.now();
    final initial = isJoin ? (_joinDate ?? now) : (_installmentDueDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.cyanAccent,
            onPrimary: Colors.black,
            surface: Color(0xFF203A43),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isJoin) {
          _joinDate = picked;
          // Auto-update Billing Date
          _installmentDueDate = DateTime(picked.year, picked.month + _paymentCycleMonths, picked.day);
        } else {
          _installmentDueDate = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a group')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService.createPlayer(
        name: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
        age: _ageCtl.text.isEmpty ? null : int.tryParse(_ageCtl.text.trim()),
        joinDate: _joinDate,
        groupId: _selectedGroupId!,
        notes: _notesCtl.text.isEmpty ? null : _notesCtl.text.trim(),
        photoUrl: _photoCtl.text.isEmpty ? null : _photoCtl.text.trim(),
        firstInstallmentDate: _installmentDueDate,
        paymentCycleMonths: _paymentCycleMonths,
      );

      EventBus().fire(PlayerEvent('added'));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player Added! First Bill Generated.'), backgroundColor: Colors.green));
      Navigator.of(context).pop(true);
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Add New Player', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]))),

          SafeArea(
            child: _isLoading
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
                          _neonTextField(_phoneCtl, 'Phone', Icons.phone, type: TextInputType.phone),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                  child: _neonTextField(_ageCtl, 'Age', Icons.cake, type: TextInputType.number)
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                // 🔥 Join Date Box Selector
                                  child: _neonSelector(
                                    label: "Join Date",  // Label inside box
                                    value: _joinDate == null ? 'Select Date' : df.format(_joinDate!),
                                    icon: Icons.calendar_today,
                                    onTap: () => _pickDate(true),
                                  )
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Group Dropdown
                          DropdownButtonFormField<int>(
                            value: _selectedGroupId,
                            dropdownColor: const Color(0xFF2C5364),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDeco('Group', Icons.group),
                            items: _groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
                            onChanged: (v) => setState(() => _selectedGroupId = v),
                          ),
                          const SizedBox(height: 16),

                          // Payment Cycle
                          DropdownButtonFormField<int>(
                            value: _paymentCycleMonths,
                            dropdownColor: const Color(0xFF2C5364),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDeco('Payment Cycle', Icons.loop),
                            items: List.generate(12, (index) {
                              int month = index + 1;
                              String label = "$month Month${month > 1 ? 's' : ''}";
                              if (month == 1) label += " (Monthly)";
                              if (month == 3) label += " (Quarterly)";
                              if (month == 6) label += " (Half-Yearly)";
                              if (month == 12) label += " (Yearly)";
                              return DropdownMenuItem(value: month, child: Text(label));
                            }),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _paymentCycleMonths = val;
                                  DateTime baseDate = _joinDate ?? DateTime.now();
                                  _installmentDueDate = DateTime(baseDate.year, baseDate.month + val, baseDate.day);
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          const Text("Billing Details", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),

                          // 🔥 Billing Date Box Selector
                          _neonSelector(
                              label: "Billing Start Date", // Label inside box
                              value: _installmentDueDate == null ? 'Select Date' : df.format(_installmentDueDate!),
                              icon: Icons.event_available,
                              onTap: () => _pickDate(false),
                              isHighlight: true
                          ),

                          const SizedBox(height: 8),
                          Text(
                            "Note: This date determines the billing day for all future payments.",
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),

                          const SizedBox(height: 16),
                          _neonTextField(_notesCtl, 'Notes (Optional)', Icons.note, maxLines: 2),
                          const SizedBox(height: 30),

                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: const LinearGradient(colors: [Colors.cyan, Colors.blueAccent])),
                            child: ElevatedButton(
                              onPressed: _groups.isEmpty ? null : _submit,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: const Text('CREATE PLAYER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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

  // --- Helper Methods ---

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

  // 🔥 RESTORED BOX DESIGN WITH LABEL INSIDE
  Widget _neonSelector({required String label, required String value, required IconData icon, required VoidCallback onTap, bool isHighlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60, // Fixed height similar to TextFields
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isHighlight ? Colors.purpleAccent.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isHighlight ? Colors.purpleAccent : Colors.cyanAccent.withOpacity(0.7)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔹 Label inside box (Small)
                Text(
                    label,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)
                ),
                const SizedBox(height: 2),
                // 🔹 Value inside box (Big)
                Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}