import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../payments/payment_list_screen.dart';

class AllInstallmentsScreen extends StatefulWidget {
  const AllInstallmentsScreen({super.key});

  @override
  State<AllInstallmentsScreen> createState() => _AllInstallmentsScreenState();
}

class _AllInstallmentsScreenState extends State<AllInstallmentsScreen> {
  bool _loading = true;
  String? _error;
  List<PlayerInstallmentSummary> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Use the NEW endpoint that shows ALL installments
      final list = await ApiService.fetchAllInstallmentsSummary();
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPayments(PlayerInstallmentSummary row) {
    if (row.installmentId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentsListScreen(
            installmentId: row.installmentId!,
            remainingAmount: row.remaining,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No installment exists for this player.')),
      );
    }
  }

  Widget _buildRow(PlayerInstallmentSummary p) {
    final df = DateFormat('dd MMM yyyy');

    Color getStatusColor(String status) {
      switch (status) {
        case 'PAID': return Colors.green;
        case 'PARTIALLY_PAID': return Colors.orange;
        case 'PENDING': return Colors.blue;
        case 'OVERDUE': return Colors.red;
        case 'NO_INSTALLMENT': return Colors.grey;
        default: return Colors.grey;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Player Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                p.playerName.isNotEmpty ? p.playerName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),

            const SizedBox(width: 12),

            // Player Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.playerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '${p.groupName ?? ''} • ${p.phone ?? ''}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Installment Details
                  if (p.installmentId != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount: ₹${p.installmentAmount?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Paid: ₹${p.totalPaid.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Left: ${p.remaining != null ? '₹${p.remaining!.toStringAsFixed(2)}' : '—'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (p.dueDate != null)
                          Text(
                            'Due: ${df.format(p.dueDate!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.dueDate!.isBefore(DateTime.now())
                                  ? Colors.red
                                  : Colors.grey,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: getStatusColor(p.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: getStatusColor(p.status)),
              ),
              child: Text(
                p.status.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: getStatusColor(p.status),
                ),
              ),
            ),

            // Action Button
            if (p.installmentId != null)
              IconButton(
                icon: const Icon(Icons.payment, color: Colors.deepPurple),
                onPressed: () => _openPayments(p),
                tooltip: 'View Payments',
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Installments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _items.isEmpty
          ? const Center(child: Text('No installments found'))
          : RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: _items.length,
          itemBuilder: (ctx, i) => _buildRow(_items[i]),
        ),
      ),
    );
  }
}