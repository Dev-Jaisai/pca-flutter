import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/player.dart';

class PlayerDetailScreen extends StatelessWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]))),
          Positioned(top: -50, right: -50, child: Container(height: 200, width: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.2), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 100)]))),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (player.photoUrl != null)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.cyanAccent, width: 2), boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.3), blurRadius: 20)]),
                            child: CircleAvatar(radius: 50, backgroundImage: NetworkImage(player.photoUrl!)),
                          ),
                        const SizedBox(height: 20),
                        Text(player.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(player.group ?? 'No Group', style: TextStyle(color: Colors.cyanAccent.withOpacity(0.8), fontSize: 16)),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 20),
                        _row('Phone', player.phone ?? '-', Icons.phone),
                        _row('Age', player.age?.toString() ?? '-', Icons.cake),
                        _row('Joined', player.joinDate != null ? df.format(player.joinDate!) : '-', Icons.calendar_today),
                        if (player.notes != null) _row('Notes', player.notes!, Icons.note),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 16),
          Text('$label:', style: const TextStyle(color: Colors.white54)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}