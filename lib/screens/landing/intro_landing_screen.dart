import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart'; // Lottie नसेल तर खालील Image कोड वापरा

class IntroLandingScreen extends StatefulWidget {
  const IntroLandingScreen({super.key});

  @override
  State<IntroLandingScreen> createState() => _IntroLandingScreenState();
}

class _IntroLandingScreenState extends State<IntroLandingScreen> {
  @override
  Widget build(BuildContext context) {
    // स्क्रीनची हाईट आणि विड्थ घेणे (Responsive करण्यासाठी)
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E), // Fallback color
      body: Stack(
        children: [
          // 1. FULL SCREEN BACKGROUND GRADIENT
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2E0249), // Deep Purple (Top)
                  Color(0xFF0F0F0F), // Black (Bottom)
                ],
              ),
            ),
          ),

          // 2. BACKGROUND DECORATION (Orbs)
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.2),
              ),
            ),
          ),

          // 3. MAIN CONTENT (Full Screen Column)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const Spacer(flex: 1), // वर थोडी जागा

                  // --- CRICKET IMAGE / ANIMATION ---
                  // इथे आपण इमेजला 'Circle' मध्ये टाकले आहे जेणेकरून
                  // व्हाईट बॅकग्राउंड डार्क थीमवर खराब दिसणार नाही.
                  Container(
                    height: size.width * 0.8, // स्क्रीनच्या रुंदीनुसार साईज
                    width: size.width * 0.8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05), // हलका ग्लास इफेक्ट
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purpleAccent.withOpacity(0.3),
                          blurRadius: 60,
                          spreadRadius: 10,
                        )
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0), // इमेजला थोडे आत ढकलण्यासाठी

                        // 🔥 पर्याय 1: Lottie Animation (जर असेल तर)
                        // child: Lottie.asset('assets/animations/cricket_shot.json', fit: BoxFit.contain),

                        // 🔥 पर्याय 2: तुमची इमेज (सध्या ही वापरू)
                        child: Image.asset(
                          'assets/images/cricket_intro.png',
                          fit: BoxFit.contain, // इमेज कापली जाणार नाही
                        ),
                      ),
                    ),
                  ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),

                  const Spacer(flex: 1), // इमेज आणि टेक्स्ट मध्ये जागा

                  // --- TEXT SECTION ---
                  Column(
                    children: [
                      Text(
                        "PCA ACADEMY",
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.purple.withOpacity(0.8),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ).animate().fade().slideY(begin: 0.5, end: 0),

                      const SizedBox(height: 16),

                      Text(
                        "Forging Future Legends.\nSmart management for serious cricket.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ).animate(delay: 200.ms).fade().slideY(begin: 0.5, end: 0),
                    ],
                  ),

                  const Spacer(flex: 2), // टेक्स्ट आणि बटन मध्ये जास्त जागा

                  // --- BUTTON SECTION ---
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    },
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.cyanAccent, Colors.blueAccent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Enter Arena",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87, // डार्क बटनवर ब्लॅक टेक्स्ट
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, color: Colors.black87)
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveX(begin: 0, end: 5),
                        ],
                      ),
                    ),
                  ).animate(delay: 500.ms).fade(duration: 800.ms).slideY(begin: 1, end: 0),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}