// lib/screens/groups/group_list_screen.dart
import 'package:flutter/material.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';
import 'create_group_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});
  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  late Future<List<Group>> _futureGroups;

  @override
  void initState() {
    super.initState();
    _futureGroups = ApiService.fetchGroups();
  }

  void _load() {
    setState(() {
      _futureGroups = ApiService.fetchGroups();
    });
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _confirmDelete(Group group) async {
    final should = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete group'),
        content: Text('Delete group "${group.name}"? This may affect players.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (should == true) {
      try {
        await ApiService.deleteGroup(group.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${group.name}')));
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFBF8FF);
    const accent = Color(0xFF9B6CFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Groups'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<Group>>(
        future: _futureGroups,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final list = snap.data ?? [];
          if (list.isEmpty)
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.group_work_outlined, size: 56, color: Colors.black26),
                  SizedBox(height: 12),
                  Text('No groups yet. Create one.', style: TextStyle(color: Colors.black54)),
                ],
              ),
            );

          return RefreshIndicator(
            onRefresh: () async {
              _load();
              await _futureGroups;
            },
            color: accent,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final g = list[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  elevation: 6,
                  shadowColor: Colors.black12,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // optionally open a group-detail or filter players by group in future
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFF3F5FF),
                            child: Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _confirmDelete(g),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Add Group'),
        backgroundColor: accent,
      ),
    );
  }
}
