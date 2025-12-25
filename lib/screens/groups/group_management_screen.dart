import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../models/group.dart';

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({super.key});

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  List<Group> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final fresh = await DataManager().getGroups(forceRefresh: true);
      if (mounted) setState(() { _groups = fresh; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- ADD / EDIT DIALOG (Merged Logic) ---
  void _showGroupDialog({Group? groupToEdit}) {
    final isEdit = groupToEdit != null;
    final nameCtl = TextEditingController(text: isEdit ? groupToEdit.name : '');
    final feeCtl = TextEditingController(text: isEdit ? groupToEdit.currentFee.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Edit Group' : 'Add New Group', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.group, color: Colors.cyanAccent),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.cyanAccent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feeCtl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Monthly Fee (₹)',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.attach_money, color: Colors.greenAccent),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.greenAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtl.text.isNotEmpty && feeCtl.text.isNotEmpty) {
                Navigator.pop(ctx);
                final name = nameCtl.text.trim();
                final fee = double.tryParse(feeCtl.text.trim()) ?? 0;

                if (isEdit) {
                  await _updateGroup(groupToEdit.id, name, fee);
                } else {
                  await _createGroup(name, fee);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: Text(isEdit ? 'Update' : 'Save'),
          )
        ],
      ),
    );
  }

  Future<void> _createGroup(String name, double fee) async {
    setState(() => _loading = true);
    try {
      await ApiService.createGroup(name: name, fee: fee);
      await _refreshData();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group Created!'), backgroundColor: Colors.green));
    } catch (e) {
      _handleError(e);
    }
  }

  // 🔥 NEW: Update Function
  Future<void> _updateGroup(int id, String name, double fee) async {
    setState(() => _loading = true);
    try {
      await ApiService.updateGroup(id, name, fee);
      await _refreshData();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group Updated!'), backgroundColor: Colors.green));
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> _deleteGroup(Group g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        title: const Text('Delete Group?', style: TextStyle(color: Colors.white)),
        content: Text('Deleting "${g.name}" will remove all players and data.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await ApiService.deleteGroup(g.id);
        await _refreshData();
      } catch (e) {
        _handleError(e);
      }
    }
  }

  Future<void> _refreshData() async {
    DataManager().invalidateGroups();
    DataManager().invalidateFees();
    await _loadGroups();
  }

  void _handleError(Object e) {
    if(mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Groups & Fees', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.cyanAccent), onPressed: _loadGroups)
        ],
      ),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]))),

          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _groups.isEmpty
                ? const Center(child: Text("No groups found.", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length,
              itemBuilder: (ctx, i) {
                final g = _groups[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                            child: const Icon(Icons.groups, color: Colors.cyanAccent, size: 20),
                          ),
                          title: Text(g.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('Fee: ₹${g.currentFee.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 🔥 EDIT BUTTON
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orangeAccent),
                                onPressed: () => _showGroupDialog(groupToEdit: g),
                              ),
                              // 🔥 DELETE BUTTON
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => _deleteGroup(g),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGroupDialog(),
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text("New Group"),
      ),
    );
  }
}