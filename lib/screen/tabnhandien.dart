import 'wave_painter.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_database/firebase_database.dart';

class NhanDienTab extends StatefulWidget {
  const NhanDienTab({super.key});

  @override
  State<NhanDienTab> createState() => _NhanDienTabState();
}

class _NhanDienTabState extends State<NhanDienTab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final DatabaseReference _languageRef;
  late final DatabaseReference _noteRef;
  late final TextEditingController _noteController;
  late final StreamSubscription _languageSub;
  late final StreamSubscription _noteSub;

  double _angle = 0;
  String? _ngonNguHienTai;
  String? _noiDungGhiChu;
  bool _dangChoDuLieu = true;

  static const int _maxNoteLength = 100000;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _languageRef = FirebaseDatabase.instance.ref("Results/language");
    _noteRef = FirebaseDatabase.instance.ref("Results/text");

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _languageSub = _languageRef.onValue.listen((event) {
      final data = event.snapshot.value?.toString();
      if (data?.isNotEmpty ?? false) {
        setState(() {
          _ngonNguHienTai = _mapLanguage(data!);
          _dangChoDuLieu = false;
        });
      }
    });

    _noteSub = _noteRef.onValue.listen((event) {
      final data = event.snapshot.value?.toString();
      if (data?.isNotEmpty ?? false) {
        final newEntry = "$data\n";
        final current = _noteController.text;
        final updatedText = (newEntry + current);
        _noiDungGhiChu =
            updatedText.length > _maxNoteLength
                ? updatedText.substring(0, _maxNoteLength)
                : updatedText;

        setState(() {
          _noteController.text = _noiDungGhiChu!;
        });
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (_ngonNguHienTai == null) {
        setState(() => _dangChoDuLieu = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _languageSub.cancel();
    _noteSub.cancel();
    _noteController.dispose();
    super.dispose();
  }

  String _mapLanguage(String language) {
    const languageMap = {
      'vi': 'Tiếng Việt',
      'us': 'Tiếng Anh Mỹ',
      'gb': 'Tiếng Anh Anh',
      'en': 'Tiếng Anh',
      'jp': 'Tiếng Nhật',
      'kr': 'Tiếng Hàn',
      'fr': 'Tiếng Pháp',
      'de': 'Tiếng Đức',
      'cn': 'Tiếng Trung',
      'es': 'Tiếng Tây Ban Nha',
      'th': 'Tiếng Thái',
    };
    return languageMap[language.toLowerCase().trim()] ?? 'Không xác định';
  }

  String getCountryCode(String language) {
    final lower = language.toLowerCase().trim();
    const languageMap = {
      'vi': 'vn',
      'vietnam': 'vn',
      'tiếng việt': 'vn',
      'english': 'us',
      'us': 'us',
      'tiếng anh mỹ': 'us',
      'british': 'gb',
      'england': 'gb',
      'uk': 'gb',
      'tiếng anh anh': 'gb',
      'japanese': 'jp',
      'jp': 'jp',
      'tiếng nhật': 'jp',
      'korean': 'kr',
      'kr': 'kr',
      'tiếng hàn': 'kr',
      'french': 'fr',
      'fr': 'fr',
      'tiếng pháp': 'fr',
      'german': 'de',
      'de': 'de',
      'tiếng đức': 'de',
      'chinese': 'cn',
      'cn': 'cn',
      'tiếng trung': 'cn',
      'spanish': 'es',
      'es': 'es',
      'tiếng tây ban nha': 'es',
      'thai': 'th',
      'th': 'th',
      'tiếng thái': 'th',
    };
    return languageMap[lower] ?? 'vn';
  }

  Widget _buildLanguageCard(double width, String countryCode) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                _angle = _controller.value * 2 * pi;
                return CustomPaint(
                  painter: WavePainter(_angle),
                  child: Center(
                    child: SvgPicture.asset(
                      'icons/flags/svg/$countryCode.svg',
                      package: 'country_icons',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      placeholderBuilder: (_) => const Icon(Icons.flag),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _ngonNguHienTai ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContentDisplay(double width) {
    Widget child;
    Key key;
    if (_dangChoDuLieu) {
      child = _buildWaitingCard(width);
      key = const ValueKey('waiting');
    } else if (_ngonNguHienTai != null) {
      child = _buildLanguageCard(width, getCountryCode(_ngonNguHienTai!));
      key = ValueKey('lang-$_ngonNguHienTai');
    } else {
      child = const Center(child: Text("Không có dữ liệu.", style: TextStyle(color: Colors.red)));
      key = const ValueKey('no-data');
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: Container(key: key, child: child),
    );
  }

  Widget _buildWaitingCard(double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: const Column(
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
    );
  }

  Widget _buildContentField(double height) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.all(10),
      height: height * 0.6,
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "📝 Nội dung",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red),
                tooltip: "Xoá toàn bộ ghi chú",
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Xác nhận xoá"),
                      content: const Text("Bạn có chắc muốn xoá toàn bộ nội dung ghi chú không?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Huỷ"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Xoá", style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    setState(() {
                      _noteController.clear();
                      _noiDungGhiChu = "";
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: TextField(
              controller: _noteController,
              expands: true,
              maxLines: null,
              minLines: null,
              readOnly: true,
              maxLength: _maxNoteLength,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.only(top: 0, left: 8, right: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _boxDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    boxShadow: const [
      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 3)),
    ],
  );

  Widget _buildNhandienTab(double width, double height) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTextContentDisplay(width),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildContentField(height),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return _buildNhandienTab(screenWidth, screenHeight);
  }
}
