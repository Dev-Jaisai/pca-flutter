// lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
import 'screens/installments/installment_summary_screen.dart'; // Add this import

void main() async {
  // Make main async and ensure WidgetsFlutterBinding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Open the app_cache box before the app starts
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

      // initial route
      initialRoute: '/',

      // static route table (simple screens without required runtime args)
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/intro': (ctx) => const IntroLandingScreen(),
        '/dashboard': (ctx) => const LandingScreen(),
        '/players': (ctx) => const HomeScreen(),
        '/players/add': (ctx) => const AddPlayerScreen(),
        '/groups': (ctx) => const GroupListScreen(),
        '/fees': (ctx) => const FeeListScreen(),
        '/all-players-installments': (ctx) => const AllPlayersInstallmentsScreen(),
        '/all-installments': (ctx) => const AllInstallmentsScreen(),
        '/sms-reminders': (ctx) => const SmsReminderScreen(),
        // Add InstallmentSummaryScreen route with initialMonth parameter
        '/installment-summary': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;

          if (args is Map<String, dynamic>) {
            return InstallmentSummaryScreen(
              initialMonth: args['month'] as String?,
              initialFilter: args['filter'] as String?,  // Pass filter to screen
            );
          } else if (args is String) {
            // Backward compatibility: if only month string is passed
            return InstallmentSummaryScreen(initialMonth: args);
          }
          return const InstallmentSummaryScreen();
        },
      },

      // handle routes that need runtime arguments
      onGenerateRoute: (settings) {
        // Handle payments route
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

          // fallback
          return MaterialPageRoute(
            builder: (_) => PaymentsListScreen(installmentId: 0),
            settings: settings,
          );
        }

        // Handle installment-summary with arguments using named route
        if (settings.name == '/installment-summary' && settings.arguments != null) {
          return MaterialPageRoute(
            builder: (_) => InstallmentSummaryScreen(initialMonth: settings.arguments as String),
            settings: settings,
          );
        }

        // Unknown route fallback
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      },
    );
  }
}