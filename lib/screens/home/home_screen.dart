// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart'; // DataManager (RAM + Hive)
import '../../services/player_shimmer_list.dart';
import '../installments/installments_screen.dart';
import 'add_player_screen.dart';
import '../../utils/event_bus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Show shimmer when we have no data at all (cold start)
  bool _showShimmer = true;

  // Actual list/map used by UI
  List<Player> _players = [];
  Map<int, bool> _installmentMap = {};

  // Small flag to indicate background fetch in progress if you want to show indicator later
  bool _bgFetching = false;

  @override
  void initState() {
    super.initState();
    _initialLoad();
    // Also listen for external events (add/delete) so we refresh cache/UI if needed
    EventBus().stream.listen((event) {
      if ([
        'added',
        'deleted',
        'updated',
        'installment_created',
        'installment_deleted',
        'payment_recorded'
      ].contains(event.action)) {
        // Fetch fresh data in background when such events happen
        _fetchFromApi();
      }
    });
  }

  Future<void> _initialLoad() async {
    // 1) FAST: try RAM -> Hive via DataManager
    final cached = DataManager().getCachedData();
    if (cached.players != null && cached.players!.isNotEmpty) {
      setState(() {
        _players = cached.players!;
        _installmentMap = cached.status ?? {};
        _showShimmer = false; // show actual data instantly
      });
    }

    // 2) ALWAYS: fetch fresh data in background and update UI + cache
    await _fetchFromApi();
  }

  Future<void> _fetchFromApi() async {
    try {
      setState(() => _bgFetching = true);

      final results = await Future.wait([
        ApiService.fetchPlayers(),
        ApiService.fetchInstallmentStatus(),
      ]);

      final players = results[0] as List<Player>;
      final statuses = results[1] as List<dynamic>; // expected objects with playerId & hasInstallments

      // Save to RAM + Hive
      await DataManager().saveData(players, statuses);

      // Build status map for UI
      final statusMap = <int, bool>{
        for (final s in statuses) s.playerId: s.hasInstallments
      };

      if (!mounted) return;
      setState(() {
        _players = players;
        _installmentMap = statusMap;
        _showShimmer = false;
      });
    } catch (e) {
      debugPrint('HomeScreen: fetchFromApi failed: $e');
      // If we had no cached data at all, stop shimmer so user doesn't hang
      if (mounted && _players.isEmpty) {
        setState(() => _showShimmer = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to refresh data — showing cached data if available')),
        );
      }
    } finally {
      if (mounted) setState(() => _bgFetching = false);
    }
  }

  Future<void> _refresh() async => _fetchFromApi();

  Future<void> _confirmDelete(int id, String name) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Player'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await ApiService.deletePlayer(id);
        // Fire event so other widgets can update
        EventBus().fire(PlayerEvent('deleted'));

        // Remove from UI immediately for snappy feel
        if (!mounted) return;
        setState(() {
          _players.removeWhere((p) => p.id == id);
          _installmentMap.remove(id);
        });

        // Also refresh cache by fetching from API; if you prefer you could remove from DataManager instead
        _fetchFromApi();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name deleted')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _openAddPlayerForm() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddPlayerScreen()));
    if (created == true) {
      EventBus().fire(PlayerEvent('added'));
      // Fetch fresh data (in background)
      _fetchFromApi();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFFBF8FF);
    final cardRadius = 14.0;
    final accent = const Color(0xFF9B6CFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Players'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _showShimmer
          ? const PlayerShimmerList()
          : RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 80,
        color: accent,
        child: _players.isEmpty
            ? ListView(
          // allow pull-to-refresh even when empty
          children: const [SizedBox(height: 120), Center(child: Text('No players found'))],
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          itemCount: _players.length,
          itemBuilder: (context, index) {
            final p = _players[index];
            final hasInstallments = _installmentMap[p.id] ?? false;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(cardRadius),
                elevation: 6,
                shadowColor: Colors.black12,
                child: InkWell(
                  borderRadius: BorderRadius.circular(cardRadius),
                  onTap: () async {
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => InstallmentsScreen(player: p)),
                    );
                    if (changed == true) _fetchFromApi();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey.shade100,
                          backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty)
                              ? NetworkImage(p.photoUrl!)
                              : null,
                          child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                              ? Text(_initials(p.name),
                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87))
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if ((p.group ?? '').isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(p.group!, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                    ),
                                  const SizedBox(width: 8),
                                  Text(p.phone ?? '', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (p.notes != null && p.notes!.isNotEmpty)
                                Text(p.notes!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.list_alt_outlined),
                              tooltip: 'Installments',
                              onPressed: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => InstallmentsScreen(player: p)),
                                );
                                if (changed == true) _fetchFromApi();
                              },
                            ),
                            const SizedBox(height: 4),
                            if (!hasInstallments)
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF9B6CFF)),
                                tooltip: 'Create installment',
                                onPressed: () async {
                                  final created = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => InstallmentsScreen(player: p)),
                                  );
                                  if (created == true) _fetchFromApi();
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _confirmDelete(p.id, p.name),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPlayerForm,
        icon: const Icon(Icons.add),
        label: const Text('Add Player'),
        backgroundColor: accent,
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
