import 'package:flutter/material.dart';

class AnimatedDashboardCard extends StatelessWidget {
  final Widget child;
  final int index;
  const AnimatedDashboardCard({super.key, required this.child, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + (index * 100)),
      curve: Curves.easeOut,
      builder: (ctx, value, _) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 20),
          child: Opacity(opacity: value, child: child),
        );
      },
    );
  }
}
