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
        _error = 'Failed to load groups: $e';
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

      // THIS IS THE KEY LINE - Saving to MySQL via API
      final createdFee = await ApiService.createFeeStructure(
        groupId: _selectedGroup!.id,
        monthlyFee: fee,
        effectiveFrom: _effectiveFrom,
        effectiveTo: _effectiveTo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fee ₹${createdFee.monthlyFee} created for ${createdFee.groupName}')),
      );

      Navigator.of(context).pop(true); // Return success

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Create failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Fee')),
        body: Center(child: Text('Error: $_error')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Create Fee Structure')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<Group>(
                value: _selectedGroup,
                items: _groups.map((g) => DropdownMenuItem(
                  value: g,
                  child: Text(g.name),
                )).toList(),
                onChanged: (g) => setState(() => _selectedGroup = g),
                decoration: const InputDecoration(labelText: 'Group'),
                validator: (v) => v == null ? 'Choose a group' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _feeCtl,
                decoration: const InputDecoration(labelText: 'Monthly Fee'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter fee amount';
                  final amount = double.tryParse(v);
                  if (amount == null || amount <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_effectiveFrom == null
                          ? 'Start Date'
                          : 'From: ${_effectiveFrom!.toString().split(' ')[0]}'),
                      onPressed: () => _pickDate(context, true),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_effectiveTo == null
                          ? 'End Date'
                          : 'To: ${_effectiveTo!.toString().split(' ')[0]}'),
                      onPressed: () => _pickDate(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const CircularProgressIndicator()
                      : const Text('Create Fee in Database'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
