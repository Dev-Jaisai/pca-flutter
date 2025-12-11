// lib/screens/home/edit_player_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';

class EditPlayerScreen extends StatefulWidget {
  final Player player;

  const EditPlayerScreen({super.key, required this.player});

  @override
  State<EditPlayerScreen> createState() => _EditPlayerScreenState();
}

class _EditPlayerScreenState extends State<EditPlayerScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtl;
  late TextEditingController _phoneCtl;
  late TextEditingController _ageCtl;
  late TextEditingController _notesCtl;

  DateTime? _joinDate;
  int? _selectedGroupId;
  List<Group> _groups = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data
    _nameCtl = TextEditingController(text: widget.player.name);
    _phoneCtl = TextEditingController(text: widget.player.phone);
    _ageCtl = TextEditingController(text: widget.player.age?.toString() ?? '');
    _notesCtl = TextEditingController(text: widget.player.notes);
    _joinDate = widget.player.joinDate;
    _selectedGroupId = widget.player.groupId;

    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    try {
      final groups = await ApiService.fetchGroups();
      if (mounted) {
        setState(() {
          _groups = groups;
        });
      }
    } catch (e) {
      debugPrint('Error fetching groups: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a group')));
      return;
    }

    setState(() => _loading = true);

    try {
      // Match the fields expected by your PlayerRequestDTO in Java
      final Map<String, dynamic> data = {
        "name": _nameCtl.text.trim(),
        "phone": _phoneCtl.text.trim(),
        "age": int.tryParse(_ageCtl.text.trim()) ?? 0,
        "groupId": _selectedGroupId,
        "joinDate": _joinDate?.toIso8601String().split('T')[0], // YYYY-MM-DD
        "notes": _notesCtl.text.trim(),
        // "photoUrl": widget.player.photoUrl, // Preserve existing or add logic to update
      };

      await ApiService.updatePlayer(widget.player.id, data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player updated successfully')));
        Navigator.pop(context, true); // Return true to trigger refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _joinDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Player')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtl,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person)),
                validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtl,
                decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.length < 10) ? 'Enter valid number' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedGroupId, // This will pre-select the player's current group
                decoration: const InputDecoration(labelText: 'Group', prefixIcon: Icon(Icons.group)),
                items: _groups.map((g) {
                  return DropdownMenuItem(value: g.id, child: Text(g.name));
                }).toList(),
                onChanged: (val) => setState(() => _selectedGroupId = val),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Joining Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      hintText: _joinDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(_joinDate!),
                    ),
                    validator: (v) => _joinDate == null ? 'Date is required' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageCtl,
                decoration: const InputDecoration(labelText: 'Age', prefixIcon: Icon(Icons.cake)),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtl,
                decoration: const InputDecoration(labelText: 'Notes (Optional)', prefixIcon: Icon(Icons.note)),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Update Player'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}