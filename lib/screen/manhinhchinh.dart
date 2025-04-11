import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManHinhChinhScreen extends StatelessWidget {
  const ManHinhChinhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(''),
        centerTitle: true,
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(context, '/dangnhap', (route) => false);
            },
          ),
        ],
      ),
      body: const Center(
        child: Text(
          '🎉 Chào mừng bạn đến với ứng dụng!',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
