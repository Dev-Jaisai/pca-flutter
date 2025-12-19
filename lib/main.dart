import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

// --- Screen Imports ---
import 'screens/splash/splash_screen.dart';
import 'screens/landing/intro_landing_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/add_player_screen.dart';
import 'screens/groups/group_list_screen.dart';
import 'screens/fees/fee_list_screen.dart';
import 'screens/payments/payment_list_screen.dart';
import 'screens/installments/installment_summary_screen.dart';
import 'screens/installments/all_installments_screen.dart';
import 'screens/installments/all_players_installments_screen.dart';
import 'screens/installments/overdue_players_screen.dart';
import 'screens/reminders/sms_reminder_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('app_cache');
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
      // Start with the Intro Screen
      initialRoute: '/',

      routes: {
        '/': (ctx) => const SplashScreen(),

        // This is your Intro Screen
        '/intro': (ctx) => const IntroLandingScreen(),

        // This is your Main Dashboard (LandingScreen)
        '/dashboard': (ctx) => const LandingScreen(),

        // Other routes
        '/players': (ctx) => const HomeScreen(),
        '/players/add': (ctx) => const AddPlayerScreen(),
        '/groups': (ctx) => const GroupListScreen(),
        '/fees': (ctx) => const FeeListScreen(),
        '/all-players-installments': (ctx) => const AllPlayersInstallmentsScreen(),
        '/sms-reminders': (ctx) => const SmsReminderScreen(),
        '/overdue-players': (context) => const OverduePlayersScreen(),

        // Dynamic Route: All Installments with Filter
        '/all-installments': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return AllInstallmentsScreen(initialFilter: args['filter'] as String?);
          }
          return const AllInstallmentsScreen();
        },

        // Dynamic Route: Installment Summary
        '/installment-summary': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return InstallmentSummaryScreen(
              initialMonth: args['month'] as String?,
              initialFilter: args['filter'] as String?,
            );
          } else if (args is String) {
            return InstallmentSummaryScreen(initialMonth: args);
          }
          return const InstallmentSummaryScreen();
        },
      },

      // Route Generator for complex args (like Payments)
      onGenerateRoute: (settings) {
        if (settings.name == '/payments') {
          final args = settings.arguments;
          if (args is Map<String, dynamic>) {
            final int installmentId = args['installmentId'] is int ? args['installmentId'] as int : 0;
            final double? remainingAmount = args['remaining'] is double ? args['remaining'] as double : null;
            return MaterialPageRoute(
              builder: (_) => PaymentsListScreen(installmentId: installmentId, remainingAmount: remainingAmount),
              settings: settings,
            );
          }
          // Fallback if no args provided
          return MaterialPageRoute(builder: (_) => const PaymentsListScreen(installmentId: 0), settings: settings);
        }
        return null; // Let unknown routes fail or go to default
      },
    );
  }
}