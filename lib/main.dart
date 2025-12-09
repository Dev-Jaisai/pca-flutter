import 'package:flutter/material.dart';
import 'package:textewidget/screens/installments/all_installments_screen.dart';
import 'package:textewidget/screens/installments/all_players_installments_screen.dart';
import 'package:textewidget/screens/reminders/sms_reminder_screen.dart';
import 'package:textewidget/widgets/dashboard_stats.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/landing/intro_landing_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/add_player_screen.dart';
import 'screens/groups/group_list_screen.dart';
import 'screens/fees/fee_list_screen.dart';
import 'screens/payments/payment_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PCA Academy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      // main.dart (only show routes)
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashScreen(),             // new
        '/intro': (ctx) => const IntroLandingScreen(),  // new (optional)
        '/dashboard': (ctx) => const LandingScreen(),   // your existing file
        '/players': (ctx) => const HomeScreen(),
        '/players/add': (ctx) => const AddPlayerScreen(),
        '/groups': (ctx) => const GroupListScreen(),
        '/fees': (ctx) => const FeeListScreen(),
        '/payments': (ctx) => const PaymentsListScreen(installmentId: 0),
        '/all-installments': (ctx) => AllPlayersInstallmentsScreen(),
        '/all-installments': (ctx) => const AllInstallmentsScreen(),
        '/sms-reminders': (ctx) => const SmsReminderScreen(),

      },

    );
  }
}
