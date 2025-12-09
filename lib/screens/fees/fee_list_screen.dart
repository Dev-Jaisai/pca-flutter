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
    setState(() {
      _loadingGroups = true;
      _error = null;
    });
    try {
      final groups = await ApiService.fetchGroups();
      setState(() {
        _groups = groups;
        if (groups.isNotEmpty) _selectedGroup = groups.first;
        _loadingGroups = false;
      });
      if (_selectedGroup != null) _loadFeesFor(_selectedGroup!);
    } catch (e) {
      setState(() {
        _error = '$e';
        _loadingGroups = false;
      });
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
      MaterialPageRoute(builder: (_) => const CreateFeeScreen()),
    );
    if (created == true && _selectedGroup != null) {
      _loadFeesFor(_selectedGroup!);
    }
  }

  Widget _buildFeeTile(FeeStructure f) {
    String fmtDate(DateTime? d) => d == null ? '-' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 6,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: const Color(0xFFF3F5FF), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.attach_money, color: Color(0xFF6067FF)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('₹ ${f.monthlyFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text('From: ${fmtDate(f.effectiveFrom)}  To: ${fmtDate(f.effectiveTo)}', style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(f.id == 0 ? '' : '#${f.id}', style: const TextStyle(color: Colors.black45)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFBF8FF);
    const accent = Color(0xFF9B6CFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Fee Structures'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFF7F9FF), borderRadius: BorderRadius.circular(10)),
              child: DropdownButton<Group>(
                isExpanded: true,
                value: _selectedGroup,
                items: _groups.map((g) => DropdownMenuItem(value: g, child: Text(g.name))).toList(),
                onChanged: (g) {
                  if (g != null) _loadFeesFor(g);
                },
                underline: const SizedBox.shrink(),
              ),
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
                  return RefreshIndicator(
                    onRefresh: () async {
                      if (_selectedGroup != null) _loadFeesFor(_selectedGroup!);
                      await _futureFees;
                    },
                    color: accent,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _buildFeeTile(list[i]),
                    ),
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
        backgroundColor: accent,
      ),
    );
  }
}
