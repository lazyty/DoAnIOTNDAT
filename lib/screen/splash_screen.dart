import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // Delay để giữ splash 1 giây
    Future.delayed(const Duration(seconds: 2), () {
      // Đăng ký lắng nghe auth state
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (!mounted) return;

        if (user != null) {
          Navigator.pushReplacementNamed(context, '/manhinhchinh');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

