import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math';
import 'package:iotwsra/screen/wave_painter.dart';

class NhanDienTab extends StatefulWidget {
  final ValueNotifier<String?> recognizedLanguage;
  final ValueNotifier<String?> recognizedContent;
  const NhanDienTab({
    super.key,
    required this.recognizedLanguage,
    required this.recognizedContent,
  });

  @override
  State<NhanDienTab> createState() => NhanDienTabState();
}

class NhanDienTabState extends State<NhanDienTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final DatabaseReference _languageRef;
  late final DatabaseReference _noteRef;
  late final DatabaseReference _deviceRef;
  late final TextEditingController _noteController;
  StreamSubscription? _languageSub;
  StreamSubscription? _noteSub;

  String? _currentLanguage;
  String? _noteContent;
  bool _dataLoading = true;
  double _angle = 0;

  static const int _maxNoteLength = 1000000;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _languageRef = FirebaseDatabase.instance.ref("Results/language");
    _noteRef = FirebaseDatabase.instance.ref("Results/text");
    _deviceRef = FirebaseDatabase.instance.ref("Results/device");

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _languageSub = _languageRef.onValue.listen((event) {
      final data = event.snapshot.value?.toString();
      if (data?.isNotEmpty ?? false) {
        setState(() {
          _currentLanguage = _mapLanguage(data!);
          _dataLoading = false;
        });
      }
    });
    // Bước 1: Tải dữ liệu từ Firestore trước
    _loadNotesFromFirestore().then((_) {
      // Bước 2: Bắt đầu lắng nghe dữ liệu mới
      _startListeningToRealtimeDatabase();
    });
    // Fallback nếu sau 5s chưa có ngôn ngữ
    Future.delayed(const Duration(seconds: 5), () {
      if (_currentLanguage == null) {
        setState(() => _dataLoading = true);
      }
    });
    widget.recognizedLanguage.addListener(_onLanguageOrContentChanged);
    widget.recognizedContent.addListener(_onLanguageOrContentChanged);
  }

  void startListeningFromUpload() {
    debugPrint("Bắt đầu lắng nghe dữ liệu từ API sau khi upload");
    _startListeningToApiResult();
  }

  @override
  void dispose() {
    _controller.dispose();
    _languageSub?.cancel();
    _noteSub?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadNotesFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (email != null) {
      try {
        final firestore = FirebaseFirestore.instance;
        final query =
            await firestore
                .collection('User_Information')
                .where('Email', isEqualTo: email)
                .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          final docRef = doc.reference;

          // Lấy toàn bộ content từ subcollection Content_History, sắp xếp theo thời gian
          final contentHistorySnapshot =
              await docRef
                  .collection('Content_History')
                  .orderBy(
                    'timestamp',
                    descending: false,
                  ) // đoạn chat mới nhất lên đầu
                  .get();

          final entries =
              contentHistorySnapshot.docs.map((doc) {
                final text = doc['text'] ?? '';
                final source = doc['source'] ?? '';
                final language = doc['language'] ?? '';
                return '[$source] \n  $text';
              }).toList();

          final combinedText = entries.join('\n');

          setState(() {
            _noteController.text = combinedText;
            _noteContent = combinedText;
          });
        }
      } catch (e) {
        if (kDebugMode) print("Lỗi khi tải ghi chú từ Firestore: $e");
      }
    }
  }

  void _startListeningToRealtimeDatabase() {
    _noteSub = _noteRef.onValue.listen((event) async {
      final data = event.snapshot.value?.toString();
      if (data?.isNotEmpty ?? false) {
        // Đọc giá trị của source từ _deviceRef (ví dụ: "raspberry")
        final deviceSnapshot = await _deviceRef.get();
        final source = deviceSnapshot.value?.toString() ?? 'unknown';

        final newEntry = "[$source]\n  $data\n";
        final current = _noteController.text;
        final updatedText = current + newEntry;

        _noteContent =
            updatedText.length > _maxNoteLength
                ? updatedText.substring(0, _maxNoteLength)
                : updatedText;

        // Lưu với source lấy từ _deviceRef
        await _appendNoteToFirestore(data!, source: source);

        setState(() {
          _noteController.text = _noteContent!;
        });
        _noteController.selection = TextSelection.fromPosition(
          TextPosition(offset: _noteController.text.length),
        );
        await _noteRef.set('');
      }
    });
  }

  void _startListeningToApiResult() {
    widget.recognizedLanguage.addListener(_onLanguageOrContentChanged);
  }
  void _onLanguageOrContentChanged() async {
    final language = widget.recognizedLanguage.value;
    final content = widget.recognizedContent.value;

    if ((language?.isNotEmpty ?? false) || (content?.isNotEmpty ?? false)) {
      final newEntry = "[App]\n  ${content ?? ''}\n"; // Hiển thị đúng định dạng

      final current = _noteController.text;
      final updatedText = current + newEntry; // Thêm vào cuối

      _noteContent =
          updatedText.length > _maxNoteLength
              ? updatedText.substring(updatedText.length - _maxNoteLength)
              : updatedText;

      await _appendNoteToFirestore(
        content ?? '',
        source: 'App',
        language: language,
      );

      if (language?.isNotEmpty ?? false) {
        setState(() {
          _currentLanguage = _mapLanguage(language!);
          _dataLoading = false;
        });
      }

    if (mounted) {
      setState(() {
        _noteController.text = _noteContent!;
        _noteController.selection = TextSelection.fromPosition(
          TextPosition(offset: _noteController.text.length),
        );
      });
    }

      widget.recognizedLanguage.value = null;
      widget.recognizedContent.value = null;
    }
  }

  Future<void> _appendNoteToFirestore(
    String newEntry, {
    required String source,
    String? language,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (uid != null) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('User_Information')
            .doc(uid)
            .collection('Content_History');

        await docRef.add({
          'text': newEntry.trim(),
          'language': language ?? '',
          'source': source,
          'isUser': source == 'App',
          'timestamp': Timestamp.now(),
        });
      } catch (e) {
        if (kDebugMode) print("Lỗi khi thêm entry vào Firestore: $e");
      }
    }
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
      'en': 'us',
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
              _currentLanguage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearContentHistoryForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDocId = user.uid;

    final historyCollection = FirebaseFirestore.instance
        .collection('User_Information')
        .doc(userDocId)
        .collection('Content_History');

    final snapshot = await historyCollection.get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Widget _buildTextContentDisplay(double width) {
    Widget child;
    Key key;
    if (_dataLoading) {
      child = _buildWaitingCard(width);
      key = const ValueKey('waiting');
    } else if (_currentLanguage != null) {
      child = _buildLanguageCard(width, getCountryCode(_currentLanguage!));
      key = ValueKey('lang-$_currentLanguage');
    } else {
      child = const Center(
        child: Text("Không có dữ liệu.", style: TextStyle(color: Colors.red)),
      );
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
                tooltip: "Xoá toàn bộ khung nội dung",
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Xác nhận xoá"),
                      content: const Text("Bạn có chắc muốn xoá toàn bộ nội dung không?"),
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
                      _noteContent = '';
                    });
                    await _clearContentHistoryForCurrentUser();
                  }
                },
              )
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
