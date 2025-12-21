import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';

class CreateFeeScreen extends StatefulWidget {
  const CreateFeeScreen({super.key});
  @override
  State<CreateFeeScreen> createState() => _CreateFeeScreenState();
}

class _CreateFeeScreenState extends State<CreateFeeScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Group> _groups = [];
  int? _selectedGroupId;
  final _feeCtl = TextEditingController();
  DateTime? _effectiveFrom;
  DateTime? _effectiveTo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      var groups = await DataManager().getGroups(forceRefresh: true);
      if (mounted) setState(() { _groups = groups; if (groups.isNotEmpty) _selectedGroupId = groups.first.id; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Colors.cyanAccent, onPrimary: Colors.black, surface: Color(0xFF203A43))), child: child!),
    );
    if (picked != null) setState(() { if (isFrom) _effectiveFrom = picked; else _effectiveTo = picked; });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroupId == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select Group'))); return; }

    try {
      await ApiService.createFeeStructure(
        groupId: _selectedGroupId!,
        monthlyFee: double.parse(_feeCtl.text.trim()),
        effectiveFrom: _effectiveFrom,
        effectiveTo: _effectiveTo,
      );
      DataManager().invalidateFees();
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Created Successfully'), backgroundColor: Colors.green)); Navigator.pop(context); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Create Fee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
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
                        children: [
                          DropdownButtonFormField<int>(
                            value: _selectedGroupId,
                            dropdownColor: const Color(0xFF2C5364),
                            style: const TextStyle(color: Colors.white),
                            decoration: _inputDeco('Group', Icons.group),
                            items: _groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
                            onChanged: (val) => setState(() => _selectedGroupId = val),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(controller: _feeCtl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _inputDeco('Monthly Fee', Icons.attach_money)),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: _dateButton(_effectiveFrom, true)),
                            const SizedBox(width: 10),
                            Expanded(child: _dateButton(_effectiveTo, false)),
                          ]),
                          const SizedBox(height: 30),
                          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold))))
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

  Widget _dateButton(DateTime? date, bool isFrom) {
    return GestureDetector(
      onTap: () => _pickDate(isFrom),
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.cyanAccent, size: 18),
            const SizedBox(width: 8),
            Text(date == null ? (isFrom ? 'Start Date' : 'End Date') : date.toString().split(' ')[0], style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label, labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)), prefixIcon: Icon(icon, color: Colors.cyanAccent), filled: true, fillColor: Colors.black.withOpacity(0.3),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
    );
  }
}