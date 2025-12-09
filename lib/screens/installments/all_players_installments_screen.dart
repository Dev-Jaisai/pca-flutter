import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';

class AllPlayersInstallmentsScreen extends StatefulWidget {
  final String? initialMonth; // YYYY-MM format

  const AllPlayersInstallmentsScreen({super.key, this.initialMonth});

  @override
  State<AllPlayersInstallmentsScreen> createState() => _AllPlayersInstallmentsScreenState();
}

class _AllPlayersInstallmentsScreenState extends State<AllPlayersInstallmentsScreen> {
  late String _selectedMonth;
  bool _loading = true;
  List<PlayerInstallmentSummary> _installmentSummary = [];
  List<Player> _allPlayers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    // Set default month to current month
    final now = DateTime.now();
    _selectedMonth = widget.initialMonth ?? '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load all players
      final players = await ApiService.fetchPlayers();

      // Load installment summary for selected month
      final summary = await ApiService.fetchInstallmentSummary(_selectedMonth);

      setState(() {
        _allPlayers = players;
        _installmentSummary = summary;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final parts = _selectedMonth.split('-');
    final initialYear = int.tryParse(parts[0]) ?? now.year;
    final initialMonth = int.tryParse(parts[1]) ?? now.month;

    final initialDate = DateTime(initialYear, initialMonth);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      helpText: 'Select Month',
      initialEntryMode: DatePickerEntryMode.calendar,
    );

    if (picked != null) {
      final newMonth = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}';
      setState(() {
        _selectedMonth = newMonth;
      });
      await _loadData();
    }
  }

  // Find installment summary for a player
  PlayerInstallmentSummary? _getPlayerSummary(int playerId) {
    return _installmentSummary.firstWhere(
          (summary) => summary.playerId == playerId,
      orElse: () => PlayerInstallmentSummary(
        playerId: playerId,
        playerName: '',
        totalPaid: 0.0,
        status: 'NO_INSTALLMENT',
      ),
    );
  }

  Widget _buildPlayerRow(Player player) {
    final summary = _getPlayerSummary(player.id);
    final df = DateFormat('dd MMM yyyy');

    // Status color coding
    Color getStatusColor(String status) {
      switch (status) {
        case 'PAID':
          return Colors.green;
        case 'PARTIALLY_PAID':
          return Colors.orange;
        case 'PENDING':
          return Colors.red;
        case 'NO_INSTALLMENT':
        default:
          return Colors.grey;
      }
    }

    String getStatusText(String status) {
      switch (status) {
        case 'PAID':
          return 'PAID';
        case 'PARTIALLY_PAID':
          return 'PARTIAL';
        case 'PENDING':
          return 'PENDING';
        case 'NO_INSTALLMENT':
        default:
          return 'NO INSTALLMENT';
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
              radius: 24,
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Player Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '${player.group} • ${player.phone}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Installment Details
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (summary!.installmentAmount != null)
                              Text(
                                'Amount: ₹${summary.installmentAmount!.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12),
                              ),

                            Text(
                              'Paid: ₹${summary.totalPaid.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12),
                            ),

                            Text(
                              summary.remaining != null
                                  ? 'Left: ₹${summary.remaining!.toStringAsFixed(2)}'
                                  : 'Left: —',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      // Due Date and Status
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (summary.dueDate != null)
                            Text(
                              'Due: ${df.format(summary.dueDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),

                          const SizedBox(height: 4),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: getStatusColor(summary.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: getStatusColor(summary.status),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              getStatusText(summary.status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: getStatusColor(summary.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Button
            IconButton(
              icon: Icon(
                summary.status == 'NO_INSTALLMENT'
                    ? Icons.add_circle_outline
                    : Icons.receipt_long,
                color: summary.status == 'NO_INSTALLMENT'
                    ? Colors.deepPurple
                    : Colors.grey,
              ),
              onPressed: () {
                if (summary.status == 'NO_INSTALLMENT') {
                  _createInstallmentForPlayer(player);
                } else {
                  _viewInstallmentDetails(player, summary);
                }
              },
              tooltip: summary.status == 'NO_INSTALLMENT'
                  ? 'Create Installment'
                  : 'View Details',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createInstallmentForPlayer(Player player) async {
    final now = DateTime.now();
    final parts = _selectedMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Installment for ${player.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Month: ${DateFormat('MMMM yyyy').format(DateTime(year, month))}'),
            const SizedBox(height: 16),
            const Text('This will create an installment for the selected month.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService.createInstallmentForPlayer(
                  playerId: player.id,
                  periodMonth: month,
                  periodYear: year,
                  dueDate: DateTime(year, month, 10), // 10th of the month
                  amount: 500.0, // Default amount or fetch from fee structure
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Installment created for ${player.name}')),
                );
                await _loadData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _viewInstallmentDetails(Player player, PlayerInstallmentSummary summary) {
    if (summary.installmentId != null) {
      // Navigate to installment details screen
      Navigator.pushNamed(
        context,
        '/installment-details',
        arguments: {
          'player': player,
          'installmentId': summary.installmentId,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = () {
      final parts = _selectedMonth.split('-');
      final year = int.tryParse(parts[0]) ?? DateTime.now().year;
      final month = int.tryParse(parts[1]) ?? DateTime.now().month;
      return DateFormat('MMMM yyyy').format(DateTime(year, month));
    }();

    return Scaffold(
      appBar: AppBar(
        title: Text('All Players - $monthLabel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _pickMonth,
            tooltip: 'Select Month',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _allPlayers.isEmpty
          ? const Center(child: Text('No players found'))
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: _allPlayers.length,
          itemBuilder: (context, index) {
            return _buildPlayerRow(_allPlayers[index]);
          },
        ),
      ),
    );
  }
}