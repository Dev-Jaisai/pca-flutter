import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/installment_status.dart';
import '../../services/api_service.dart';
import '../installments/installments_screen.dart';
import 'add_player_screen.dart';
import '../../utils/event_bus.dart'; // Add this import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;
  List<Player> _players = [];
  Map<int, bool> _installmentMap = {};

  @override
  void initState() {
    super.initState();
    _loadPlayersAndStatus();
  }

  Future<void> _loadPlayersAndStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final players = await ApiService.fetchPlayers();
      final statuses = await ApiService.fetchInstallmentStatus();
      final map = <int, bool>{ for (final s in statuses) s.playerId : s.hasInstallments };

      if (!mounted) return;
      setState(() {
        _players = players;
        _installmentMap = map;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async => _loadPlayersAndStatus();

  Future<void> _confirmDelete(int id, String name) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Player'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await ApiService.deletePlayer(id);
        if (!mounted) return;

        // Fire event to notify dashboard
        EventBus().fire(PlayerEvent('deleted'));

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name deleted')));
        _refresh();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _openAddPlayerForm() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddPlayerScreen()));
    if (created == true) {
      // Fire event to notify dashboard
      EventBus().fire(PlayerEvent('added'));
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Players')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) return Scaffold(appBar: AppBar(title: const Text('Players')), body: Center(child: Text('Error: $_error')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: ListView.separated(
        itemCount: _players.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = _players[index];
          final hasInstallments = _installmentMap[p.id] ?? false;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((p.group ?? '').isNotEmpty) Text(p.group!, style: const TextStyle(fontSize: 13)),
                Text(p.phone ?? '', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                if (!hasInstallments)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('No installments', style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                  ),
              ],
            ),
            trailing: Row(
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
                    if (changed == true) _refresh();
                  },
                ),

                if (!hasInstallments)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.deepPurple),
                    tooltip: 'Create installment',
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => InstallmentsScreen(player: p)),
                      );
                      if (created == true) _refresh();
                    },
                  ),

                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _confirmDelete(p.id, p.name)
                ),
              ],
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPlayerForm,
        icon: const Icon(Icons.add),
        label: const Text('Add Player'),
      ),
    );
  }
}