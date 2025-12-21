import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/fee_structure.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import 'create_fee_screen.dart';

class FeeListScreen extends StatefulWidget {
  const FeeListScreen({super.key});

  @override
  State<FeeListScreen> createState() => _FeeListScreenState();
}

class _FeeListScreenState extends State<FeeListScreen> {
  List<FeeStructure> _feeStructures = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final freshFees = await DataManager().getFees(forceRefresh: true);
      if (mounted) setState(() { _feeStructures = freshFees; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _deleteFee(FeeStructure fee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        title: const Text('Delete Fee', style: TextStyle(color: Colors.white)),
        content: Text('Delete fee of ₹${fee.monthlyFee}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteFeeStructure(fee.id);
        DataManager().invalidateFees();
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.redAccent));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Map<String, List<FeeStructure>> _getFeesByGroup() {
    final map = <String, List<FeeStructure>>{};
    for (final fee in _feeStructures) {
      map.putIfAbsent(fee.groupName, () => []).add(fee);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final feesByGroup = _getFeesByGroup();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Fee Structures', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.cyanAccent), onPressed: _loadData),
        ],
      ),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]))),
          Positioned(top: -50, right: -50, child: Container(height: 200, width: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 100)]))),

          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : feesByGroup.isEmpty
                ? const Center(child: Text('No fees found', style: TextStyle(color: Colors.white54)))
                : ListView(
              padding: const EdgeInsets.all(16),
              children: feesByGroup.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              color: Colors.white.withOpacity(0.1),
                              child: Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                            ),
                            ...entry.value.map((fee) => ListTile(
                              leading: const Icon(Icons.attach_money, color: Colors.greenAccent),
                              title: Text('₹${fee.monthlyFee.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              subtitle: Text(fee.effectiveFrom != null ? 'From: ${fee.effectiveFrom.toString().split(' ')[0]}' : 'Always active', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                              trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _deleteFee(fee)),
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFeeScreen())).then((_) => _loadData()),
        backgroundColor: Colors.cyanAccent,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}