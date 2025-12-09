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
    // assign the Future synchronously (safe)
    _futureGroups = ApiService.fetchGroups();
  }

  // Use this to reload the list (assign the Future again inside setState)
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted ${group.name}')));
        _load();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: FutureBuilder<List<Group>>(
        future: _futureGroups,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final list = snap.data ?? [];
          if (list.isEmpty) return const Center(child: Text('No groups yet. Create one.'));
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final g = list[i];
              return ListTile(
                leading: CircleAvatar(child: Text(g.name.isNotEmpty ? g.name[0].toUpperCase() : '?')),
                title: Text(g.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(g),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Add Group'),
      ),
    );
  }
}
