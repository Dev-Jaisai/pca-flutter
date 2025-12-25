import 'dart:ui'; // Glassmorphism
import 'package:flutter/material.dart';
import 'package:textewidget/widgets/PlayerSummaryCard.dart';
import '../../models/player.dart';
import '../../models/player_installment_summary.dart';
import '../../services/data_manager.dart';

// ✅ FIX: File name should match exactly (usually lowercase snake_case)

class PlayerSearchDelegate extends SearchDelegate {
  final List<Player> players;

  PlayerSearchDelegate({required this.players});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F2937),
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white70),
      ),
      scaffoldBackgroundColor: const Color(0xFF111827),
    );
  }

  @override
  String get searchFieldLabel => 'Search player...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear, color: Colors.cyanAccent), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = players.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1F2937), // Cool Slate Gray (Top)
            Color(0xFF111827), // Darker Navy (Bottom)
          ],
        ),
      ),
      child: results.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_search, size: 80, color: Colors.white24),
            SizedBox(height: 16),
            Text('No player found', style: TextStyle(color: Colors.white60, fontSize: 16)),
          ],
        ),
      )
          : FutureBuilder<List<PlayerInstallmentSummary>?>(
        future: DataManager().getCachedAllInstallments(),
        builder: (context, snapshot) {
          final allInstallments = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final player = results[index];

              // 1. Player che sagale installments ghyayche
              final myInstallments = allInstallments.where((i) => i.playerId == player.id).toList();

              // 2. Sort karayche (Latest First)
              myInstallments.sort((a, b) {
                DateTime dateA = a.dueDate ?? DateTime(2000);
                DateTime dateB = b.dueDate ?? DateTime(2000);
                return dateB.compareTo(dateA);
              });

              double sumTotal = 0, sumPaid = 0, sumRemaining = 0;
              DateTime? latestPaymentDate;

              for (var i in myInstallments) {
                sumTotal += (i.installmentAmount ?? 0);
                sumPaid += i.totalPaid;
                sumRemaining += (i.remaining ?? 0);

                if (i.lastPaymentDate != null) {
                  if (latestPaymentDate == null || i.lastPaymentDate!.isAfter(latestPaymentDate)) {
                    latestPaymentDate = i.lastPaymentDate;
                  }
                }
              }

              // 🔥 STATUS LOGIC
              String displayStatus = 'PENDING';

              if (myInstallments.isNotEmpty) {
                String latestRealStatus = (myInstallments.first.status ?? '').toUpperCase();

                if (latestRealStatus == 'SKIPPED') {
                  displayStatus = 'SKIPPED';
                } else if (latestRealStatus == 'CANCELLED') {
                  displayStatus = 'CANCELLED';
                } else {
                  if (sumRemaining <= 0) {
                    displayStatus = 'PAID';
                  } else {
                    displayStatus = 'PENDING';
                  }
                }
              } else {
                displayStatus = 'PAID';
              }

              final aggregatedSummary = PlayerInstallmentSummary(
                playerId: player.id,
                playerName: player.name,
                totalPaid: sumPaid,
                installmentAmount: sumTotal,
                remaining: sumRemaining,
                status: displayStatus,
                lastPaymentDate: latestPaymentDate,
                // 🔥 Pass correct Due Date
                dueDate: myInstallments.isNotEmpty ? myInstallments.first.dueDate : DateTime.now(),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PlayerSummaryCard(
                  player: player,
                  summary: aggregatedSummary,
                  installments: myInstallments,
                ),
              );
            },
          );
        },
      ),
    );
  }
}