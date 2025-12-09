import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/group.dart';
import '../../services/api_service.dart';
import '../../utils/event_bus.dart'; // Add this import
// Replace your existing AddPlayerScreen / _AddPlayerScreenState with this code.

class AddPlayerScreen extends StatefulWidget {
  const AddPlayerScreen({super.key});

  @override
  State<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends State<AddPlayerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _ageCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  final _photoCtl = TextEditingController();

  List<Group> _groups = [];
  int? _selectedGroupId;
  DateTime? _joinDate;
  DateTime? _installmentDueDate; // <-- user-selected due date
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final g = await ApiService.fetchGroups();
      setState(() {
        _groups = g;
        if (_groups.isNotEmpty) _selectedGroupId = _groups.first.id;
      });
    } catch (e) {
      // ignore - groups may be empty
      setState(() {});
    }
  }

  Future<void> _pickJoinDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate ?? now,
      firstDate: DateTime(1990),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _joinDate = picked);
  }

  Future<void> _pickInstallmentDueDate() async {
    final now = DateTime.now();
    final initial = _installmentDueDate ?? (_joinDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _installmentDueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a group')));
      return;
    }
    if (_joinDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick join date')));
      return;
    }
    // Require the user to pick due date manually
    if (_installmentDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick an installment due date')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1) Create player
      final createdPlayer = await ApiService.createPlayer(
        name: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim(),
        age: _ageCtl.text.isEmpty ? null : int.tryParse(_ageCtl.text.trim()),
        joinDate: _joinDate,
        groupId: _selectedGroupId!,
        notes: _notesCtl.text.isEmpty ? null : _notesCtl.text.trim(),
        photoUrl: _photoCtl.text.isEmpty ? null : _photoCtl.text.trim(),
      );

      final int playerId = createdPlayer.id;

      // 2) Create installment for the selected due date
      final due = _installmentDueDate!;
      final int month = due.month;
      final int year = due.year;

      // Call ApiService.createInstallment which accepts nullable amount (backend picks group fee)
      await ApiService.createInstallment(
        playerId: playerId,
        periodMonth: month,
        periodYear: year,
        dueDate: due,
        amount: null, // let backend pick group fee
      );

      // 3) Notify dashboard and other listeners
      EventBus().fire(PlayerEvent('added'));
      EventBus().fire(PlayerEvent('installment_created'));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player + Installment Created')));
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _ageCtl.dispose();
    _notesCtl.dispose();
    _photoCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Add Player')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageCtl,
                        decoration: const InputDecoration(labelText: 'Age'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickJoinDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Join Date',
                              hintText: _joinDate == null ? 'Select date' : df.format(_joinDate!),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Group dropdown
                DropdownButtonFormField<int>(
                  value: _selectedGroupId,
                  decoration: const InputDecoration(labelText: 'Group'),
                  items: _groups.map((g) => DropdownMenuItem<int>(value: g.id, child: Text(g.name))).toList(),
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                  validator: (v) => (v == null) ? 'Group is required' : null,
                ),

                const SizedBox(height: 12),

                // Installment Due Date - manual selection
                GestureDetector(
                  onTap: _pickInstallmentDueDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Installment Due Date (required)',
                        hintText: _installmentDueDate == null ? 'Select due date' : df.format(_installmentDueDate!),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtl,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _photoCtl,
                  decoration: const InputDecoration(labelText: 'Photo URL (optional)'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Create Player'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
