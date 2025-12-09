import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';  // Use url_launcher instead
import '../../models/player_installment_summary.dart';
import '../../services/api_service.dart';

class SmsReminderScreen extends StatefulWidget {
  const SmsReminderScreen({super.key});

  @override
  State<SmsReminderScreen> createState() => _SmsReminderScreenState();
}

class _SmsReminderScreenState extends State<SmsReminderScreen> {
  List<PlayerInstallmentSummary> _overduePlayers = [];
  List<PlayerInstallmentSummary> _dueThisWeek = [];
  bool _loading = true;
  String _sendingStatus = '';

  @override
  void initState() {
    super.initState();
    _loadDuePlayers();
  }

  Future<void> _loadDuePlayers() async {
    setState(() => _loading = true);
    try {
      final allSummary = await ApiService.fetchAllInstallmentsSummary();
      final now = DateTime.now();
      final nextWeek = now.add(const Duration(days: 7));

      setState(() {
        _overduePlayers = allSummary.where((player) {
          if (player.dueDate == null || player.status == 'PAID') return false;
          return player.dueDate!.isBefore(now) && player.remaining! > 0;
        }).toList();

        _dueThisWeek = allSummary.where((player) {
          if (player.dueDate == null || player.status == 'PAID') return false;
          return player.dueDate!.isAfter(now) &&
              player.dueDate!.isBefore(nextWeek) &&
              player.remaining! > 0;
        }).toList();
      });
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sendSmsToPlayer(PlayerInstallmentSummary player, String type) async {
    if (player.phone == null || player.phone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player has no phone number')),
      );
      return;
    }

    String message = '';
    if (type == 'overdue') {
      message = '''
Hello ${player.playerName},

Your installment of ₹${player.installmentAmount?.toStringAsFixed(2) ?? '0'} is overdue.
Due date was: ${player.dueDate?.toString().split(' ')[0] ?? ''}
Remaining: ₹${player.remaining?.toStringAsFixed(2) ?? '0'}

Please pay at your earliest.
-PCA Academy
''';
    } else {
      message = '''
Hello ${player.playerName},

Friendly reminder: Your installment of ₹${player.installmentAmount?.toStringAsFixed(2) ?? '0'} 
is due on ${player.dueDate?.toString().split(' ')[0] ?? ''}.
Remaining: ₹${player.remaining?.toStringAsFixed(2) ?? '0'}

-PCA Academy
''';
    }

    // Clean phone number (remove spaces, dashes, etc.)
    final phone = player.phone!.replaceAll(RegExp(r'[+\-\s]'), '');

    // Create SMS URL
    final smsUrl = Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening SMS for ${player.playerName}')),
        );
      } else {
        throw 'Could not launch SMS app';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send SMS: $e')),
      );
    }
  }

  Future<void> _sendBulkSms(List<PlayerInstallmentSummary> players, String type) async {
    setState(() => _sendingStatus = 'Preparing to send SMS to ${players.length} players...');

    int successCount = 0;
    for (var player in players) {
      if (player.phone != null && player.phone!.isNotEmpty) {
        try {
          await _sendSmsToPlayer(player, type);
          successCount++;
          await Future.delayed(const Duration(milliseconds: 500)); // Small delay
        } catch (e) {
          // Continue with next
        }
      }
    }

    setState(() => _sendingStatus = 'Prepared $successCount/${players.length} SMS messages');

    // Clear status after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _sendingStatus = '');
      }
    });
  }

  Widget _buildPlayerList(String title, List<PlayerInstallmentSummary> players, String type) {
    if (players.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Text(
              'No $title',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton.icon(
                  onPressed: () => _sendBulkSms(players, type),
                  icon: const Icon(Icons.send),
                  label: const Text('Send All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...players.map((player) => ListTile(
              leading: CircleAvatar(child: Text(player.playerName[0])),
              title: Text(player.playerName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due: ${player.dueDate?.toString().split(' ')[0] ?? 'N/A'}'),
                  Text('Remaining: ₹${player.remaining?.toStringAsFixed(2) ?? '0'}'),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.sms, color: Colors.green),
                onPressed: () => _sendSmsToPlayer(player, type),
                tooltip: 'Send SMS reminder',
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send SMS Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDuePlayers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This will open your device\'s SMS app with pre-filled messages. '
                            'You can review and send them individually.',
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_sendingStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_sendingStatus)),
                  ],
                ),
              ),

            _buildPlayerList('Overdue Players (${_overduePlayers.length})', _overduePlayers, 'overdue'),
            const SizedBox(height: 20),
            _buildPlayerList('Due This Week (${_dueThisWeek.length})', _dueThisWeek, 'upcoming'),

            // Instructions
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How it works:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Tap SMS icon to open SMS app with pre-filled message'),
                    const Text('• Review and send the message'),
                    const Text('• "Send All" prepares multiple SMS messages'),
                    Text('• Actual sending happens in your SMS app', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}