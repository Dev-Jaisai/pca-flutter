import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart'; // ✅ Import DataManager

class CreateFeeScreen extends StatefulWidget {
  const CreateFeeScreen({super.key});

  @override
  State<CreateFeeScreen> createState() => _CreateFeeScreenState();
}

class _CreateFeeScreenState extends State<CreateFeeScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Group> _groups = [];
  // ✅ FIX: Use ID (int) instead of Object (Group)
  int? _selectedGroupId;

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

  Future<void> _loadGroups() async {
    try {
      // 1. Try Cache First
      var groups = await DataManager().getGroups();

      // If cache empty, try force fetch
      if (groups.isEmpty) {
        groups = await DataManager().getGroups(forceRefresh: true);
      }

      if (mounted) {
        setState(() {
          _groups = groups;
          // ✅ FIX: Automatically select the first ID if valid
          if (groups.isNotEmpty) {
            // Only set default if nothing selected yet or selected is invalid
            if (_selectedGroupId == null || !_groups.any((g) => g.id == _selectedGroupId)) {
              _selectedGroupId = groups.first.id;
            }
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
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
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select group')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final fee = double.parse(_feeCtl.text.trim());

      // ✅ FIX: Use the selected ID directly
      final createdFee = await ApiService.createFeeStructure(
        groupId: _selectedGroupId!,
        monthlyFee: fee,
        effectiveFrom: _effectiveFrom,
        effectiveTo: _effectiveTo,
      );

      // Refresh cache so the list screen updates
      DataManager().invalidateFees();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fee ₹${createdFee.monthlyFee} created for ${createdFee.groupName}')),
      );
      Navigator.of(context).pop(true);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _feeCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Fee')),
        body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $_error'),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _loadGroups, child: const Text("Retry"))
              ],
            )
        ),
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
              // ✅ FIXED DROPDOWN
              DropdownButtonFormField<int>(
                value: _selectedGroupId,
                items: _groups.map((g) => DropdownMenuItem<int>(
                  value: g.id, // Store ID
                  child: Text(g.name),
                )).toList(),
                onChanged: (id) => setState(() => _selectedGroupId = id),
                decoration: const InputDecoration(labelText: 'Group', border: OutlineInputBorder()),
                validator: (v) => v == null ? 'Choose a group' : null,
              ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _feeCtl,
                decoration: const InputDecoration(labelText: 'Monthly Fee', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid amount' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_effectiveFrom == null ? 'Start Date' : _effectiveFrom!.toString().split(' ')[0]),
                      onPressed: () => _pickDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(_effectiveTo == null ? 'End Date' : _effectiveTo!.toString().split(' ')[0]),
                      onPressed: () => _pickDate(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Fee'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}