import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'tabnhandien.dart';
import 'tabghiam.dart';

class ManHinhChinhScreen extends StatelessWidget {
  const ManHinhChinhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Có 2 tab
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "IOTWSRA",
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.black),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.black,
            tabs: [
              Tab(icon: Icon(Icons.language), text: "Nhận diện"),
              Tab(icon: Icon(Icons.mic), text: "Ghi âm"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            NhanDienTab(),
            GhiAmTab(),
          ],
        ),
      ),
    );
  }
}
