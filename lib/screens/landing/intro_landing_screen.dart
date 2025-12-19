import 'package:flutter/material.dart';

class IntroLandingScreen extends StatefulWidget {
  const IntroLandingScreen({super.key});

  @override
  State<IntroLandingScreen> createState() => _IntroLandingScreenState();
}

class _IntroLandingScreenState extends State<IntroLandingScreen> {

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // OPTIMIZATION: Pre-load the image so it shows up instantly without lag
    precacheImage(const AssetImage('assets/images/cricket_intro.png'), context);
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width to optimize image decoding
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF3EFFF),
      body: Column(
        children: [
          // ------------------ FULL WIDTH TOP IMAGE ------------------
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF3EFFF),
              child: Image(
                image: ResizeImage(
                  const AssetImage('assets/images/cricket_intro.png'),
                  // Decode image only as wide as the screen (saves memory & loads faster)
                  width: (screenWidth * 2).toInt(),
                ),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      "Welcome to PCA Academy",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Your smart assistant for managing players, payments and schedules.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),

                    const Spacer(), // Pushes button to bottom

                    // Let's Build Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A56F0),
                          elevation: 8,
                          shadowColor: const Color(0xFF8A56F0).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          // This matches the '/dashboard' route defined in main.dart
                          Navigator.pushReplacementNamed(context, '/dashboard');
                        },
                        child: const Text(
                          "Let’s Build",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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