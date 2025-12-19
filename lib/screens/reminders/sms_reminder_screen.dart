import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/data_manager.dart'; // ✅ Import DataManager
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
  // 🚀 OPTIMIZED LOAD LOGIC
  // ---------------------------------------------------------
  Future<void> _loadData() async {
    // 1. Load from Cache (Instant)
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

    // 2. Fetch Fresh Data (Background)
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
        final existingOldest = existing.oldestDueDate;
        final newOldest = (existingOldest == null || dueDate.isBefore(existingOldest)) ? dueDate : existingOldest;

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

    final bool isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final encoded = Uri.encodeComponent(message);
    final String urlString = isAndroid
        ? 'whatsapp://send?phone=$phone&text=$encoded'
        : 'https://wa.me/$phone?text=$encoded';

    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnack('WhatsApp opened for ${p.playerName}');
      } else {
        _showSnack('WhatsApp not available', isError: true);
      }
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
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnack('SMS app opened for ${p.playerName}');
      } else {
        _showSnack('SMS app not available', isError: true);
      }
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
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              size: 18,
              color: isError ? Colors.red.shade100 : Colors.green.shade100,
            ),
            const SizedBox(width: 8),
            Text(msg),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
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

  Widget _buildSectionHeader(String title, String subtitle, Color color, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(PlayerReminder p, bool isOverdue) {
    final color = isOverdue ? Colors.red.shade600 : Colors.blue.shade600;
    final message = _getMessage(p, isOverdue);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(margin: const EdgeInsets.only(bottom: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                      Text('Send Reminder to ${p.playerName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      Text(message, style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4), textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _sending ? null : () => _sendWhatsApp(p, message),
                              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18),
                              label: const Text('WhatsApp'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _sending ? null : () => _sendSms(p, message),
                              icon: const Icon(Icons.sms, size: 18),
                              label: const Text('SMS'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 48, width: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text(p.playerName.isNotEmpty ? p.playerName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.playerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                          const SizedBox(height: 4),
                          if (p.phone != null && p.phone!.isNotEmpty) Text(p.phone!, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(isOverdue ? Icons.warning : Icons.schedule, size: 16, color: color),
                              const SizedBox(width: 6),
                              Expanded(child: Text('₹${p.totalDue.toInt()} • ${p.count} installment${p.count > 1 ? 's' : ''}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color))),
                            ],
                          ),
                          if (p.oldestDueDate != null) ...[const SizedBox(height: 4), Text('Oldest due: ${p.oldestDueDate!.toLocal().toString().split(' ')[0]}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))],
                        ],
                      ),
                    ),
                    Container(
                      height: 40, width: 40,
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: IconButton(onPressed: () {}, icon: const Icon(Icons.send), iconSize: 18, color: color, padding: EdgeInsets.zero),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sending ? null : () => _sendWhatsApp(p, message),
                        icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.green.shade300)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _sending ? null : () => _sendSms(p, message),
                        icon: const Icon(Icons.sms, size: 16),
                        label: const Text('SMS'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.blue.shade300)),
                      ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 160, width: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.deepPurple.shade100, width: 2),
              ),
              child: Icon(Icons.notifications_off, size: 70, color: Colors.deepPurple.shade400),
            ),
            const SizedBox(height: 32),
            const Text('No Reminders Needed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: -0.5)),
            const SizedBox(height: 12),
            const Text('Great! All payments are up to date.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.4)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: const Text('Send Reminders', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade600, Colors.purple.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
          ),
        ),
        // ✅ Explicit Back Button
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Main Content
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Colors.deepPurple.shade600, strokeWidth: 2.5))
                : _overdueList.isEmpty && _upcomingList.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.deepPurple.shade600,
              backgroundColor: Colors.white,
              child: ListView(
                padding: const EdgeInsets.only(top: 24, bottom: 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_overdueList.isNotEmpty) ...[
                    _buildSectionHeader('Overdue Payments', 'Immediate action required', Colors.red.shade600, _overdueList.length),
                    ..._overdueList.map((p) => _buildPlayerCard(p, true)),
                  ],
                  if (_upcomingList.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('Upcoming Payments', 'Due within 7 days', Colors.blue.shade600, _upcomingList.length),
                    ..._upcomingList.map((p) => _buildPlayerCard(p, false)),
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
        backgroundColor: Colors.deepPurple.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.refresh, size: 24),
        label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
      )
          : null,
    );
  }
}