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
      appBar: AppBar(title: Text(player.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (player.photoUrl != null)
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundImage: NetworkImage(player.photoUrl!),
                ),
              ),
            const SizedBox(height: 16),
            Text('Name: ${player.name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (player.group.isNotEmpty) Text('Group: ${player.group}'),
            if (player.age != null) Text('Age: ${player.age}'),
            if (player.joinDate != null) Text('Joined: ${df.format(player.joinDate!)}'),
            const SizedBox(height: 12),
            Text('Phone: ${player.phone}'),
            const SizedBox(height: 12),
            if (player.notes != null) Text('Notes: ${player.notes}'),
          ],
        ),
      ),
    );
  }
}
