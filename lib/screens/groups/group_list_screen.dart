import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
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

  Future<void> _loadGroups() async {
    try {
      final fresh = await DataManager().getGroups(forceRefresh: true);
      if (mounted) setState(() { _groups = fresh; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addGroup(String name) async {
    try {
      await ApiService.createGroup(name: name);
      DataManager().invalidateGroups();
      _loadGroups();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group Created'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent));
    }
  }

  void _showAddDialog() {
    final ctl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        title: const Text('New Group', style: TextStyle(color: Colors.white)),
        content: TextField(controller: ctl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () { if (ctl.text.isNotEmpty) { Navigator.pop(ctx); _addGroup(ctl.text.trim()); } },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  Future<void> _deleteGroup(Group g) async {
    try {
      await ApiService.deleteGroup(g.id);
      DataManager().invalidateGroups();
      _loadGroups();
    } catch (e) { debugPrint('$e'); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Manage Groups', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), actions: [IconButton(icon: const Icon(Icons.refresh, color: Colors.cyanAccent), onPressed: _loadGroups)]),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]))),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length,
              itemBuilder: (ctx, i) {
                final g = _groups[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.cyanAccent.withOpacity(0.2), child: Text(g.name[0], style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))),
                          title: Text(g.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteGroup(g)),
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
      floatingActionButton: FloatingActionButton(onPressed: _showAddDialog, backgroundColor: Colors.cyanAccent, child: const Icon(Icons.add, color: Colors.black)),
    );
  }
}