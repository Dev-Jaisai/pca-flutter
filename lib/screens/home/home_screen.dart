import 'dart:ui'; // For Glassmorphism
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/player.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../services/player_shimmer_list.dart';
import '../installments/BulkExtendScreen.dart';
import '../installments/installments_screen.dart';
import 'add_player_screen.dart';
import 'edit_player_screen.dart';
import '../../utils/event_bus.dart';

// ✅ IMPORT THIS
import '../installments/create_installment_screen.dart';

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
      if (['added', 'deleted', 'updated', 'installment_created'].contains(event.action)) {
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
      final players = await ApiService.fetchPlayers();
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
        backgroundColor: const Color(0xFF203A43),
        title: const Text('Delete Player', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete $name?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await ApiService.deletePlayer(id);
        EventBus().fire(PlayerEvent('deleted'));
        _fetchFromApi();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.redAccent));
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('All Players', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.holiday_village, color: Colors.orangeAccent),
            tooltip: "Holiday / Bulk Extend",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulkExtendScreen()),
              ).then((_) => _refresh());
            },
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
          ),

          // 2. ORBS
          Positioned(top: -50, right: -50, child: Container(height: 200, width: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 100)]))),
          Positioned(bottom: 100, left: -50, child: Container(height: 200, width: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 100)]))),

          // 3. CONTENT
          _showShimmer
              ? const PlayerShimmerList()
              : RefreshIndicator(
            onRefresh: _refresh,
            color: Colors.cyanAccent,
            backgroundColor: const Color(0xFF203A43),
            child: _players.isEmpty
                ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No players found', style: TextStyle(color: Colors.white54)))])
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 80),
              itemCount: _players.length,
              itemBuilder: (context, index) {
                final p = _players[index];
                final delay = Duration(milliseconds: 50 * index);
                return _buildGlassPlayerCard(p)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: delay)
                    .slideX(begin: 0.2, end: 0, duration: 400.ms, delay: delay, curve: Curves.easeOutQuad);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPlayerForm,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Player', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
      ),
    );
  }

  Widget _buildGlassPlayerCard(Player p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
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
                      Hero(
                        tag: 'avatar_${p.id}',
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          backgroundImage: (p.photoUrl != null && p.photoUrl!.isNotEmpty)
                              ? NetworkImage(p.photoUrl!)
                              : null,
                          child: (p.photoUrl == null || p.photoUrl!.isEmpty)
                              ? Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 18),
                          )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(
                              "${p.group ?? 'No Group'} • ${p.phone ?? ''}",
                              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),

                      // --- ACTION BUTTONS ---
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 🔥 NEW: GENERATE BILL BUTTON
                          IconButton(
                            icon: const Icon(Icons.receipt_long, color: Colors.greenAccent, size: 22),
                            tooltip: "Generate Bill",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => CreateInstallmentScreen(player: p)),
                              ).then((_) => _fetchFromApi());
                            },
                          ),

                          // EDIT BUTTON
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: Colors.blueAccent.shade100, size: 22),
                            onPressed: () async {
                              final updated = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(builder: (_) => EditPlayerScreen(player: p)),
                              );
                              if (updated == true) _fetchFromApi();
                            },
                          ),

                          // DELETE BUTTON
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.redAccent.shade100, size: 22),
                            onPressed: () => _confirmDelete(p.id, p.name),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}