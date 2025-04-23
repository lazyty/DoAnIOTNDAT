import 'dart:math';
import 'dart:async';
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
  final DatabaseReference _dataRef = FirebaseDatabase.instance.ref("What is the Language/Language");
  final DatabaseReference _noteRef = FirebaseDatabase.instance.ref("What is the Language/Content");
  final TextEditingController _noteController = TextEditingController();

  String? _noiDung;
  String? _ghiChu;
  bool _waiting = true;

  late StreamSubscription<DatabaseEvent> _dataSubscription;
  late StreamSubscription<DatabaseEvent> _noteSubscription;

  @override
  void initState() {
    super.initState();

    // Animation Controller
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
    _dataSubscription = _dataRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data.toString().isNotEmpty) {
        setState(() {
          _noiDung = data.toString();
          _waiting = false;
        });
      }
    });

    _noteSubscription = _noteRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data.toString().isNotEmpty) {
        setState(() {
          _ghiChu = data.toString();
          _noteController.text = _ghiChu!;
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
    _dataSubscription.cancel();
    _noteSubscription.cancel();
    super.dispose();
  }

  String getCountryCode(String language) {
    final lower = language.toLowerCase().trim();
    final Map<String, String> languageMap = {
      //Tiếng việtviệt
      'vietnamese': 'vn',
      'vi': 'vn',
      'vietnam': 'vn',
      'tiếng việt': 'vn',
      //Tiếng anh mỹ
      'english': 'us',
      'us': 'us',
      'tiếng anh mỹ': 'us',
      //Tiếng anh anh
      'british': 'gb',
      'england': 'gb',
      'uk': 'gb',
      'great britain': 'gb',
      'tiếng anh anh': 'gb',
      //Tiếng nhật 
      'japanese': 'jp',
      'jp': 'jp',
      'nihongo': 'jp',
      'tiếng nhật': 'jp',
      //Tiếng hàn 
      'korean': 'kr',
      'kr': 'kr',
      'hangul': 'kr',
      'tiếng hàn': 'kr',
      //Tiếng pháp 
      'french': 'fr',
      'fr': 'fr',
      'français': 'fr',
      'tiếng pháp': 'fr',
      //Tiếng đức 
      'german': 'de',
      'de': 'de',
      'deutsch': 'de',
      'tiếng đức': 'de',
      //Tiếng trung 
      'chinese': 'cn',
      'cn': 'cn',
      'zh': 'cn',
      'mandarin': 'cn',
      'tiếng trung': 'cn',
      //Tiếng tây ban nha 
      'spanish': 'es',
      'es': 'es',
      'español': 'es',
      'tiếng tây ban nha': 'es',
      //Tiếng thái 
      'thai': 'th',
      'th': 'th',
      'tiếng thái': 'th',
    };
    return languageMap[lower] ?? 'white';
  }

  Widget _buildEditableNoteField() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(2, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _noteController,
            maxLines: 5,
            maxLength: 2000000,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContentDisplay() {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_waiting) {
      return Container(
        width: screenWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text(
                "⏳ Đang chờ dữ liệu từ server...",
                style: TextStyle(fontSize: 20, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_noiDung != null) {
      final countryCode = getCountryCode(_noiDung!);

      return Container(
        width: screenWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    painter: WavePainter(_angle),
                    child: const SizedBox.expand(),
                  ),
                  SvgPicture.asset(
                    'packages/country_icons/icons/flags/svg/$countryCode.svg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => const Icon(Icons.flag, size: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _noiDung!,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return const Text(
      "Không có dữ liệu.",
      style: TextStyle(fontSize: 16, color: Colors.red),
    );
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
                context,
                '/dangnhap',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 70),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildTextContentDisplay(),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildEditableNoteField(),
            ),
          ],
        ),
      ),
    );
  }
}
