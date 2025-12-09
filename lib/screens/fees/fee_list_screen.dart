// lib/screens/fees/fee_list_screen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';

class FeeListScreen extends StatefulWidget {
  const FeeListScreen({super.key});

  @override
  State<FeeListScreen> createState() => _FeeListScreenState();
}

class _FeeListScreenState extends State<FeeListScreen> {
  final _box = Hive.box('app_cache');

  // Map groupName -> fee
  Map<String, double> _fees = {};
  // Groups loaded from cache or API
  List<Group> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await _loadGroups();
    _loadFeesFromHive();
    setState(() => _loading = false);
  }

  Future<void> _loadGroups() async {
    // 1) Try Hive cache
    try {
      final cachedGroups = _box.get('groups_list', defaultValue: []);
      if (cachedGroups is List && cachedGroups.isNotEmpty) {
        final parsed = cachedGroups.map((json) {
          try {
            if (json is Map<String, dynamic>) return Group.fromJson(json);
            if (json is Map) return Group.fromJson(Map<String, dynamic>.from(json));
          } catch (_) {}
          return null;
        }).whereType<Group>().toList();

        // sanitize: remove id==0 and dedupe by id
        final map = <int, Group>{};
        for (final g in parsed) {
          if (g.id != 0) map.putIfAbsent(g.id, () => g);
        }
        if (map.isNotEmpty) {
          _groups = map.values.toList();
          // do not return yet — we'll still try API to refresh cache
        }
      }
    } catch (e) {
      debugPrint('FeeList: load groups from hive failed: $e');
    }

    // 2) Try API to refresh groups (and persist)
    try {
      final apiGroups = await ApiService.fetchGroups();
      if (apiGroups.isNotEmpty) {
        // sanitize and dedupe
        final apiMap = <int, Group>{};
        for (final g in apiGroups) {
          if (g.id != 0) apiMap.putIfAbsent(g.id, () => g);
        }
        _groups = apiMap.values.toList();

        // persist cleaned json to hive for next time
        try {
          final groupsJson = _groups.map((g) => g.toJson()).toList();
          await _box.put('groups_list', groupsJson);
        } catch (e) {
          debugPrint('FeeList: failed to save groups to hive: $e');
        }
      }
    } catch (e) {
      debugPrint('FeeList: fetchGroups API failed: $e');
      // keep whatever we had from cache (if any)
    }
  }

  void _loadFeesFromHive() {
    try {
      final raw = _box.get('fee_structures', defaultValue: <dynamic, dynamic>{});
      if (raw is Map) {
        _fees = raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      } else {
        _fees = {};
      }
    } catch (e) {
      debugPrint('FeeList: load fees failed: $e');
      _fees = {};
    }
  }

  Future<void> _saveFees() async {
    try {
      await _box.put('fee_structures', _fees);
      setState(() {});
    } catch (e) {
      debugPrint('FeeList: save fees failed: $e');
    }
  }

  // Count how many groups have no fee assigned
  int _groupsWithoutFeesCount() {
    if (_groups.isEmpty) return 0;
    final namesWithFee = _fees.keys.toSet();
    return _groups.where((g) => !namesWithFee.contains(g.name)).length;
  }

  // Open add/edit dialog: if editing, pass existing groupName; else null
  void _addOrEditFee({String? existingGroup}) {
    String? selectedGroup = existingGroup;
    final amountCtl = TextEditingController(text: existingGroup != null ? (_fees[existingGroup]?.toStringAsFixed(0) ?? '') : '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existingGroup == null ? 'Add Fee for Group' : 'Edit Fee'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dropdown to pick a group
              DropdownButtonFormField<String>(
                value: selectedGroup,
                decoration: const InputDecoration(labelText: 'Group'),
                items: _groups.map((g) => DropdownMenuItem(value: g.name, child: Text(g.name))).toList(),
                onChanged: (v) {
                  selectedGroup = v;
                  // If selectedGroup has fee, update amountCtl
                  final fee = (v != null) ? _fees[v] : null;
                  amountCtl.text = fee != null ? fee.toStringAsFixed(0) : '';
                  (ctx as Element).markNeedsBuild(); // update dialog UI
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtl,
                decoration: const InputDecoration(labelText: 'Monthly Fee (₹)', prefixText: '₹ '),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final gname = selectedGroup;
                final amount = double.tryParse(amountCtl.text.trim()) ?? 0.0;
                if (gname == null || gname.isEmpty) return; // do nothing if group not selected
                if (amount <= 0) return; // require positive fee

                // Save
                setState(() => _fees[gname] = amount);
                _saveFees();
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteFee(String group) {
    setState(() => _fees.remove(group));
    _saveFees();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _fees.entries.toList();
    final missingCount = _groupsWithoutFeesCount();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Structures'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: 'Reload groups & fees',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (missingCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: GestureDetector(
                onTap: () {
                  // open add dialog with first group that lacks fee preselected
                  final missingGroup = _groups.firstWhere((g) => !_fees.containsKey(g.name), orElse: () => Group(id: 0, name: ''));
                  if (missingGroup.id != 0) _addOrEditFee(existingGroup: missingGroup.name);
                  else _addOrEditFee();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 10),
                      Expanded(child: Text('$missingCount group(s) without fee structure', style: const TextStyle(color: Colors.black87))),
                      const Icon(Icons.keyboard_arrow_right, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text('No fee structures defined.\nTap + to add.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])))
                : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final entry = entries[i];
                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: const Icon(Icons.currency_rupee, color: Colors.green, size: 20),
                    ),
                    title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Monthly Fee: ₹${entry.value.toStringAsFixed(0)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _addOrEditFee(existingGroup: entry.key)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteFee(entry.key)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Open dialog; allow selecting from all groups
          _addOrEditFee();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Fee'),
      ),
    );
  }
}
