import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/data_manager.dart';
import '../landing/intro_landing_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scale = Tween(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(curve: Curves.elasticOut, parent: _controller),
    );

    _fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _startAppInitialization();


    Timer(const Duration(milliseconds: 1600), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const IntroLandingScreen()),
      );
    });
  }
  Future<void> _startAppInitialization() async {
    // 1. Initialize DataManager
    await DataManager().init();

    // 2. Wait for BOTH: Animation (min 1.6s) AND Data Fetching
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1600)), // Minimum show time
      DataManager().prefetchAllData(), // Background Fetch
    ]);

    // 3. Navigate only after data is ready
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/intro');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Good practice to have a base color
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (ctx, child) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          ),
          child: Hero(
            tag: 'pca-logo',
            child: Image.asset('assets/images/logo.png', width: 130),
          ),
        ),
      ),
    );
  }
}