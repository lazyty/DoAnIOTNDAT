import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManHinhChinhScreen extends StatelessWidget {
  const ManHinhChinhScreen({super.key});

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       automaticallyImplyLeading: false,
  //       title: const Text(''),
  //       centerTitle: true,
  //       backgroundColor: Colors.blue,
  //       actions: [
  //         IconButton(
  //           icon: Icon(Icons.exit_to_app),
  //           onPressed: () async {
  //             await FirebaseAuth.instance.signOut();
  //             Navigator.pushNamedAndRemoveUntil(context, '/dangnhap', (route) => false);
  //           },
  //         ),
  //       ],
  //     ),
  //     body: const Center(
  //       child: Text(
  //         '🎉 Chào mừng bạn đến với ứng dụng!',
  //         style: TextStyle(fontSize: 16),
  //       ),
  //     ),
  //   );
  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.black),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/dangnhap', (route) => false);
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB2EBF2), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.celebration, size: 80, color: Colors.blueAccent),
              SizedBox(height: 20),
              Text(
                '🎉 Chào mừng bạn đến với ứng dụng!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

}
