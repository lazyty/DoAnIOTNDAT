import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screen/dangnhap.dart';
import 'screen/dangky.dart';
import 'screen/manhinhchinh.dart';
import 'screen/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iotwsra',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/dangky': (context) => const DangKyScreen(),
        '/dangnhap': (context) => const DangNhapScreen(),
        '/manhinhchinh': (context) => const ManHinhChinhScreen(),
      },
    );
  }
}
