// lib/screens/add_player_screen.dart
import 'dart:async';
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
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _ageCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  final _photoCtl = TextEditingController();

  List<Group> _groups = [];
  int? _selectedGroupId;
  DateTime? _joinDate;
  DateTime? _installmentDueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final g = await ApiService.fetchGroups();
      setState(() {
        _groups = g;
        if (_groups.isNotEmpty) _selectedGroupId = _groups.first.id;
      });
    } catch (e) {
      // keep empty if API fails; UI will show empty dropdown
      setState(() {});
    }
  }

  Future<void> _pickJoinDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: const Color(0xFF9B6CFF)),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _joinDate = picked);
  }

  Future<void> _pickInstallmentDueDate() async {
    final now = DateTime.now();
    final initial = _installmentDueDate ?? (_joinDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: const Color(0xFF9B6CFF)),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) setState(() => _installmentDueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a group')));
      return;
    }
    if (_joinDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick join date')));
      return;
    }
    if (_installmentDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick an installment due date')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1) Create player (keeps same API signature)
      final createdPlayer = await ApiService.createPlayer(
        name: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
        age: _ageCtl.text.isEmpty ? null : int.tryParse(_ageCtl.text.trim()),
        joinDate: _joinDate,
        groupId: _selectedGroupId!,
        notes: _notesCtl.text.isEmpty ? null : _notesCtl.text.trim(),
        photoUrl: _photoCtl.text.isEmpty ? null : _photoCtl.text.trim(),
      );

      final int playerId = createdPlayer.id;

      // 2) Create installment for selected due date (same API call)
      final due = _installmentDueDate!;
      final int month = due.month;
      final int year = due.year;

      await ApiService.createInstallment(
        playerId: playerId,
        periodMonth: month,
        periodYear: year,
        dueDate: due,
        amount: null, // backend chooses based on group fee
      );

      // 3) Notify listeners (same EventBus usage)
      EventBus().fire(PlayerEvent('added'));
      EventBus().fire(PlayerEvent('installment_created'));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player + Installment Created')));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _ageCtl.dispose();
    _notesCtl.dispose();
    _photoCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme tokens
    const bg = Color(0xFFFBF8FF);
    const accent = Color(0xFF9B6CFF);
    const cardRadius = 16.0;
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('Add Player', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(cardRadius),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: const Offset(0, 10))],
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFBFD8FF), Color(0xFF60A5FA)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(Icons.sports_cricket, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('New Player', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          SizedBox(height: 6),
                          Text('Add player details and set first installment due date',
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Form card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(cardRadius),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 14, offset: const Offset(0, 8))],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _roundedTextField(controller: _nameCtl, label: 'Name', validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
                      const SizedBox(height: 12),
                      _roundedTextField(controller: _phoneCtl, label: 'Phone', keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _roundedTextField(controller: _ageCtl, label: 'Age', keyboardType: TextInputType.number)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _pressableDateField(
                              label: 'Join Date',
                              text: _joinDate == null ? 'Select date' : df.format(_joinDate!),
                              onTap: _pickJoinDate,
                              icon: Icons.calendar_today,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Group dropdown inside rounded container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<int>(
                          value: _selectedGroupId,
                          decoration: const InputDecoration(border: InputBorder.none, labelText: 'Group'),
                          items: _groups.map((g) => DropdownMenuItem<int>(value: g.id, child: Text(g.name))).toList(),
                          onChanged: (v) => setState(() => _selectedGroupId = v),
                          validator: (v) => (v == null) ? 'Group is required' : null,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Installment due date (required)
                      _pressableDateField(
                        label: 'Installment Due Date (required)',
                        text: _installmentDueDate == null ? 'Select due date' : df.format(_installmentDueDate!),
                        onTap: _pickInstallmentDueDate,
                        icon: Icons.event_note,
                      ),

                      const SizedBox(height: 12),
                      _roundedTextField(controller: _notesCtl, label: 'Notes', maxLines: 2),
                      const SizedBox(height: 12),
                      _roundedTextField(controller: _photoCtl, label: 'Photo URL (optional)'),
                      const SizedBox(height: 20),

                      // Big gradient submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: accent,
                            elevation: 8,
                          ),
                          child: const Text('Create Player', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundedTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F9FF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _pressableDateField({required String label, required String text, required VoidCallback onTap, IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: text.contains('Select') ? Colors.black45 : Colors.black87),
              ),
            ),
            if (icon != null) Icon(icon, color: Colors.black45),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
