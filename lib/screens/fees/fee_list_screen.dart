// lib/screens/fees/fee_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/fee_structure.dart';
import '../../services/api_service.dart';
// import '../../services/data_manager.dart'; // ✅ UNCOMMENT when getFees() is added to DataManager
import '../../services/data_manager.dart';
import 'create_fee_screen.dart';

class FeeListScreen extends StatefulWidget {
  const FeeListScreen({super.key});

  @override
  State<FeeListScreen> createState() => _FeeListScreenState();
}

class _FeeListScreenState extends State<FeeListScreen> {
  List<FeeStructure> _feeStructures = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }
// ... inside _FeeListScreenState

  Future<void> _loadData() async {
    // 1. Instant Load from Cache
    final cachedFees = await DataManager().getFees();
    if (cachedFees.isNotEmpty) {
      if (mounted) {
        setState(() {
          _feeStructures = cachedFees;
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = true);
    }

    // 2. Background Refresh
    try {
      final freshFees = await DataManager().getFees(forceRefresh: true);
      if (mounted) {
        setState(() {
          _feeStructures = freshFees;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && _feeStructures.isEmpty) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  void _navigateToCreateFee() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateFeeScreen()),
    ).then((_) => _loadData());
  }

  Future<void> _deleteFee(FeeStructure fee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee'),
        content: Text('Delete fee of ₹${fee.monthlyFee}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteFeeStructure(fee.id);
        // DataManager().invalidateFees(); // ✅ Clear Cache
        _loadData(); // Reload
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _editFee(FeeStructure fee) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => EditFeeDialog(fee: fee),
    );
    if (result == true) {
      // DataManager().invalidateFees(); // ✅ Clear Cache
      _loadData();
    }
  }

  Map<String, List<FeeStructure>> _getFeesByGroup() {
    final map = <String, List<FeeStructure>>{};
    for (final fee in _feeStructures) {
      map.putIfAbsent(fee.groupName, () => []).add(fee);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final feesByGroup = _getFeesByGroup();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Structures'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateFee,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : feesByGroup.isEmpty
          ? const Center(child: Text('No fees found'))
          : ListView(
        padding: const EdgeInsets.all(8),
        children: feesByGroup.entries.map((entry) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                ),
                ...entry.value.map((fee) => ListTile(
                  leading: const Icon(Icons.attach_money, color: Colors.green),
                  title: Text('₹${fee.monthlyFee.toStringAsFixed(0)}'),
                  subtitle: Text(fee.effectiveFrom != null ? 'From: ${fee.effectiveFrom.toString().split(' ')[0]}' : 'Always active'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editFee(fee)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteFee(fee)),
                    ],
                  ),
                )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// -----------------------------------------------------------
// ✅ EDIT DIALOG (Logic Verified)
// -----------------------------------------------------------
class EditFeeDialog extends StatefulWidget {
  final FeeStructure fee;
  const EditFeeDialog({super.key, required this.fee});
  @override
  State<EditFeeDialog> createState() => _EditFeeDialogState();
}

class _EditFeeDialogState extends State<EditFeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _feeController = TextEditingController();
  DateTime? _effectiveFrom;
  DateTime? _effectiveTo;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _feeController.text = widget.fee.monthlyFee.toString();
    _effectiveFrom = widget.fee.effectiveFrom;
    _effectiveTo = widget.fee.effectiveTo;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final double monthlyFee = double.parse(_feeController.text.trim());
      final Map<String, dynamic> updateData = {
        'groupId': widget.fee.groupId, // ✅ Critical fix for backend validation
        'monthlyFee': monthlyFee,
        if (_effectiveFrom != null) 'effectiveFrom': _effectiveFrom!.toIso8601String().split('T')[0],
        if (_effectiveTo != null) 'effectiveTo': _effectiveTo!.toIso8601String().split('T')[0],
      };
      await ApiService.updateFeeStructure(widget.fee.id, updateData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_effectiveFrom ?? DateTime.now()) : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _effectiveFrom = picked; else _effectiveTo = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Fee'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Monthly Fee'),
              validator: (v) => v!.isEmpty ? 'Enter fee' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => _pickDate(true), child: Text(_effectiveFrom == null ? 'Start' : 'From: ${_effectiveFrom.toString().split(' ')[0]}'))),
                Expanded(child: TextButton(onPressed: () => _pickDate(false), child: Text(_effectiveTo == null ? 'End' : 'To: ${_effectiveTo.toString().split(' ')[0]}'))),
              ],
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text("Update")),
      ],
    );
  }
}