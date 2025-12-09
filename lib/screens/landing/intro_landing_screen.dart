import 'package:flutter/material.dart';

class IntroLandingScreen extends StatelessWidget {
  const IntroLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFFF), // FIXED
      body: Column(
        children: [
          // ------------------ FULL WIDTH TOP IMAGE ------------------
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF3EFFF), // light purple behind image
              child: Image.asset(
                'assets/images/cricket_intro.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ------------------ BOTTOM WHITE AREA ------------------
          Expanded(
            flex: 3,
            child: Transform.translate(
              offset: const Offset(0, -25),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(45),
                    topRight: Radius.circular(45),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      "Welcome to PCA Academy",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Your smart assistant for managing players, payments and schedules.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A56F0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/dashboard');
                      },
                      child: const Text(
                        "Let’s Build",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
