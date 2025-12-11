// lib/screens/installments/create_installment_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/fee_structure.dart';
import '../../services/api_service.dart';
import '../../utils/event_bus.dart';

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
    // Prefill month/year with current month/year
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
      await ApiService.createInstallment(
        playerId: widget.player.id,
        periodMonth: month,
        periodYear: year,
        dueDate: _dueDate!,
        amount: amount,
      );

      EventBus().fire(PlayerEvent('installment_created'));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Installment created')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('New Installment'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _submitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. PLAYER INFO CARD ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.deepPurple.shade100,
                      child: Icon(Icons.person, color: Colors.deepPurple.shade700),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Creating Installment For:",
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w500
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.player.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- 2. PERIOD INPUTS ---
              const Text("Installment Period", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _monthCtl,
                      decoration: InputDecoration(
                        labelText: 'Month',
                        hintText: '1-12',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final val = int.tryParse(v ?? '');
                        if (val == null || val < 1 || val > 12) return 'Invalid Month';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _yearCtl,
                      decoration: InputDecoration(
                        labelText: 'Year',
                        hintText: 'e.g. 2025',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final val = int.tryParse(v ?? '');
                        if (val == null || val < 2000) return 'Invalid Year';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- 3. AMOUNT ---
              const Text("Payment Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtl,
                decoration: InputDecoration(
                  labelText: 'Installment Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: _loadingFee
                      ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  helperText: _loadingFee
                      ? 'Fetching group fee...'
                      : _effectiveFee != null
                      ? 'Default Group Fee: ₹${_effectiveFee!.monthlyFee}'
                      : 'No default fee found',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // Backend uses default
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter valid amount';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // --- 4. DUE DATE ---
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.deepPurple),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _dueDate == null ? 'Select Due Date *' : df.format(_dueDate!),
                          style: TextStyle(
                            fontSize: 16,
                            color: _dueDate == null ? Colors.grey.shade600 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  child: const Text('Create Installment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}