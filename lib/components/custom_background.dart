import 'package:flutter/material.dart';

class CustomBackground extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const CustomBackground({super.key, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black87],
        )
            : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFE0ECFF)],
        ),
      ),
      child: child,
    );
  }
}
