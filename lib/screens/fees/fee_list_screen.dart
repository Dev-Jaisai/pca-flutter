// lib/screens/fees/fee_list_screen.dart
import 'package:flutter/material.dart';
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
  List<Group> _groups = [];
  Group? _selectedGroup;
  Future<List<FeeStructure>>? _futureFees;
  bool _loadingGroups = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() { _loadingGroups = true; _error = null; });
    try {
      final groups = await ApiService.fetchGroups();
      setState(() {
        _groups = groups;
        if (groups.isNotEmpty) _selectedGroup = groups.first;
        _loadingGroups = false;
      });
      if (_selectedGroup != null) _loadFeesFor(_selectedGroup!);
    } catch (e) {
      setState(() { _error = '$e'; _loadingGroups = false; });
    }
  }

  void _loadFeesFor(Group group) {
    setState(() {
      _selectedGroup = group;
      _futureFees = ApiService.fetchFeesByGroup(group.id);
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateFeeScreen()),
    );
    if (created == true && _selectedGroup != null) {
      _loadFeesFor(_selectedGroup!);
    }
  }

  Widget _buildFeeTile(FeeStructure f) {
    String fmtDate(DateTime? d) => d == null ? '-' : '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

    return ListTile(
      title: Text('₹ ${f.monthlyFee.toStringAsFixed(2)}'),
      subtitle: Text('From: ${fmtDate(f.effectiveFrom)}  To: ${fmtDate(f.effectiveTo)}'),
      trailing: Text(f.id == 0 ? '' : '#${f.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fee Structures')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: _loadingGroups
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text('Error: $_error'))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Group', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropdownButton<Group>(
              isExpanded: true,
              value: _selectedGroup,
              items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
              onChanged: (g) {
                if (g != null) _loadFeesFor(g);
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _selectedGroup == null
                  ? const Center(child: Text('No group selected'))
                  : FutureBuilder<List<FeeStructure>>(
                future: _futureFees,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                  final list = snap.data ?? [];
                  if (list.isEmpty) return const Center(child: Text('No fee history for this group.'));
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) => _buildFeeTile(list[i]),
                  );
                },
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Create Fee'),
      ),
    );
  }
}
