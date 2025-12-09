// lib/screens/installments/create_installment_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/fee_structure.dart';
import '../../services/api_service.dart';
import '../../utils/event_bus.dart'; // <-- added import

class CreateInstallmentScreen extends StatefulWidget {
  final Player player;
  const CreateInstallmentScreen({super.key, required this.player});

  @override
  State<CreateInstallmentScreen> createState() => _CreateInstallmentScreenState();
}

class _CreateInstallmentScreenState extends State<CreateInstallmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _monthCtl = TextEditingController();
  final _yearCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  DateTime? _dueDate;

  bool _submitting = false;
  bool _loadingFee = true;
  FeeStructure? _effectiveFee;
  String? _feeError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Prefill month/year with current month/year for convenience
    _monthCtl.text = now.month.toString();
    _yearCtl.text = now.year.toString();
    _loadEffectiveFee();
  }

  @override
  void dispose() {
    _monthCtl.dispose();
    _yearCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  Future<void> _loadEffectiveFee() async {
    setState(() {
      _loadingFee = true;
      _feeError = null;
    });

    try {
      final groupId = widget.player.groupId;
      if (groupId == null) {
        _feeError = 'Player has no group assigned';
        _effectiveFee = null;
      } else {
        final fee = await ApiService.fetchEffectiveFee(groupId);
        _effectiveFee = fee;
        if (fee != null) {
          // Prefill amount with group fee (editable)
          _amountCtl.text = fee.monthlyFee.toStringAsFixed(2);
        }
      }
    } catch (e) {
      _feeError = 'Failed to load group fee';
      // keep _effectiveFee null
    } finally {
      if (mounted) {
        setState(() {
          _loadingFee = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick a due date')));
      return;
    }

    final int month = int.parse(_monthCtl.text.trim());
    final int year = int.parse(_yearCtl.text.trim());
    final double? amount = _amountCtl.text.trim().isEmpty ? null : double.tryParse(_amountCtl.text.trim());

    setState(() => _submitting = true);
    try {
      // Use existing ApiService.createInstallment (matches your current code)
      await ApiService.createInstallment(
        playerId: widget.player.id,
        periodMonth: month,
        periodYear: year,
        dueDate: _dueDate!,
        amount: amount,
      );

      // Fire event so Dashboard (and other parts) refresh
      EventBus().fire(PlayerEvent('installment_created'));

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Installment created')));
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: Text('${widget.player.name} — Create Installment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _submitting
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Player: ${widget.player.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Month & Year
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _monthCtl,
                        decoration: const InputDecoration(labelText: 'Month (1-12)'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final val = int.tryParse(v ?? '');
                          if (val == null || val < 1 || val > 12) return 'Enter month 1-12';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _yearCtl,
                        decoration: const InputDecoration(labelText: 'Year (e.g., 2025)'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final val = int.tryParse(v ?? '');
                          if (val == null || val < 2000) return 'Enter valid year';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Amount field (prefilled with group fee if available)
                TextFormField(
                  controller: _amountCtl,
                  decoration: InputDecoration(
                    labelText: 'Amount (optional, leave blank for group fee)',
                    helperText: _loadingFee
                        ? 'Loading group fee…'
                        : _feeError != null
                        ? _feeError
                        : _effectiveFee != null
                        ? 'Group fee: ₹ ${_effectiveFee!.monthlyFee.toStringAsFixed(2)} (editable)'
                        : 'No group fee set for this group',
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null; // allow empty -> backend will use group fee
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Due date
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Due Date',
                        hintText: _dueDate == null ? 'Pick due date' : df.format(_dueDate!),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: const Text('Create Installment'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
