// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/installment_status.dart';
import '../../services/api_service.dart';
import '../installments/installments_screen.dart';
import 'add_player_screen.dart';
import '../../utils/event_bus.dart';

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
    final bg = const Color(0xFFFBF8FF);
    final cardRadius = 14.0;
    final accent = const Color(0xFF9B6CFF);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('Players')),
        body: const Center(child: CircularProgressIndicator()),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddPlayerForm,
          icon: const Icon(Icons.add),
          label: const Text('Add Player'),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(title: const Text('Players')),
        body: Center(child: Text('Error: $_error')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddPlayerForm,
          icon: const Icon(Icons.add),
          label: const Text('Add Player'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Players'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 80,
        color: accent,
        child: ListView.builder(
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
                    // open installments by tapping the card (same behavior as before for the icon)
                    final changed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => InstallmentsScreen(player: p)),
                    );
                    if (changed == true) _refresh();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    child: Row(
                      children: [
                        // avatar / initials
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey.shade100,
                          backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty) ? NetworkImage(p.photoUrl!) : null,
                          child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                              ? Text(_initials(p.name), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87))
                              : null,
                        ),

                        const SizedBox(width: 12),

                        // main info
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
                              // optional small note row
                              if (p.notes != null && p.notes!.isNotEmpty)
                                Text(p.notes!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // action column
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // installments / view button
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

                            const SizedBox(height: 4),

                            // create installment shortcut (if no installments)
                            if (!hasInstallments)
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF9B6CFF)),
                                tooltip: 'Create installment',
                                onPressed: () async {
                                  final created = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => InstallmentsScreen(player: p)),
                                  );
                                  if (created == true) _refresh();
                                },
                              ),

                            // delete
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
