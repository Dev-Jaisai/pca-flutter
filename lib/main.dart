import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ... other imports ...
import 'package:textewidget/screens/installments/all_installments_screen.dart';
import 'package:textewidget/screens/installments/all_players_installments_screen.dart';
import 'package:textewidget/screens/reminders/sms_reminder_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/landing/intro_landing_screen.dart';
import 'screens/landing/landing_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/add_player_screen.dart';
import 'screens/groups/group_list_screen.dart';
import 'screens/fees/fee_list_screen.dart';
import 'screens/payments/payment_list_screen.dart';
import 'screens/installments/installment_summary_screen.dart';

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
      initialRoute: '/',
      routes: {
        '/': (ctx) => const SplashScreen(),
        '/intro': (ctx) => const IntroLandingScreen(),
        '/dashboard': (ctx) => const LandingScreen(),
        '/players': (ctx) => const HomeScreen(),
        '/players/add': (ctx) => const AddPlayerScreen(),
        '/groups': (ctx) => const GroupListScreen(),
        '/fees': (ctx) => const FeeListScreen(),
        '/all-players-installments': (ctx) => const AllPlayersInstallmentsScreen(),
        '/sms-reminders': (ctx) => const SmsReminderScreen(),

        // --- UPDATED ROUTE HANDLER ---
        '/all-installments': (ctx) {
          final args = ModalRoute.of(ctx)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return AllInstallmentsScreen(initialFilter: args['filter'] as String?);
          }
          return const AllInstallmentsScreen();
        },

        '/installment-summary': (context) {
          final args = ModalRoute.of(context)!.settings.arguments;
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
          return MaterialPageRoute(builder: (_) => PaymentsListScreen(installmentId: 0), settings: settings);
        }
        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
      },
    );
  }
}