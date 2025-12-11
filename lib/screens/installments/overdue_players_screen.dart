import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/PlayerOverdueSummary.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../utils/event_bus.dart';
import 'installments_screen.dart';

class OverduePlayersScreen extends StatefulWidget {
  const OverduePlayersScreen({super.key});

  @override
  State<OverduePlayersScreen> createState() => _OverduePlayersScreenState();
}

extension DateTimeExtension on DateTime {
  bool isAtSameMonthAs(DateTime other) {
    return year == other.year && month == other.month;
  }
}

class _OverduePlayersScreenState extends State<OverduePlayersScreen> {
  List<PlayerInstallmentSummary> _allItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _loadAllData();
  }

  Future<void> _loadFromCache() async {
    final cached = await DataManager().getCachedAllInstallments();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() => _allItems = cached);
    }
  }

  Future<void> _loadAllData() async {
    if (_allItems.isEmpty) setState(() => _isLoading = true);
    try {
      final List<PlayerInstallmentSummary> list =
      await ApiService.fetchAllInstallmentsSummary(page: 0, size: 2000);

      await DataManager().saveAllInstallments(list);

      if (mounted) {
        setState(() {
          _allItems = list;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }// Corrected Grouping Logic
  Map<int, PlayerOverdueSummary> _groupOverduePlayers(List<PlayerInstallmentSummary> items) {
    final Map<int, PlayerOverdueSummary> tempMap = {};
    final Map<int, bool> isPlayerActuallyOverdue = {}; // Track who is actually late

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (final p in items) {
      if (p.playerId == null) continue;
      final pid = p.playerId!;

      // 1. Get existing summary or create a fresh starting one
      final currentSummary = tempMap[pid] ?? PlayerOverdueSummary(
        playerId: pid,
        playerName: p.playerName,
        groupName: p.groupName ?? '',
        phone: p.phone,
        totalOriginalAmount: 0.0,
        totalPaidAmount: 0.0,
        totalOverdueRemaining: 0.0,
        overdueMonths: [],
        installmentIds: [],
      );

      // 2. Calculate the new totals (Add current row to existing totals)
      final originalAmount = p.installmentAmount ?? 0.0;
      final paidSoFar = p.totalPaid ?? 0.0;
      // Ensure we don't add negative remaining if overpaid
      final remaining = (originalAmount - paidSoFar) > 0 ? (originalAmount - paidSoFar) : 0.0;

      final newTotalOriginal = currentSummary.totalOriginalAmount + originalAmount;
      final newTotalPaid = currentSummary.totalPaidAmount + paidSoFar;
      final newTotalRemaining = currentSummary.totalOverdueRemaining + remaining;

      // 3. Prepare updated lists (Copy existing lists so we can add to them)
      final List<DateTime> updatedMonths = List.from(currentSummary.overdueMonths);
      final List<int> updatedIds = List.from(currentSummary.installmentIds);

      // 4. Check if this specific item is OVERDUE
      if (p.dueDate != null) {
        final st = (p.status ?? '').toUpperCase().replaceAll('_', ' ').trim();
        final bool isPastDue = p.dueDate!.isBefore(startOfToday);
        final bool isNotFullyPaid = st != 'PAID';

        if (isPastDue && isNotFullyPaid) {
          // Mark this player as visibly overdue
          isPlayerActuallyOverdue[pid] = true;

          // Add to overdue months list if not already there
          final monthKey = DateTime(p.dueDate!.year, p.dueDate!.month, 1);
          if (!updatedMonths.any((m) => m.isAtSameMonthAs(monthKey))) {
            updatedMonths.add(monthKey);
          }

          // Add to ID list for payment
          if (p.installmentId != null && !updatedIds.contains(p.installmentId!)) {
            updatedIds.add(p.installmentId!);
          }
        }
      }

      // 5. Create a NEW object with the updated values and put it back in the map
      tempMap[pid] = PlayerOverdueSummary(
        playerId: pid,
        playerName: p.playerName,
        groupName: p.groupName ?? '',
        phone: p.phone,
        totalOriginalAmount: newTotalOriginal,
        totalPaidAmount: newTotalPaid,
        totalOverdueRemaining: newTotalRemaining,
        overdueMonths: updatedMonths,
        installmentIds: updatedIds,
      );
    }

    // 6. Filter: Only return players who have at least one actual overdue item
    final Map<int, PlayerOverdueSummary> finalResult = {};
    tempMap.forEach((pid, summary) {
      if (isPlayerActuallyOverdue[pid] == true) {
        finalResult[pid] = summary;
      }
    });

    return finalResult;
  }

  Future<void> _showPayOverdueDialog(PlayerOverdueSummary player) async {
    final amountCtl = TextEditingController(
        text: player.totalOverdueRemaining.toStringAsFixed(0));
    bool paying = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Pay Overdue for ${player.playerName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This will strictly pay oldest overdue months first.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: paying ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: paying
                    ? null
                    : () async {
                  final amt = double.tryParse(amountCtl.text) ?? 0.0;
                  if (amt <= 0) return;

                  setDialogState(() => paying = true);

                  try {
                    await ApiService.payOverdue(
                      playerId: player.playerId,
                      amount: amt,
                    );

                    EventBus().fire(PlayerEvent('payment_recorded'));
                    EventBus().fire(PlayerEvent('installment_updated'));

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Payment Recorded Successfully!')),
                      );
                      _loadAllData();
                    }
                  } catch (e) {
                    if (mounted) {
                      setDialogState(() => paying = false);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: paying
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Pay'),
              ),
            ],
          );
        },
      ),
    );
  }Widget _buildOverduePlayerRow(PlayerOverdueSummary player) {
    player.overdueMonths.sort((a, b) => a.compareTo(b));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: Colors.red),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ... [Header Row code remains same] ...
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(player.playerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(player.groupName,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.redAccent, size: 20),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ... [Amount Container code remains same] ...
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Total Overdue:",
                                    style: TextStyle(
                                        color: Colors.red[800], fontSize: 13)),
                                Text(
                                    "₹${player.totalOriginalAmount.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Paid:",
                                    style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 13)),
                                Text(
                                    "₹${player.totalPaidAmount.toStringAsFixed(0)}",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                        fontSize: 13)),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Remaining:",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text(
                                    "₹${player.totalOverdueRemaining.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Text("Overdue Months:",
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: player.overdueMonths.map((m) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Text(
                              DateFormat('MMM yyyy').format(m),
                              style: TextStyle(
                                  fontSize: 11, color: Colors.red.shade800),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // --- UPDATED BUTTONS ROW ---
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // Navigate to Installments Screen (View Details)
                                final p = Player(
                                    id: player.playerId,
                                    name: player.playerName,
                                    phone: player.phone ?? '',
                                    group: player.groupName
                                );
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => InstallmentsScreen(player: p))
                                ).then((_) => _loadAllData());
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                foregroundColor: Colors.black87,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text("View Details"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _showPayOverdueDialog(player),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: const Text("Pay Overdue"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final overduePlayers = _groupOverduePlayers(_allItems);
    final overdueList = overduePlayers.values.toList()
      ..sort((a, b) => b.totalOverdueRemaining.compareTo(a.totalOverdueRemaining));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Overdue Players (${overdueList.length})'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text("Error: $_error"))
          : overdueList.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text("No overdue players!", style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAllData,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 12, bottom: 80),
          itemCount: overdueList.length,
          itemBuilder: (ctx, i) {
            return _buildOverduePlayerRow(overdueList[i]);
          },
        ),
      ),
    );
  }
}