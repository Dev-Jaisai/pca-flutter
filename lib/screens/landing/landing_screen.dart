import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Screens
import '../home/add_player_screen.dart';
import '../../widgets/dashboard_stats.dart';
import '../installments/BulkExtendScreen.dart';
import '../installments/installment_summary_screen.dart';
import '../reminders/sms_reminder_screen.dart';
import '../installments/all_installments_screen.dart';
import '../home/home_screen.dart';
import '../groups/group_list_screen.dart';
import '../fees/fee_list_screen.dart';

// Search & Data Imports
import '../../services/data_manager.dart';
import '../home/player_search_delegate.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

    return Scaffold(
      extendBodyBehindAppBar: true,
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

          // 2. GLOWING ORBS
          Positioned(top: -100, right: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.purple.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 100)]))),
          Positioned(bottom: 50, left: -50, child: Container(height: 250, width: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.15), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 100)]))),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Hello, Coach!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 8),
                              const Text('👋', style: TextStyle(fontSize: 28))
                                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                                  .rotate(begin: -0.05, end: 0.05, duration: 1000.ms, curve: Curves.easeInOut),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Manage your academy efficiently', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6))),
                        ],
                      ),

                      // SEARCH BUTTON
                      GestureDetector(
                        onTap: () async {
                          final players = await DataManager().getPlayers();
                          if (context.mounted) {
                            showSearch(context: context, delegate: PlayerSearchDelegate(players: players));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2))),
                          child: const Icon(Icons.search, color: Colors.cyanAccent, size: 26),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // --- STATS WIDGET (Wrapped in Glass if DashboardStats itself isn't updated) ---
                  // Note: Ensure DashboardStats uses transparent background or wrap its content.
                  // For now, I assume DashboardStats is updated or looks good on dark bg.
                  const DashboardStats(),

                  const SizedBox(height: 32),

                  // --- QUICK ACTIONS ---
                  const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                  const SizedBox(height: 16),

                  Column(
                    children: [
                      _buildGlassActionCard(icon: Icons.person_add, label: 'Add New Player', color: Colors.greenAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlayerScreen()))),
                      const SizedBox(height: 12),
                      _buildGlassActionCard(icon: Icons.payment, label: 'View Payments & Dues', color: Colors.blueAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstallmentSummaryScreen(initialMonth: currentMonth)))),
                      const SizedBox(height: 12),
                      _buildGlassActionCard(icon: Icons.notifications_active, label: 'Send Reminders', color: Colors.orangeAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmsReminderScreen()))),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // --- ALL FEATURES ---
                  const Text('All Features', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                  const SizedBox(height: 16),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildGridActionCard(icon: Icons.list_alt, label: 'All Installments', color: Colors.tealAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AllInstallmentsScreen()))),
                      _buildGridActionCard(icon: Icons.people, label: 'Manage Players', color: Colors.purpleAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen()))),
                      _buildGridActionCard(icon: Icons.group, label: 'Groups', color: Colors.indigoAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupListScreen()))),
                      _buildGridActionCard(icon: Icons.monetization_on, label: 'Fee Structures', color: Colors.amberAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeeListScreen()))),
                      _buildGridActionCard(icon: Icons.edit_calendar, label: 'Extend Dates', color: Colors.pinkAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BulkExtendScreen()))),
                    ],
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlayerScreen())),
        backgroundColor: Colors.cyanAccent,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildGlassActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 24, color: color)),
                const SizedBox(width: 16),
                Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30, color: color),
                const SizedBox(height: 10),
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}