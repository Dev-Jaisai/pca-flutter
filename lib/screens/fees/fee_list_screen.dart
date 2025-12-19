// lib/screens/fees/fee_list_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/group.dart';
import '../../models/fee_structure.dart';
import '../../services/api_service.dart';
import 'create_fee_screen.dart';

class FeeListScreen extends StatefulWidget {
  const FeeListScreen({super.key});

  @override
  State<FeeListScreen> createState() => _FeeListScreenState();
}

class _FeeListScreenState extends State<FeeListScreen> {
  final _box = Hive.box('app_cache');
  List<Group> _groups = [];
  List<FeeStructure> _feeStructures = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ✅ FULLY FIXED DATA LOADING METHOD
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ FIRST load groups
      final List<Group> groups = await ApiService.fetchGroups();

      // ✅ THEN load fees group-wise
      final List<FeeStructure> allFees = [];
      for (final group in groups) {
        final List<FeeStructure> fees =
        await ApiService.fetchFeesByGroup(group.id);
        allFees.addAll(fees);
      }

      setState(() {
        _groups = groups;
        _feeStructures = allFees;
      });

      // ✅ Save to cache
      await _saveToCache(groups, allFees);
    } catch (e) {
      debugPrint('API failed, loading from cache: $e');
      _loadFromCache();
    } finally {
      setState(() => _loading = false);
    }
  }

  // ✅ LOAD FROM CACHE
  void _loadFromCache() {
    try {
      final cachedGroups = _box.get('groups_list', defaultValue: []);
      if (cachedGroups is List) {
        final groups =
        cachedGroups.map((json) => Group.fromJson(json)).toList();
        setState(() => _groups = groups);
      }

      final cachedFees = _box.get('fee_structures_api', defaultValue: []);
      if (cachedFees is List) {
        final fees = cachedFees
            .map((json) => FeeStructure.fromJson(json))
            .toList();
        setState(() => _feeStructures = fees);
      }
    } catch (e) {
      setState(() => _error = 'Failed to load cached data: $e');
    }
  }

  // ✅ SAVE TO CACHE
  Future<void> _saveToCache(
      List<Group> groups, List<FeeStructure> fees) async {
    try {
      await _box.put(
          'groups_list', groups.map((g) => g.toJson()).toList());
      await _box.put('fee_structures_api',
          fees.map((f) => f.toJson()).toList());
    } catch (e) {
      debugPrint('Cache save failed: $e');
    }
  }

  void _navigateToCreateFee() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateFeeScreen()),
    ).then((_) => _loadData());
  }

  Future<void> _editFee(FeeStructure fee) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => EditFeeDialog(fee: fee),
    );

    if (result == true) _loadData();
  }

  Future<void> _deleteFee(FeeStructure fee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Fee Structure'),
        content: Text('Delete fee of ₹${fee.monthlyFee} for ${fee.groupName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ApiService.deleteFeeStructure(fee.id); // Call the new API
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee structure deleted')),
        );
        _loadData(); // Refresh list
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  // ✅ GROUP FEES BY GROUP NAME
  Map<String, List<FeeStructure>> _getFeesByGroup() {
    final map = <String, List<FeeStructure>>{};
    for (final fee in _feeStructures) {
      final groupName = fee.groupName;
      map.putIfAbsent(groupName, () => []).add(fee);
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _groups.isEmpty
          ? const Center(child: Text('No groups found'))
          : feesByGroup.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.attach_money,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No fee structures defined'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _navigateToCreateFee,
              child: const Text('Create First Fee'),
            ),
          ],
        ),
      )
          : ListView(
        children: [
          ...feesByGroup.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...entry.value.map((fee) => ListTile(
                    leading: const Icon(
                        Icons.attach_money,
                        color: Colors.green),
                    title: Text(
                        '₹${fee.monthlyFee.toStringAsFixed(0)} per month'),
                    subtitle: Text(
                      'Effective: ${fee.effectiveFrom?.toString().split(' ')[0] ?? 'Now'}'
                          '${fee.effectiveTo != null ? ' to ${fee.effectiveTo?.toString().split(' ')[0]}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blue),
                          onPressed: () =>
                              _editFee(fee),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red),
                          onPressed: () =>
                              _deleteFee(fee),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateFee,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ✅ EDIT DIALOG (UNCHANGED LOGIC)
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
  }Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final double monthlyFee = double.parse(_feeController.text.trim());

      final Map<String, dynamic> updateData = {
        // ✅ CRITICAL FIX: Sending the groupId from your model
        'groupId': widget.fee.groupId,

        'monthlyFee': monthlyFee,
        if (_effectiveFrom != null) 'effectiveFrom': _effectiveFrom!.toIso8601String().split('T')[0],
        if (_effectiveTo != null) 'effectiveTo': _effectiveTo!.toIso8601String().split('T')[0],
      };

      await ApiService.updateFeeStructure(widget.fee.id, updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fee structure updated')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
      isFrom ? (_effectiveFrom ?? DateTime.now()) : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _effectiveFrom = picked;
        } else {
          _effectiveTo = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Fee Structure'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _feeController,
              decoration: const InputDecoration(labelText: 'Monthly Fee'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter fee amount';
                final amount = double.tryParse(v);
                if (amount == null || amount <= 0) {
                  return 'Enter valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _pickDate(true),
                    child: Text(_effectiveFrom == null
                        ? 'Set Start Date'
                        : 'From: ${_effectiveFrom!.toString().split(' ')[0]}'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _pickDate(false),
                    child: Text(_effectiveTo == null
                        ? 'Set End Date'
                        : 'To: ${_effectiveTo!.toString().split(' ')[0]}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
              height: 20, width: 20, child: CircularProgressIndicator())
              : const Text('Update'),
        ),
      ],
    );
  }
}
