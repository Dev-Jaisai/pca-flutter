import 'dart:ui'; // Required for Glassmorphism
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart';
import '../../models/player_installment_summary.dart';

// Helper class to group data by player
class PlayerReminder {
  final int playerId;
  final String playerName;
  final String? phone;
  final double totalDue;
  final int count;
  final DateTime? oldestDueDate;

  PlayerReminder({
    required this.playerId,
    required this.playerName,
    this.phone,
    required this.totalDue,
    required this.count,
    this.oldestDueDate,
  });
}

class SmsReminderScreen extends StatefulWidget {
  const SmsReminderScreen({super.key});

  @override
  State<SmsReminderScreen> createState() => _SmsReminderScreenState();
}

class _SmsReminderScreenState extends State<SmsReminderScreen> {
  List<PlayerReminder> _overdueList = [];
  List<PlayerReminder> _upcomingList = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------------------------------------------------
  // 🚀 LOGIC (KEPT SAME AS YOUR CODE)
  // ---------------------------------------------------------
  Future<void> _loadData() async {
    final cachedData = await DataManager().getCachedAllInstallments();
    if (cachedData != null && cachedData.isNotEmpty) {
      if (mounted) {
        setState(() {
          _processData(cachedData);
          _loading = false;
        });
      }
    } else {
      if (mounted) setState(() => _loading = true);
    }

    try {
      final freshList = await ApiService.fetchAllInstallmentsSummary(page: 0, size: 5000);
      await DataManager().saveAllInstallments(freshList);

      if (mounted) {
        setState(() {
          _processData(freshList);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading reminders: $e");
      if (mounted && _overdueList.isEmpty && _upcomingList.isEmpty) {
        setState(() => _loading = false);
        _showSnack('Failed to load reminders', isError: true);
      }
    }
  }

  void _processData(List<PlayerInstallmentSummary> rawList) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));

    final Map<int, PlayerReminder> overdueMap = {};
    final Map<int, PlayerReminder> upcomingMap = {};

    for (var item in rawList) {
      if (item.playerId == null || item.dueDate == null) continue;

      final st = (item.status ?? '').toUpperCase();
      if (st == 'PAID') continue;

      final remaining = (item.remaining ?? 0).toDouble();
      if (remaining <= 0) continue;

      final dueDate = item.dueDate!;
      bool isOverdue = dueDate.isBefore(today);
      bool isUpcoming = !isOverdue && dueDate.isBefore(nextWeek);

      if (!isOverdue && !isUpcoming) continue;

      final targetMap = isOverdue ? overdueMap : upcomingMap;

      if (targetMap.containsKey(item.playerId)) {
        final existing = targetMap[item.playerId]!;
        final newOldest = (existing.oldestDueDate == null || dueDate.isBefore(existing.oldestDueDate!)) ? dueDate : existing.oldestDueDate;

        targetMap[item.playerId!] = PlayerReminder(
          playerId: existing.playerId,
          playerName: existing.playerName,
          phone: existing.phone ?? item.phone,
          totalDue: existing.totalDue + remaining,
          count: existing.count + 1,
          oldestDueDate: newOldest,
        );
      } else {
        targetMap[item.playerId!] = PlayerReminder(
          playerId: item.playerId!,
          playerName: item.playerName,
          phone: item.phone,
          totalDue: remaining,
          count: 1,
          oldestDueDate: dueDate,
        );
      }
    }

    _overdueList = overdueMap.values.toList();
    _upcomingList = upcomingMap.values.toList();
  }

  String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '91$digits';
    }
    return digits;
  }

  Future<void> _sendWhatsApp(PlayerReminder p, String message) async {
    final phoneRaw = p.phone;
    if (phoneRaw == null || phoneRaw.trim().isEmpty) {
      _showSnack('No phone number found', isError: true);
      return;
    }

    final phone = _normalizePhone(phoneRaw);
    if (phone.isEmpty) {
      _showSnack('Invalid phone number', isError: true);
      return;
    }

    setState(() => _sending = true);

    final encoded = Uri.encodeComponent(message);
    final String urlString = 'https://wa.me/$phone?text=$encoded'; // Simplified for universal link

    try {
      await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication);
      _showSnack('WhatsApp opened for ${p.playerName}');
    } catch (e) {
      debugPrint('WhatsApp launch error: $e');
      _showSnack('Error launching WhatsApp', isError: true);
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendSms(PlayerReminder p, String message) async {
    final phoneRaw = p.phone;
    if (phoneRaw == null || phoneRaw.trim().isEmpty) {
      _showSnack('No phone number found', isError: true);
      return;
    }

    setState(() => _sending = true);

    final phone = _normalizePhone(phoneRaw);
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      _showSnack('SMS app opened for ${p.playerName}');
    } catch (e) {
      debugPrint('SMS launch error: $e');
      _showSnack('Error launching SMS app', isError: true);
    } finally {
      setState(() => _sending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(msg, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getMessage(PlayerReminder p, bool isOverdue) {
    final amt = p.totalDue.toStringAsFixed(0);
    if (isOverdue) {
      return "Hello ${p.playerName}, your total outstanding fee is ₹$amt. Please pay the overdue amount immediately to avoid penalties. - PCA Academy";
    } else {
      return "Hello ${p.playerName}, gentle reminder: your total fee of ₹$amt is due soon. Please pay on time. - PCA Academy";
    }
  }

  // ---------------------------------------------------------
  // 🎨 NEW PREMIUM DESIGN UI (Logic is preserved above)
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Send Reminders', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT
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

          // 3. MAIN CONTENT
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : _overdueList.isEmpty && _upcomingList.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.cyanAccent,
              backgroundColor: const Color(0xFF203A43),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                children: [
                  if (_overdueList.isNotEmpty) ...[
                    _buildSectionHeader('Overdue Payments', 'Immediate action required', Colors.redAccent, _overdueList.length),
                    ..._overdueList.map((p) => _buildGlassCard(p, true)),
                  ],
                  if (_upcomingList.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('Upcoming Payments', 'Due within 7 days', Colors.cyanAccent, _upcomingList.length),
                    ..._upcomingList.map((p) => _buildGlassCard(p, false)),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: !_loading && (_overdueList.isNotEmpty || _upcomingList.isNotEmpty)
          ? FloatingActionButton.extended(
        onPressed: _loadData,
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
        elevation: 4,
        icon: const Icon(Icons.refresh, size: 24),
        label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold)),
      )
          : null,
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, Color color, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(PlayerReminder p, bool isOverdue) {
    final color = isOverdue ? Colors.redAccent : Colors.cyanAccent;
    final message = _getMessage(p, isOverdue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: color.withOpacity(0.2),
                      child: Text(
                        p.playerName.isNotEmpty ? p.playerName[0].toUpperCase() : '?',
                        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.playerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          if (p.phone != null && p.phone!.isNotEmpty)
                            Text(p.phone!, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(isOverdue ? Icons.warning_amber_rounded : Icons.schedule, size: 16, color: color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '₹${p.totalDue.toInt()} • ${p.count} item${p.count > 1 ? 's' : ''}',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                                ),
                              ),
                            ],
                          ),
                          if (p.oldestDueDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Oldest due: ${p.oldestDueDate!.toLocal().toString().split(' ')[0]}',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                            )
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showSendOptions(p, message),
                      icon: const Icon(Icons.send),
                      color: Colors.white,
                      style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSendOptions(PlayerReminder p, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF203A43), // Dark Sheet
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 40, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Text('Send Reminder to ${p.playerName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : () { Navigator.pop(ctx); _sendWhatsApp(p, message); },
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : () { Navigator.pop(ctx); _sendSms(p, message); },
                    icon: const Icon(Icons.sms, size: 18),
                    label: const Text('SMS'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 140, width: 140,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white10)),
            child: Icon(Icons.notifications_off, size: 60, color: Colors.white.withOpacity(0.3)),
          ),
          const SizedBox(height: 24),
          const Text('No Reminders Needed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          const Text('Great! All payments are up to date.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.white54)),
        ],
      ),
    );
  }
}