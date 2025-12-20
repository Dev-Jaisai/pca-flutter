import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/data_manager.dart';
import '../../widgets/PlayerSummaryCard.dart';

class PlayerSearchDelegate extends SearchDelegate {
  final List<Player> players;

  PlayerSearchDelegate({required this.players});

  @override
  String get searchFieldLabel => 'Search player name...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = players.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No player found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return FutureBuilder<List<PlayerInstallmentSummary>?>(
      future: DataManager().getCachedAllInstallments(),
      builder: (context, snapshot) {
        final allInstallments = snapshot.data ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final player = results[index];

            // 1. Get ALL installments for this player
            final myInstallments = allInstallments.where((i) => i.playerId == player.id).toList();

            // 2. Calculate Totals
            double sumTotal = 0;
            double sumPaid = 0;
            double sumRemaining = 0;

            for (var i in myInstallments) {
              sumTotal += (i.installmentAmount ?? 0);
              sumPaid += i.totalPaid;
              sumRemaining += (i.remaining ?? 0);
            }

            final aggregatedSummary = PlayerInstallmentSummary(
              playerId: player.id,
              playerName: player.name,
              totalPaid: sumPaid,
              installmentAmount: sumTotal,
              remaining: sumRemaining,
              status: sumRemaining > 0 ? 'PENDING' : 'PAID',
            );

            // ✅ 3. Pass 'myInstallments' list to the card
            return PlayerSummaryCard(
              player: player,
              summary: aggregatedSummary,
              installments: myInstallments, // Pass the list here
            );
          },
        );
      },
    );
  }
}