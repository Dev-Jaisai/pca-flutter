import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart'; // ✅ Import DataManager
import '../../models/group.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  List<Group> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  // ---------------------------------------------------------
  // 🚀 OPTIMIZED LOAD LOGIC
  // ---------------------------------------------------------
  Future<void> _loadGroups() async {
    // 1. Instant Load from Cache
    try {
      final cached = await DataManager().getGroups();
      if (cached.isNotEmpty) {
        if (mounted) setState(() { _groups = cached; _loading = false; });
      } else {
        // Only show spinner if absolutely no data
        if (mounted) setState(() => _loading = true);
      }
    } catch (e) {
      // Ignore cache errors
    }

    // 2. Fresh Fetch from API (Background)
    try {
      final fresh = await DataManager().getGroups(forceRefresh: true);
      if (mounted) setState(() { _groups = fresh; _loading = false; });
    } catch (e) {
      if (mounted && _groups.isEmpty) {
        setState(() => _loading = false); // Stop spinner on error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  void _addGroup() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Group Name (e.g. Junior)'),
          textCapitalization: TextCapitalization.sentences,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _createGroup(name);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroup(String name) async {
    setState(() => _loading = true);
    try {
      await ApiService.createGroup(name: name);

      // ✅ Invalidate Cache so dropdowns elsewhere update immediately
      DataManager().invalidateGroups();

      await _loadGroups(); // Refresh list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Group "$name" created')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteGroup(Group group) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Delete "${group.name}"? This might affect fees linked to it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _loading = true);
    try {
      await ApiService.deleteGroup(group.id);

      // ✅ Clear Caches
      DataManager().invalidateGroups();
      DataManager().invalidateFees(); // Fees might be deleted on backend cascade

      await _loadGroups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Group "${group.name}" deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroups,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No groups added yet.\nTap + to add.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final group = _groups[i];
          return Card(
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade50,
                child: Text(group.name.isNotEmpty ? group.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.deepPurple)),
              ),
              title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteGroup(group),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGroup,
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
    );
  }
}