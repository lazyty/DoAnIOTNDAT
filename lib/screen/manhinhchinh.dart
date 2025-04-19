import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_database/firebase_database.dart';
import 'wave_painter.dart';

class ManHinhChinhScreen extends StatefulWidget {
  const ManHinhChinhScreen({super.key});

  @override
  State<ManHinhChinhScreen> createState() => _ManHinhChinhScreenState();
}

class _ManHinhChinhScreenState extends State<ManHinhChinhScreen>
  with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _angle = 0;
  final DatabaseReference _dataRef =
      FirebaseDatabase.instance.ref("What is the Language/Language");

  String? _noiDung;
  bool _waiting = true;

  @override
  void initState() {
    super.initState();

    // Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _controller.addListener(() {
      setState(() {
        _angle = _controller.value * 2 * pi;
      });
    });

    // Firebase listener
    _dataRef.onValue.listen((event) {
      final data = event.snapshot.value;
       if (data != null && data.toString().isNotEmpty) {
        setState(() {
          _noiDung = data.toString();
          _waiting = false;
        });
      }
    });
    // Timeout nếu đợi quá lâu
    Future.delayed(const Duration(seconds: 5), () {
      if (_noiDung == null) {
        setState(() {
          _waiting = true;
        });
      }
    });
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
String getCountryCode(String language) {
  final languageMap = {
    'vietnamese': 'vn',
    'english': 'us',
    'japanese': 'jp',
    'korean': 'kr',
    'french': 'fr',
    'german': 'de',
    'chinese': 'cn',
    'spanish': 'es',
    'thai': 'th',
  };
  return languageMap[language.toLowerCase()] ?? 'white';
}
  
  Widget _buildNoiDung() {
    if (_noiDung != null) {
      final countryCode = getCountryCode(_noiDung!);
      final flagAsset =
          'packages/country_icons/icons/flags/svg/$countryCode.svg';

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            flagAsset,
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 10),
          Text(
            _noiDung!,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else if (_waiting) {
      return const Text(
        "⏳ Đang chờ dữ liệu từ server...",
        style: TextStyle(fontSize: 16, color: Colors.grey),
      );
    } else {
      return const Text(
        "Không có dữ liệu.",
        style: TextStyle(fontSize: 16, color: Colors.red),
      );
    }
  }

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
              Navigator.pushNamedAndRemoveUntil(
                  context, '/dangnhap', (route) => false);
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
          child: SizedBox(
            width: 200,
            height: 200,
            child: CustomPaint(
              painter: WavePainter(_angle),
              size: MediaQuery.of(context).size,
              child: Center(child: _buildNoiDung()),
            ),
          ),
        ),
      ),
    );
  }
}
