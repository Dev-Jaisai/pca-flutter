// lib/screens/landing/landing_screen.dart
import 'package:flutter/material.dart';
import '../home/add_player_screen.dart';
import '../../widgets/dashboard_stats.dart';
import '../installments/installment_summary_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  // path and provider for background
  final String _bgPath = 'assets/images/cricket_bg.webp';
  late ImageProvider _bgImage;

  @override
  void initState() {
    super.initState();
    // temporary fallback provider — will be replaced in didChangeDependencies with ResizeImage
    _bgImage = AssetImage(_bgPath);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // compute an appropriate cacheWidth to reduce decode cost
    final mq = MediaQuery.of(context);
    final devicePixelRatio = mq.devicePixelRatio;
    final screenWidth = mq.size.width;
    final cacheWidth = (screenWidth * devicePixelRatio).round();

    // Use ResizeImage so Flutter decodes just what's needed
    _bgImage = ResizeImage(const AssetImage('assets/images/cricket_bg.webp'), width: cacheWidth);

    // Precache the resized image
    precacheImage(_bgImage, context);
  }

  void _open(BuildContext context, String routeName) {
    try {
      Navigator.pushNamed(context, routeName);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route not implemented: $routeName')),
      );
    }
  }

  Widget _card(
      BuildContext ctx, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
        Color? color,
      }) {
    final c = color ?? Colors.deepPurple;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap, // whole card clickable
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, size: 28, color: c),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  ],
                ),
              ),
              // chevron is an IconButton so it navigates too
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.grey),
                onPressed: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              const Text('Quick actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Add Player'),
                subtitle: const Text('Open add player form'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlayerScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Create Installments (All)'),
                subtitle: const Text('Generate monthly installments for all players'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Installment generation triggered (demo)')));
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment),
                title: const Text('Payments'),
                subtitle: const Text('Open payments screen'),
                onTap: () {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final currentMonth = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
                  Navigator.push(context, MaterialPageRoute(builder: (_) => InstallmentSummaryScreen(initialMonth: currentMonth)));
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickActionsSheet(context),
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          // Background image (uses pre-cached ResizeImage)
          Positioned.fill(
            child: Image(
              image: _bgImage,
              fit: BoxFit.cover,
              color: Colors.white.withOpacity(0.86),
              colorBlendMode: BlendMode.modulate,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
            ),
          ),

          // subtle gradient overlay for contrast
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.85)],
                  stops: const [0.0, 0.9],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                children: [
                  // header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Welcome, Coach', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('Manage players, fees, installments and payments', style: TextStyle(color: Colors.grey[700])),
                          ],
                        ),
                      ),
                      CircleAvatar(radius: 22, backgroundColor: Colors.deepPurple.shade100, child: const Icon(Icons.sports_cricket, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Dashboard
                  const DashboardStats(),
                  const SizedBox(height: 20),

                  // Feature cards + actions
                  Expanded(
                    child: ListView(
                      children: [
                        _card(
                          context,
                          icon: Icons.list_alt,
                          title: 'All Installments',
                          subtitle: 'View all players with their installments (not month-filtered)',
                          onTap: () => Navigator.pushNamed(context, '/all-installments'),
                          color: Colors.blue,
                        ),
                        _card(
                          context,
                          icon: Icons.people,
                          title: 'Manage Player',
                          subtitle: 'View all players, add or delete players',
                          onTap: () => _open(context, '/players'),
                          color: Colors.teal,
                        ),

                        _card(
                          context,
                          icon: Icons.group_add,
                          title: 'Groups',
                          subtitle: 'Create & manage player groups (Junior / Senior ...)',
                          onTap: () => _open(context, '/groups'),
                          color: Colors.indigo,
                        ),
                        _card(
                          context,
                          icon: Icons.monetization_on,
                          title: 'Fee Structures',
                          subtitle: 'Define monthly fees per group',
                          onTap: () => _open(context, '/fees'),
                          color: Colors.deepPurple,
                        ),
                        _card(
                          context,
                          icon: Icons.sms,
                          title: 'SMS Reminders',
                          subtitle: 'Send due date reminders to players',
                          onTap: () => Navigator.pushNamed(context, '/sms-reminders'),
                          color: Colors.green,
                        ),
                        const SizedBox(height: 14),

                        Text('Quick Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ActionChip(label: const Text('Add Player'), avatar: const Icon(Icons.add), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlayerScreen()))),
                            ActionChip(label: const Text('Create Installment (all)'), avatar: const Icon(Icons.schedule), onPressed: () => _showQuickActionsSheet(context)),
                            ActionChip(label: const Text('View Players'), avatar: const Icon(Icons.list), onPressed: () => Navigator.pushNamed(context, '/players')),
                            ActionChip(label: const Text('Payments'), avatar: const Icon(Icons.payment), onPressed: () {
                              final now = DateTime.now();
                              final currentMonth = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
                              Navigator.push(context, MaterialPageRoute(builder: (_) => InstallmentSummaryScreen(initialMonth: currentMonth)));
                            }),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
