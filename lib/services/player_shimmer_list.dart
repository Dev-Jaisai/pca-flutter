// lib/widgets/player_shimmer_list.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PlayerShimmerList extends StatelessWidget {
  const PlayerShimmerList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 3)),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(radius: 28, backgroundColor: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: double.infinity, height: 16, color: Colors.white),
                        const SizedBox(height: 8),
                        Container(width: 120, height: 12, color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 36, height: 36, color: Colors.white),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
