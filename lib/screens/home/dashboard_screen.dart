// lib/screens/landing_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/dashboard_stats.dart';
import '../home/add_player_screen.dart'; // adjust or remove if you already have route handling

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _openAddPlayer(BuildContext context) {
    // Replace with your existing navigation logic
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPlayerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // page-level colors / tokens (easy to tweak)
    const bg = Color(0xFFFBF8FF);
    const cardBg = Colors.white;
    const accent = Color(0xFF9B6CFF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text('PCA Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () {},
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddPlayer(context),
        backgroundColor: accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Welcome, Coach',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        Text('Manage players, fees, installments and payments',
                            style: TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accent.withOpacity(0.9), accent]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {},
                    ),
                  )
                ],
              ),

              const SizedBox(height: 18),

              // DashboardStats (YOUR original widget inserted unchanged)
              const DashboardStats(),

              const SizedBox(height: 22),

              // Quick action / feature row (horizontal cards)
              const Text('Highlights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _featureCard(
                      title: 'Players',
                      subtitle: 'View all players, add or delete players',
                      icon: Icons.group,
                      onTap: () {
                        // navigate to players screen
                        Navigator.pushNamed(context, '/players');
                      },
                    ),
                    _featureCard(
                      title: 'All Installments',
                      subtitle: 'Month-wise installments (not filtered)',
                      icon: Icons.calendar_month,
                      onTap: () {
                        Navigator.pushNamed(context, '/installments');
                      },
                    ),
                    _featureCard(
                      title: 'Groups',
                      subtitle: 'Create & manage player groups',
                      icon: Icons.layers,
                      onTap: () {
                        Navigator.pushNamed(context, '/groups');
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Quick list tiles (navigation)
              _sectionTile(
                context,
                icon: Icons.people_alt_outlined,
                title: 'Players',
                subtitle: 'View all players, add or delete players',
                onTap: () => Navigator.pushNamed(context, '/players'),
              ),
              const SizedBox(height: 12),
              _sectionTile(
                context,
                icon: Icons.receipt_long,
                title: 'All Installments',
                subtitle: 'View players with their installments',
                onTap: () => Navigator.pushNamed(context, '/installments'),
              ),
              const SizedBox(height: 12),
              _sectionTile(
                context,
                icon: Icons.group_work_outlined,
                title: 'Groups',
                subtitle: 'Create and manage player groups',
                onTap: () => Navigator.pushNamed(context, '/groups'),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    const Gradient g = LinearGradient(colors: [Color(0xFFBFD8FF), Color(0xFF60A5FA)]);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: g,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0,10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
            ]),
            const Spacer(),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTile(BuildContext context,
      {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF1F3FF), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF6067FF)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
