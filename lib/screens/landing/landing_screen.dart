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
  final String _bgPath = 'assets/images/cricket_bg.webp';
  late ImageProvider _bgImage;

  @override
  void initState() {
    super.initState();
    _bgImage = AssetImage(_bgPath);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    final cacheWidth = (mq.size.width * mq.devicePixelRatio).round();
    _bgImage = ResizeImage(const AssetImage('assets/images/cricket_bg.webp'), width: cacheWidth);
    precacheImage(_bgImage, context);
  }

  // ---------------- QUICK ACTION CARD ----------------
  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLarge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isLarge ? double.infinity : null,
        padding: isLarge
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 16)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: isLarge ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: isLarge ? 24 : 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isLarge ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isLarge)
              Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

    return Scaffold(
      body: Stack(
        children: [
          // ---------- BACKGROUND ----------
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.deepPurple.shade50, Colors.white],
                  stops: const [0.0, 0.6],
                ),
              ),
              child: Image(
                image: _bgImage,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.5),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---------- HEADER ----------
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 👋 Greeting Row
                          Row(
                            children: [
                              Text(
                                'Hello, Coach!',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '👋',
                                style: TextStyle(fontSize: 28),
                              )
                                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                                  .rotate(
                                  begin: -0.05,
                                  end: 0.05,
                                  duration: 1000.ms,
                                  curve: Curves.easeInOut,
                                  alignment: Alignment.bottomCenter
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your academy efficiently',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),

                      // 🔍 SEARCH ICON
                      GestureDetector(
                        onTap: () async {
                          final players = await DataManager().getPlayers();
                          if (context.mounted) {
                            showSearch(
                              context: context,
                              delegate: PlayerSearchDelegate(players: players),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.deepPurple.shade600, Colors.purple.shade600],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.shade300.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.search,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2000.ms),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Stats Widget
                  const DashboardStats(),

                  const SizedBox(height: 32),

                  // ---------- QUICK ACTIONS ----------
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Column(
                    children: [
                      _buildQuickActionCard(
                        icon: Icons.add_circle,
                        label: 'Add New Player',
                        color: Colors.green.shade600,
                        isLarge: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddPlayerScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActionCard(
                        icon: Icons.payment,
                        label: 'View Payments & Dues',
                        color: Colors.blue.shade600,
                        isLarge: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InstallmentSummaryScreen(initialMonth: currentMonth),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActionCard(
                        icon: Icons.notifications,
                        label: 'Send Reminders',
                        color: Colors.orange.shade600,
                        isLarge: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SmsReminderScreen()),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ---------- ALL FEATURES ----------
                  Text(
                    'All Features',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // 1. All Installments
                      _buildQuickActionCard(
                        icon: Icons.list_alt,
                        label: 'All Installments',
                        color: Colors.teal.shade600,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AllInstallmentsScreen()),
                        ),
                      ),

                      // 2. Manage Players
                      _buildQuickActionCard(
                        icon: Icons.people,
                        label: 'Manage Players',
                        color: Colors.purple.shade600,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                        ),
                      ),

                      // 3. Groups
                      _buildQuickActionCard(
                        icon: Icons.group,
                        label: 'Groups',
                        color: Colors.indigo.shade600,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GroupListScreen()),
                        ),
                      ),

                      // 4. Fees
                      _buildQuickActionCard(
                        icon: Icons.monetization_on,
                        label: 'Fee Structures',
                        color: Colors.amber.shade700,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FeeListScreen()),
                        ),
                      ),

                      // ✅ 5. NEW: EXTEND DATES (Added Here)
                      _buildQuickActionCard(
                        icon: Icons.edit_calendar,
                        label: 'Extend Dates',
                        color: Colors.pink.shade600, // Distinct Color
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BulkExtendScreen()),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ---------- FAB ----------
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.deepPurple.shade600,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPlayerScreen()),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}