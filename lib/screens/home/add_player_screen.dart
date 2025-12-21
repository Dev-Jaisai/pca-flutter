import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
  bool _loadingGroups = true;
  Map<String, double> _fees = {};

  @override
  void initState() {
    super.initState();
    _loadGroupsAndFees();
  }

  Future<void> _loadGroupsAndFees() async {
    setState(() => _loadingGroups = true);
    final box = Hive.box('app_cache');

    try {
      final rawFees = box.get('fee_structures', defaultValue: <dynamic, dynamic>{});
      if (rawFees is Map) {
        _fees = rawFees.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }

      final cachedGroups = box.get('groups_list', defaultValue: []);
      if (cachedGroups is List && cachedGroups.isNotEmpty) {
        final parsed = cachedGroups.map((json) {
          try {
            if (json is Map<String, dynamic>) return Group.fromJson(json);
            if (json is Map) return Group.fromJson(Map<String, dynamic>.from(json));
            return null;
          } catch (_) { return null; }
        }).whereType<Group>().toList();

        if (parsed.isNotEmpty) {
          if (mounted) setState(() { _groups = parsed; _validateSelection(); _loadingGroups = false; });
        }
      }
    } catch (e) { debugPrint('Cache load error: $e'); }

    try {
      final apiGroups = await ApiService.fetchGroups();
      if (apiGroups.isNotEmpty) {
        try {
          final groupsJson = apiGroups.map((g) => g.toJson()).toList();
          await box.put('groups_list', groupsJson);
        } catch (e) { debugPrint('Hive save error: $e'); }

        if (mounted) setState(() { _groups = apiGroups; _validateSelection(); _loadingGroups = false; });
      }
    } catch (e) {
      debugPrint('API Error: $e');
      if (mounted && _groups.isEmpty) setState(() => _loadingGroups = false);
    }
  }

  void _validateSelection() {
    if (_groups.isEmpty) { _selectedGroupId = null; return; }
    if (_selectedGroupId == null || !_groups.any((g) => g.id == _selectedGroupId)) {
      _selectedGroupId = _groups.first.id;
    }
  }

  Future<void> _pickDate(bool isJoin) async {
    final now = DateTime.now();
    final initial = isJoin ? (_joinDate ?? now) : (_installmentDueDate ?? (_joinDate ?? now));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
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
        if (isJoin) _joinDate = picked; else _installmentDueDate = picked;
      });
    }
  }

  double? _selectedGroupFee() {
    if (_selectedGroupId == null) return null;
    try {
      final g = _groups.firstWhere((e) => e.id == _selectedGroupId);
      return _fees[g.name];
    } catch (_) { return null; }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroupId == null || _joinDate == null || _installmentDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final createdPlayer = await ApiService.createPlayer(
        name: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
        age: _ageCtl.text.isEmpty ? null : int.tryParse(_ageCtl.text.trim()),
        joinDate: _joinDate,
        groupId: _selectedGroupId!,
        notes: _notesCtl.text.isEmpty ? null : _notesCtl.text.trim(),
        photoUrl: _photoCtl.text.isEmpty ? null : _photoCtl.text.trim(),
      );

      await ApiService.createInstallment(
        playerId: createdPlayer.id,
        periodMonth: _installmentDueDate!.month,
        periodYear: _installmentDueDate!.year,
        dueDate: _installmentDueDate!,
        amount: _selectedGroupFee(),
      );

      EventBus().fire(PlayerEvent('added'));
      EventBus().fire(PlayerEvent('installment_created'));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player Created Successfully'), backgroundColor: Colors.green));
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
    final selectedFee = _selectedGroupFee();

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
          // Background
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]))),
          Positioned(top: -50, right: -50, child: Container(height: 250, width: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.cyan.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 100)]))),

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
                        children: [
                          _neonTextField(_nameCtl, 'Full Name', Icons.person),
                          const SizedBox(height: 16),
                          _neonTextField(_phoneCtl, 'Phone', Icons.phone, type: TextInputType.phone),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _neonTextField(_ageCtl, 'Age', Icons.cake, type: TextInputType.number)),
                              const SizedBox(width: 12),
                              Expanded(child: _neonSelector(
                                  label: _joinDate == null ? 'Join Date' : df.format(_joinDate!),
                                  icon: Icons.calendar_today,
                                  onTap: () => _pickDate(true)
                              )),
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
                          if (selectedFee != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 10),
                              child: Align(alignment: Alignment.centerLeft, child: Text('Monthly Fee: ₹${selectedFee.toStringAsFixed(0)}', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                            ),

                          const SizedBox(height: 16),
                          _neonSelector(
                              label: _installmentDueDate == null ? 'First Installment Due Date' : df.format(_installmentDueDate!),
                              icon: Icons.event_available,
                              onTap: () => _pickDate(false),
                              isHighlight: true
                          ),

                          const SizedBox(height: 16),
                          _neonTextField(_notesCtl, 'Notes (Optional)', Icons.note, maxLines: 2),
                          const SizedBox(height: 16),
                          _neonTextField(_photoCtl, 'Photo URL (Optional)', Icons.image),
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

  Widget _neonSelector({required String label, required IconData icon, required VoidCallback onTap, bool isHighlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
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
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }
}