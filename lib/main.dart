import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screen/manhinhchinh.dart';
import 'screen/splash_screen.dart';
import 'screen/login.dart';       
import 'screen/register.dart';    

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
        '/manhinhchinh': (context) => const ManHinhChinhScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
      },
    );
  }
}
