// lib/screens/fees/create_fee_screen.dart
import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';

class CreateFeeScreen extends StatefulWidget {
  const CreateFeeScreen({super.key});
  @override
  State<CreateFeeScreen> createState() => _CreateFeeScreenState();
}

class _CreateFeeScreenState extends State<CreateFeeScreen> {
  final _formKey = GlobalKey<FormState>();
  List<Group> _groups = [];
  Group? _selectedGroup;
  final _feeCtl = TextEditingController();
  DateTime? _effectiveFrom;
  DateTime? _effectiveTo;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _feeCtl.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await ApiService.fetchGroups();
      setState(() {
        _groups = groups;
        _selectedGroup = groups.isNotEmpty ? groups.first : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(BuildContext ctx, bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom ? (_effectiveFrom ?? now) : (_effectiveTo ?? now);
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF9B6CFF))),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _effectiveFrom = picked;
        else _effectiveTo = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select group')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final fee = double.parse(_feeCtl.text.trim());
      await ApiService.createFeeStructure(
        groupId: _selectedGroup!.id,
        monthlyFee: fee,
        effectiveFrom: _effectiveFrom,
        effectiveTo: _effectiveTo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee created')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFBF8FF);
    const accent = Color(0xFF9B6CFF);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('Create Fee'), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black87),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('Create Fee'), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black87),
        body: Center(child: Text('Error: $_error')),
      );
    }

    String fmt(DateTime? d) => d == null ? 'Not set' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Create Fee Structure'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Intro card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 8))],
            ),
            child: const Text('Define monthly fee for a player group and set effective dates', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),

          // Form card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 8))],
            ),
            child: Form(
              key: _formKey,
              child: Column(children: [
                // group dropdown
                DropdownButtonFormField<Group>(
                  value: _selectedGroup,
                  items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                  onChanged: (g) => setState(() => _selectedGroup = g),
                  decoration: const InputDecoration(labelText: 'Group', filled: true, fillColor: Color(0xFFF7F9FF), border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10)))),
                  validator: (v) => v == null ? 'Choose a group' : null,
                ),
                const SizedBox(height: 12),

                // fee field
                TextFormField(
                  controller: _feeCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Monthly fee (INR)', filled: true, fillColor: Color(0xFFF7F9FF), border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10)))),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter monthly fee';
                    final num? val = num.tryParse(v);
                    if (val == null || val <= 0) return 'Enter a positive number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF7F9FF), borderRadius: BorderRadius.circular(10)),
                        child: Text('Effective from: ${fmt(_effectiveFrom)}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _pickDate(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF7F9FF), borderRadius: BorderRadius.circular(10)),
                        child: Text('Effective to: ${fmt(_effectiveTo)}'),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(MaterialState.disabled)) return Colors.grey.shade200;
                        return accent;
                      }),
                      foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                        if (states.contains(MaterialState.disabled)) return Colors.grey.shade600;
                        return Colors.white;
                      }),
                      padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
                      shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      elevation: MaterialStateProperty.resolveWith<double?>((states) => states.contains(MaterialState.disabled) ? 0 : 8),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Create Fee', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                )
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
