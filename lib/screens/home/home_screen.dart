// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../services/player_shimmer_list.dart';
import '../installments/installments_screen.dart';
import 'add_player_screen.dart';
import 'edit_player_screen.dart'; // Import your edit screen
import '../../utils/event_bus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showShimmer = true;
  List<Player> _players = [];
  bool _bgFetching = false;

  @override
  void initState() {
    super.initState();
    _initialLoad();
    EventBus().stream.listen((event) {
      if (['added', 'deleted', 'updated'].contains(event.action)) {
        _fetchFromApi();
      }
    });
  }

  Future<void> _initialLoad() async {
    final cached = DataManager().getCachedData();
    if (cached.players != null && cached.players!.isNotEmpty) {
      setState(() {
        _players = cached.players!;
        _showShimmer = false;
      });
    }
    await _fetchFromApi();
  }

  Future<void> _fetchFromApi() async {
    try {
      setState(() => _bgFetching = true);
      // We only need players now, installment status is not needed for the list UI anymore
      final players = await ApiService.fetchPlayers();

      // Save to RAM + Hive (passing empty list for statuses since we don't use them on card)
      await DataManager().saveData(players, []);

      if (!mounted) return;
      setState(() {
        _players = players;
        _showShimmer = false;
      });
    } catch (e) {
      debugPrint('HomeScreen: fetchFromApi failed: $e');
      if (mounted && _players.isEmpty) setState(() => _showShimmer = false);
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
        EventBus().fire(PlayerEvent('deleted'));
        _fetchFromApi();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name deleted')));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _openAddPlayerForm() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddPlayerScreen()));
    if (created == true) {
      EventBus().fire(PlayerEvent('added'));
      _fetchFromApi();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFBF8FF);//local
    const accent = Color(0xFF9B6CFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('All players'.toUpperCase()),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _showShimmer
          ? const PlayerShimmerList()
          : RefreshIndicator(
        onRefresh: _refresh,
        color: accent,
        child: _players.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No players found'))])
            : ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          itemCount: _players.length,
          itemBuilder: (context, index) {
            final p = _players[index];
            return _buildPlayerCard(p);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPlayerForm,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Player'),
        backgroundColor: accent,
      ),
    );
  }

  Widget _buildPlayerCard(Player p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // Tapping the card opens the Profile / Installments screen
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InstallmentsScreen(player: p)),
            ).then((_) => _fetchFromApi());
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.deepPurple.shade50,
                  backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty)
                      ? NetworkImage(p.photoUrl!)
                      : null,
                  child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                      ? Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700, fontSize: 18),
                  )
                      : null,
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        "${p.group ?? 'No Group'} • ${p.phone ?? ''}",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // Actions: Edit & Delete ONLY
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 22),
                      tooltip: 'Edit Details',
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => EditPlayerScreen(player: p)),
                        );
                        if (updated == true) _fetchFromApi();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(p.id, p.name),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}