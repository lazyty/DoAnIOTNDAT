import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DangNhapScreen extends StatefulWidget {
  const DangNhapScreen({super.key});

  @override
  State<DangNhapScreen> createState() => _DangNhapScreenState();
}

class _DangNhapScreenState extends State<DangNhapScreen> {
  final TextEditingController _emailOrUsernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _dangNhap() async {
    final input = _emailOrUsernameController.text.trim();
    final matKhau = _passwordController.text;

    if (input.isEmpty || matKhau.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập đầy đủ thông tin.')),
      );
      return;
    }

    final hashedPassword = hashPassword(matKhau);
    try {
      QuerySnapshot snapshot;

      if (input.contains('@')) {
        // Truy vấn theo email
        snapshot = await _firestore.collection('User_Information').where('Email', isEqualTo: input).get();
      } else {
        // Truy vấn theo username
        snapshot = await _firestore.collection('User_Information').where('Username', isEqualTo: input).get();
      }

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tìm thấy người dùng.')),
        );
        return;
      }

      final userData = snapshot.docs.first.data() as Map<String, dynamic>;
      final storedPassword = userData['Password'];

      if (storedPassword == hashedPassword) {
        // Đăng nhập FirebaseAuth để duy trì session
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: userData['Email'],
          password: matKhau,
        );

        // Lưu trạng thái đăng nhập vào SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setInt('loginTimestamp', DateTime.now().millisecondsSinceEpoch);
        Navigator.pushReplacementNamed(context, '/manhinhchinh');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mật khẩu không đúng.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng nhập: $e')),
      );
    }
  }

  Future<void> _guiEmailResetMatKhau(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email reset mật khẩu đã được gửi!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  void _showResetPasswordDialog() {
    TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Reset Mật khẩu'),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(hintText: 'Nhập email của bạn'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Đóng Dialog
              },
              child: Text('Đóng'),
            ),
            TextButton(
              onPressed: () {
                String email = emailController.text.trim();
                if (email.isNotEmpty) {
                  _guiEmailResetMatKhau(email);
                  Navigator.of(context).pop(); // Đóng Dialog sau khi gửi email
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập email của bạn.')),
                  );
                }
              },
              child: Text('Gửi Email'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset('assets/images/icon_app.png', height: 200),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailOrUsernameController,
                decoration: InputDecoration(labelText: 'Email hoặc Username'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Mật khẩu'),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _showResetPasswordDialog,
                        child: const Text('Quên mật khẩu?'),
                      ),
                      ElevatedButton(
                        onPressed: _dangNhap,
                        child: const Text('Đăng Nhập'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/dangky');
                        },
                        child: const Text('Bạn là người mới?'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
