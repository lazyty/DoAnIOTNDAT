import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import '../components/background.dart'; // Đường dẫn tương đối
import 'wave_painter.dart';
class ManHinhChinhScreen extends StatefulWidget {
  const ManHinhChinhScreen({super.key});

  @override
  State<ManHinhChinhScreen> createState() => _ManHinhChinhScreenState();
}

class _ManHinhChinhScreenState extends State<ManHinhChinhScreen>
    with SingleTickerProviderStateMixin {
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

  static const int _maxNoteLength = 10000;

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
        _noiDungGhiChu = updatedText.length > _maxNoteLength
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

  String getCountryCode(String language) {
    final lower = language.toLowerCase().trim();
    const languageMap = {
      'vi': 'vn', 'vietnam': 'vn', 'tiếng việt': 'vn', 'vn': 'vn',
      'english': 'us', 'us': 'us', 'tiếng anh mỹ': 'us',
      'british': 'gb', 'england': 'gb', 'uk': 'gb', 'great britain': 'gb', 'tiếng anh anh': 'gb',
      'japanese': 'jp', 'jp': 'jp', 'nihongo': 'jp', 'tiếng nhật': 'jp',
      'korean': 'kr', 'kr': 'kr', 'hangul': 'kr', 'tiếng hàn': 'kr',
      'french': 'fr', 'fr': 'fr', 'français': 'fr', 'tiếng pháp': 'fr',
      'german': 'de', 'de': 'de', 'deutsch': 'de', 'tiếng đức': 'de',
      'chinese': 'cn', 'cn': 'cn', 'zh': 'cn', 'mandarin': 'cn', 'tiếng trung': 'cn',
      'spanish': 'es', 'es': 'es', 'español': 'es', 'tiếng tây ban nha': 'es',
      'thai': 'th', 'th': 'th', 'tiếng thái': 'th',
    };
    return languageMap[lower] ?? 'vn';
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
                      'packages/country_icons/icons/flags/svg/$countryCode.svg',
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
              _ngonNguHienTai!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
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
          Text("⏳ Đang chờ dữ liệu từ server...", style: TextStyle(fontSize: 20, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTextContentDisplay(double width) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _dangChoDuLieu
          ? _buildWaitingCard(width)
          : (_ngonNguHienTai != null
          ? _buildLanguageCard(width, getCountryCode(_ngonNguHienTai!))
          : const Center(child: Text("Không có dữ liệu.", style: TextStyle(color: Colors.red)))) ,
    );
  }

  Widget _buildContentField(double height) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      height: height * 0.75,
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("📝 Nội dung", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Huỷ")),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Xoá", style: TextStyle(color: Colors.red))),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: Background(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 70),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildTextContentDisplay(screenWidth),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildContentField(screenHeight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'wave_painter.dart';
//
// class ManHinhChinhScreen extends StatefulWidget {
//   const ManHinhChinhScreen({super.key});
//
//   @override
//   State<ManHinhChinhScreen> createState() => _ManHinhChinhScreenState();
// }
//
// class _ManHinhChinhScreenState extends State<ManHinhChinhScreen>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _controller;
//   late final DatabaseReference _languageRef;
//   late final DatabaseReference _noteRef;
//   late final TextEditingController _noteController;
//   late final StreamSubscription _languageSub;
//   late final StreamSubscription _noteSub;
//
//   double _angle = 0;
//   String? _ngonNguHienTai;
//   String? _noiDungGhiChu;
//   bool _dangChoDuLieu = true;
//
//   static const int _maxNoteLength = 10000;
//
//   @override
//   void initState() {
//     super.initState();
//     _noteController = TextEditingController();
//     _languageRef = FirebaseDatabase.instance.ref("Results/language");
//     _noteRef = FirebaseDatabase.instance.ref("Results/text");
//
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 2),
//     )..repeat();
//
//     _languageSub = _languageRef.onValue.listen((event) {
//       final data = event.snapshot.value?.toString();
//       if (data?.isNotEmpty ?? false) {
//         setState(() {
//           _ngonNguHienTai = _mapLanguage(data!);
//           _dangChoDuLieu = false;
//         });
//       }
//     });
//
//     _noteSub = _noteRef.onValue.listen((event) {
//       final data = event.snapshot.value?.toString();
//       if (data?.isNotEmpty ?? false) {
//         final newEntry = "$data\n";
//         final current = _noteController.text;
//         final updatedText = (newEntry + current);
//         _noiDungGhiChu = updatedText.length > _maxNoteLength
//             ? updatedText.substring(0, _maxNoteLength)
//             : updatedText;
//
//         setState(() {
//           _noteController.text = _noiDungGhiChu!;
//         });
//       }
//     });
//
//     Future.delayed(const Duration(seconds: 5), () {
//       if (_ngonNguHienTai == null) {
//         setState(() => _dangChoDuLieu = true);
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     _languageSub.cancel();
//     _noteSub.cancel();
//     _noteController.dispose();
//     super.dispose();
//   }
//
//   String getCountryCode(String language) {
//     final lower = language.toLowerCase().trim();
//     const languageMap = {
//       'vi': 'vn', 'vietnam': 'vn', 'tiếng việt': 'vn', 'vn': 'vn',
//       'english': 'us', 'us': 'us', 'tiếng anh mỹ': 'us',
//       'british': 'gb', 'england': 'gb', 'uk': 'gb', 'great britain': 'gb', 'tiếng anh anh': 'gb',
//       'japanese': 'jp', 'jp': 'jp', 'nihongo': 'jp', 'tiếng nhật': 'jp',
//       'korean': 'kr', 'kr': 'kr', 'hangul': 'kr', 'tiếng hàn': 'kr',
//       'french': 'fr', 'fr': 'fr', 'français': 'fr', 'tiếng pháp': 'fr',
//       'german': 'de', 'de': 'de', 'deutsch': 'de', 'tiếng đức': 'de',
//       'chinese': 'cn', 'cn': 'cn', 'zh': 'cn', 'mandarin': 'cn', 'tiếng trung': 'cn',
//       'spanish': 'es', 'es': 'es', 'español': 'es', 'tiếng tây ban nha': 'es',
//       'thai': 'th', 'th': 'th', 'tiếng thái': 'th',
//     };
//     return languageMap[lower] ?? 'vn';
//   }
//
//   String _mapLanguage(String language) {
//     const languageMap = {
//       'vi': 'Tiếng Việt',
//       'us': 'Tiếng Anh Mỹ',
//       'gb': 'Tiếng Anh Anh',
//       'en': 'Tiếng Anh',
//       'jp': 'Tiếng Nhật',
//       'kr': 'Tiếng Hàn',
//       'fr': 'Tiếng Pháp',
//       'de': 'Tiếng Đức',
//       'cn': 'Tiếng Trung',
//       'es': 'Tiếng Tây Ban Nha',
//       'th': 'Tiếng Thái',
//     };
//     return languageMap[language.toLowerCase().trim()] ?? 'Không xác định';
//   }
//
//   Widget _buildLanguageCard(double width, String countryCode) {
//     return Container(
//       width: width,
//       padding: const EdgeInsets.all(16),
//       decoration: _boxDecoration(),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           SizedBox(
//             width: 40,
//             height: 40,
//             child: AnimatedBuilder(
//               animation: _controller,
//               builder: (_, __) {
//                 _angle = _controller.value * 2 * pi;
//                 return CustomPaint(
//                   painter: WavePainter(_angle),
//                   child: Center(
//                     child: SvgPicture.asset(
//                       'packages/country_icons/icons/flags/svg/$countryCode.svg',
//                       width: 24,
//                       height: 24,
//                       fit: BoxFit.contain,
//                       placeholderBuilder: (_) => const Icon(Icons.flag),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               _ngonNguHienTai!,
//               textAlign: TextAlign.center,
//               style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildWaitingCard(double width) {
//     return Container(
//       width: width,
//       padding: const EdgeInsets.all(16),
//       decoration: _boxDecoration(),
//       child: const Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           CircularProgressIndicator(),
//           SizedBox(height: 12),
//           Text("⏳ Đang chờ dữ liệu từ server...", style: TextStyle(fontSize: 20, color: Colors.grey)),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTextContentDisplay(double width) {
//     return AnimatedSwitcher(
//       duration: const Duration(milliseconds: 400),
//       child: _dangChoDuLieu
//           ? _buildWaitingCard(width)
//           : (_ngonNguHienTai != null
//           ? _buildLanguageCard(width, getCountryCode(_ngonNguHienTai!))
//           : const Center(child: Text("Không có dữ liệu.", style: TextStyle(color: Colors.red)))) ,
//     );
//   }
//
//   Widget _buildContentField(double height) {
//     return Container(
//       margin: const EdgeInsets.only(top: 10),
//       padding: const EdgeInsets.all(16),
//       height: height * 0.75,
//       decoration: _boxDecoration(),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               const Text("📝 Nội dung", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               const Spacer(),
//               IconButton(
//                 icon: const Icon(Icons.clear, color: Colors.red),
//                 tooltip: "Xoá toàn bộ ghi chú",
//                 onPressed: () async {
//                   final confirm = await showDialog<bool>(
//                     context: context,
//                     builder: (context) => AlertDialog(
//                       title: const Text("Xác nhận xoá"),
//                       content: const Text("Bạn có chắc muốn xoá toàn bộ nội dung ghi chú không?"),
//                       actions: [
//                         TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Huỷ")),
//                         TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Xoá", style: TextStyle(color: Colors.red))),
//                       ],
//                     ),
//                   );
//                   if (confirm == true) {
//                     setState(() {
//                       _noteController.clear();
//                       _noiDungGhiChu = "";
//                     });
//                   }
//                 },
//               ),
//             ],
//           ),
//           const SizedBox(height: 2),
//           Expanded(
//             child: TextField(
//               controller: _noteController,
//               expands: true,
//               maxLines: null,
//               minLines: null,
//               readOnly: true,
//               maxLength: _maxNoteLength,
//               textAlignVertical: TextAlignVertical.top,
//               decoration: const InputDecoration(
//                 border: OutlineInputBorder(),
//                 contentPadding: EdgeInsets.only(top: 0, left: 8, right: 8),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   BoxDecoration _boxDecoration() => BoxDecoration(
//     color: Colors.white,
//     borderRadius: BorderRadius.circular(8),
//     boxShadow: const [
//       BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 3)),
//     ],
//   );
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//     final screenHeight = MediaQuery.of(context).size.height;
//
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         automaticallyImplyLeading: false,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.exit_to_app, color: Colors.black),
//             onPressed: () async {
//               await FirebaseAuth.instance.signOut();
//               if (!mounted) return;
//               Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
//             },
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.only(top: 70),
//         child: Column(
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: _buildTextContentDisplay(screenWidth),
//             ),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: _buildContentField(screenHeight),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
