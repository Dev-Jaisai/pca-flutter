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
      setState(() { _error = '$e'; _loading = false; });
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
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _effectiveFrom = picked; else _effectiveTo = picked;
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fee created')));
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Fee')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Create Fee')), body: Center(child: Text('Error: $_error')));

    String fmt(DateTime? d) => d == null ? 'Not set' : '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Create Fee Structure')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButtonFormField<Group>(
              value: _selectedGroup,
              items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
              onChanged: (g) => setState(() => _selectedGroup = g),
              decoration: const InputDecoration(labelText: 'Group'),
              validator: (v) => v == null ? 'Choose a group' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _feeCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monthly fee (INR)'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter monthly fee';
                final num? val = num.tryParse(v);
                if (val == null || val <= 0) return 'Enter a positive number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('Effective from: ${fmt(_effectiveFrom)}')),
              TextButton(onPressed: () => _pickDate(context, true), child: const Text('Pick'))
            ]),
            Row(children: [
              Expanded(child: Text('Effective to: ${fmt(_effectiveTo)}')),
              TextButton(onPressed: () => _pickDate(context, false), child: const Text('Pick'))
            ]),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)) : const Text('Create Fee'),
              ),
            )
          ]),
        ),
      ),
    );
  }
}
