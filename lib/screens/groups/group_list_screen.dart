import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/api_service.dart';
import '../../models/group.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({super.key});

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  final _box = Hive.box('app_cache');
  List<Group> _groups = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _loading = true);

    try {
      // Try to load from API first
      final apiGroups = await ApiService.fetchGroups();

      // Save to Hive cache
      final groupsJson = apiGroups.map((g) => g.toJson()).toList();
      await _box.put('groups_list', groupsJson);

      setState(() {
        _groups = apiGroups;
      });
    } catch (e) {
      // If API fails, try loading from Hive cache
      debugPrint('Failed to load groups from API: $e');

      final cachedData = _box.get('groups_list', defaultValue: []);
      if (cachedData is List) {
        setState(() {
          _groups = cachedData.map((json) => Group.fromJson(json)).toList();
        });
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveGroups() async {
    final groupsJson = _groups.map((g) => g.toJson()).toList();
    await _box.put('groups_list', groupsJson);
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')
          ),
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
      // Create group in API
      final createdGroup = await ApiService.createGroup(name: name);

      // Add to local list
      setState(() => _groups.add(createdGroup));

      // Save to Hive
      await _saveGroups();

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$name" created successfully'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e'))
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteGroup(int index) async {
    final group = _groups[index];

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Delete "${group.name}"? This will also delete associated fee structures.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')
          ),
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
      // Delete from API
      await ApiService.deleteGroup(group.id);

      // Remove from local list
      setState(() => _groups.removeAt(index));

      // Save to Hive
      await _saveGroups();

      // Also remove any fee structure for this group
      final feeBox = Hive.box('app_cache');
      final fees = Map<String, dynamic>.from(feeBox.get('fee_structures', defaultValue: {}));
      fees.remove(group.name);
      await feeBox.put('fee_structures', fees);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "${group.name}" deleted'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'))
      );
    } finally {
      setState(() => _loading = false);
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
            Text(
              'No groups added yet.\nTap + to add.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
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
                child: Text(
                  group.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.deepPurple),
                ),
              ),
              title: Text(
                group.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteGroup(i),
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