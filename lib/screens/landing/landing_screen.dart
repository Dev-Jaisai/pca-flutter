// lib/screens/landing/landing_screen.dart
import 'package:flutter/material.dart';
import '../home/add_player_screen.dart';
import '../../widgets/dashboard_stats.dart';
import '../installments/installment_summary_screen.dart';
import '../reminders/sms_reminder_screen.dart';

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
    final devicePixelRatio = mq.devicePixelRatio;
    final screenWidth = mq.size.width;
    final cacheWidth = (screenWidth * devicePixelRatio).round();

    _bgImage = ResizeImage(const AssetImage('assets/images/cricket_bg.webp'), width: cacheWidth);
    precacheImage(_bgImage, context);
  }

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

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.05),
                color.withOpacity(0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
                size: 24,
              ),
            ],
          ),
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
          // Background Image with Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.deepPurple.shade50,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.6],
                ),
              ),
              child: Image(
                image: _bgImage,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.1),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, Coach!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade900,
                              letterSpacing: -0.5,
                            ),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade600,
                              Colors.purple.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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
                          Icons.sports_cricket,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Dashboard Stats
                  const DashboardStats(),

                  const SizedBox(height: 32),

                  // Quick Actions Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Most Used',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Large Quick Action Cards
                  Column(
                    children: [
                      _buildQuickActionCard(
                        icon: Icons.add_circle,
                        label: 'Add New Player',
                        color: Colors.green.shade600,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddPlayerScreen()),
                        ),
                        isLarge: true,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActionCard(
                        icon: Icons.payment,
                        label: 'View Payments & Dues',
                        color: Colors.blue.shade600,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InstallmentSummaryScreen(initialMonth: currentMonth),
                          ),
                        ),
                        isLarge: true,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickActionCard(
                        icon: Icons.notifications,
                        label: 'Send Reminders',
                        color: Colors.orange.shade600,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SmsReminderScreen()),
                        ),
                        isLarge: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // All Features Section
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
                      _buildQuickActionCard(
                        icon: Icons.list_alt,
                        label: 'All Installments',
                        color: Colors.teal.shade600,
                        onTap: () => Navigator.pushNamed(context, '/all-installments'),
                      ),
                      _buildQuickActionCard(
                        icon: Icons.people,
                        label: 'Manage Players',
                        color: Colors.purple.shade600,
                        onTap: () => Navigator.pushNamed(context, '/players'),
                      ),
                      _buildQuickActionCard(
                        icon: Icons.group,
                        label: 'Groups',
                        color: Colors.indigo.shade600,
                        onTap: () => Navigator.pushNamed(context, '/groups'),
                      ),
                      _buildQuickActionCard(
                        icon: Icons.monetization_on,
                        label: 'Fee Structures',
                        color: Colors.amber.shade700,
                        onTap: () => Navigator.pushNamed(context, '/fees'),
                      ),
                      // Removed: Payment History, Reports, Settings as requested
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Space for bottom navigation
                ],
              ),
            ),
          ),

          // Floating Action Button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPlayerScreen()),
              ),
              backgroundColor: Colors.deepPurple.shade600,
              foregroundColor: Colors.white,
              elevation: 4,
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
