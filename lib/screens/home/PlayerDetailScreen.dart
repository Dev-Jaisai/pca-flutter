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

    // --- LOGIC: Billing Info Display Strings ---
    String billingDayStr = player.billingDay != null
        ? "${player.billingDay}${_getDaySuffix(player.billingDay!)} of month"
        : "Not Set";

    String cycleStr = (player.paymentCycleMonths == 3)
        ? "Quarterly (Every 3 Months)"
        : "Monthly (Every Month)";

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(player.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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

          // 2. DECORATIVE ORBS
          Positioned(
              top: -50, right: -50,
              child: Container(height: 200, width: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.2), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 100)]))
          ),

          // 3. MAIN CONTENT
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // --- AVATAR SECTION ---
                        Hero(
                          tag: 'avatar_${player.id}',
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.cyanAccent, width: 2),
                              boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.3), blurRadius: 20)],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              backgroundImage: (player.photoUrl != null && player.photoUrl!.isNotEmpty)
                                  ? NetworkImage(player.photoUrl!)
                                  : null,
                              child: (player.photoUrl == null || player.photoUrl!.isEmpty)
                                  ? Text(
                                player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent, fontSize: 40),
                              )
                                  : null,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // NAME & GROUP
                        Text(
                          player.name,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
                          child: Text(
                              player.group.isNotEmpty ? player.group : 'No Group',
                              style: TextStyle(color: Colors.cyanAccent.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600)
                          ),
                        ),

                        const SizedBox(height: 30),
                        const Divider(color: Colors.white24),

                        // --- BASIC INFO ---
                        _row('Phone', player.phone.isNotEmpty ? player.phone : '-', Icons.phone),
                        _row('Age', player.age?.toString() ?? '-', Icons.cake),
                        _row('Joined', player.joinDate != null ? df.format(player.joinDate!) : '-', Icons.calendar_today),

                        // --- ✅ NEW: BILLING SETTINGS ---
                        const SizedBox(height: 15),
                        const Divider(color: Colors.white24),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                              "BILLING SETTINGS",
                              style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)
                          ),
                        ),
                        _row('Billing Day', billingDayStr, Icons.event_repeat),
                        _row('Cycle Type', cycleStr, Icons.loop),

                        // NOTES
                        if (player.notes != null && player.notes!.isNotEmpty) ...[
                          const SizedBox(height: 15),
                          const Divider(color: Colors.white24),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text("NOTES", style: TextStyle(color: Colors.white38, fontSize: 10)),
                          ),
                          Text(
                            player.notes!,
                            style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ]
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

  // Helper Widget for Rows
  Widget _row(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 16),
          Text('$label:', style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // Helper for "1st, 2nd, 3rd" suffix
  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return "th";
    switch (day % 10) {
      case 1: return "st";
      case 2: return "nd";
      case 3: return "rd";
      default: return "th";
    }
  }
}