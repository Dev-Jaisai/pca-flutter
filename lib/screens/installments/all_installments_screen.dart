// lib/screens/installments/all_installments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart'; // Ensure you have shimmer package
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart'; // Import DataManager
import '../payments/payment_list_screen.dart';

class AllInstallmentsScreen extends StatefulWidget {
  const AllInstallmentsScreen({super.key});

  @override
  State<AllInstallmentsScreen> createState() => _AllInstallmentsScreenState();
}

class _AllInstallmentsScreenState extends State<AllInstallmentsScreen> {
  // If true, show shimmer (only if no cache available)
  bool _showShimmer = true;
  String? _error;
  List<PlayerInstallmentSummary> _items = [];

  // Precomputed formatting
  final Map<int, String> _formattedDue = {};
  final Map<int, Color> _statusColor = {};
  final df = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    // 1. Load Sync (Instant)
    _loadFromCache();
    // 2. Fetch Async (Background)
    _fetchFromApi();
  }

  void _loadFromCache() {
    final cached = DataManager().getCachedAllInstallments();
    if (cached != null && cached.isNotEmpty) {
      _processAndSetItems(cached, stopShimmer: true);
    }
  }

  Future<void> _fetchFromApi() async {
    try {
      final list = await ApiService.fetchAllInstallmentsSummary();

      // Save to cache for next time
      await DataManager().saveAllInstallments(list);

      if (mounted) {
        _processAndSetItems(list, stopShimmer: true);
        setState(() => _error = null);
      }
    } catch (e) {
      if (mounted) {
        // Only show error text if we have NO data at all
        if (_items.isEmpty) {
          setState(() {
            _error = e.toString();
            _showShimmer = false;
          });
        }
      }
    }
  }

  // Helper to pre-calculate colors and dates efficiently
  void _processAndSetItems(List<PlayerInstallmentSummary> list, {required bool stopShimmer}) {
    // Clear maps to avoid memory growth on repeats
    _formattedDue.clear();
    _statusColor.clear();

    for (final p in list) {
      _formattedDue[p.hashCode] = p.dueDate != null ? df.format(p.dueDate!) : '—';
      _statusColor[p.hashCode] = _calculateStatusColor(p.status);
    }

    setState(() {
      _items = list;
      if (stopShimmer) _showShimmer = false;
    });
  }

  Color _calculateStatusColor(String status) {
    switch (status) {
      case 'PAID': return Colors.green;
      case 'PARTIALLY_PAID': return Colors.orange;
      case 'PENDING': return Colors.blue;
      case 'OVERDUE': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _refresh() async => _fetchFromApi();

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

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: 8,
      itemBuilder: (ctx, i) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const CircleAvatar(radius: 20, backgroundColor: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 16, color: Colors.white),
                        const SizedBox(height: 8),
                        Container(width: 80, height: 12, color: Colors.white),
                        const SizedBox(height: 8),
                        Container(width: double.infinity, height: 40, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRow(PlayerInstallmentSummary p) {
    // Safety check in case maps aren't ready (shouldn't happen with logic above)
    final color = _statusColor[p.hashCode] ?? Colors.grey;
    final dueText = _formattedDue[p.hashCode] ?? '—';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                p.playerName.isNotEmpty ? p.playerName[0].toUpperCase() : "?",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.playerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${p.groupName ?? ''} • ${p.phone ?? ''}",
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (p.installmentId != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Amount: ₹${p.installmentAmount?.toStringAsFixed(2) ?? "0.00"}",
                            style: const TextStyle(fontSize: 12)),
                        Text("Paid: ₹${p.totalPaid.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 12)),
                        Text("Left: ${p.remaining != null ? "₹${p.remaining!.toStringAsFixed(2)}" : "—"}",
                            style: const TextStyle(fontSize: 12)),
                        Text("Due: $dueText",
                            style: TextStyle(
                              fontSize: 12,
                              color: p.dueDate != null && p.dueDate!.isBefore(DateTime.now())
                                  ? Colors.red
                                  : Colors.grey,
                            )),
                      ],
                    ),
                ],
              ),
            ),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Text(
                p.status.replaceAll("_", " "),
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.bold),
              ),
            ),
            if (p.installmentId != null)
              IconButton(
                icon: const Icon(Icons.payment, color: Colors.deepPurple),
                onPressed: () => _openPayments(p),
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
            onPressed: _refresh,
          )
        ],
      ),
      body: _showShimmer
          ? _buildShimmer()
          : _error != null
          ? Center(child: Text("Error: $_error"))
          : _items.isEmpty
          ? const Center(child: Text("No installments found"))
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: _items.length,
          itemBuilder: (ctx, i) => _buildRow(_items[i]),
        ),
      ),
    );
  }
}