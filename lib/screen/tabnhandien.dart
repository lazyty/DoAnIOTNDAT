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

class NoteEntry {
  final String source;
  final String data;
  final String language;

  NoteEntry({required this.source, required this.language, required this.data});

  @override
  String toString() {
    return '[$source] - [$language]:\n  $data';
  }
}

class NhanDienTabState extends State<NhanDienTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller;
  late final DatabaseReference _languageRef;
  late final DatabaseReference _noteRef;
  late final DatabaseReference _deviceRef;
  late final TextEditingController _noteController;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _languageSub;
  StreamSubscription? _noteSub;

  String? _currentLanguage;
  String? _noteContent;
  // ignore: unused_field
  bool _dataLoading = true;
  String? _lastSavedContent;
  DateTime? _lastSavedTime;
  bool _isSaving = false;

  static const int _maxNoteLength = 500000;

  @override
  bool get wantKeepAlive => true;

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

  @override
  void dispose() {
    _controller.dispose();
    _languageSub?.cancel();
    _noteSub?.cancel();
    _noteController.dispose();
    _scrollController.dispose();
    widget.recognizedLanguage.removeListener(_onLanguageOrContentChanged);
    widget.recognizedContent.removeListener(_onLanguageOrContentChanged);
    super.dispose();
  }

  Future<void> _loadNotesFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final firestore = FirebaseFirestore.instance;
        final docRef = firestore.collection('User_Information').doc(user.uid);
        final docSnapshot = await docRef.get();

        if (docSnapshot.exists) {
          final contentHistorySnapshot =
              await docRef
                  .collection('Content_History')
                  .orderBy('timestamp', descending: false)
                  .get();

          final entries =
              contentHistorySnapshot.docs.map((doc) {
                final data = doc.data();
                final text = data['text'] ?? '';
                final source = data['source'] ?? '';
                final language = data['language'] ?? '';
                return '[$source] - [$language]:\n  $text';
              }).toList();

          final combinedText = entries.join('\n');

          setState(() {
            _noteController.text = combinedText;
            _noteContent = combinedText;
          });
        } else {
          debugPrint(
            "⚠️ Không tìm thấy tài liệu người dùng với uid: ${user.uid}",
          );
        }
      } catch (e, stack) {
        debugPrint("❌ Lỗi khi tải ghi chú từ Firestore: $e\n$stack");
      }
    } else {
      debugPrint("⚠️ Không tìm thấy user hiện tại.");
    }
  }

  void _startListeningToRealtimeDatabase() {
    debugPrint('🟠 Bắt đầu lắng nghe Firebase Realtime Database...');
    _noteSub = _noteRef.onValue.listen((event) async {
      final data = event.snapshot.value?.toString();
      if (data?.isNotEmpty ?? false) {
        final languageSnapshot = await _languageRef.get();
        final language = languageSnapshot.value?.toString() ?? 'unknown';
        final displayLanguage = _mapLanguage(language);
        final deviceSnapshot = await _deviceRef.get();
        final source = deviceSnapshot.value?.toString() ?? 'unknown';

        final noteEntry = NoteEntry(
          source: source,
          language: displayLanguage,
          data: data!,
        );
        final current = _noteController.text;
        final updatedText = current.isEmpty
            ? noteEntry.toString()
            : '$current\n${noteEntry.toString()}';

        if (updatedText.length > _maxNoteLength) {
          if (kDebugMode) {
            debugPrint('🔴 Vượt quá giới hạn ký tự cho phép ($_maxNoteLength ký tự)');
          }
          await _noteRef.set(''); // reset dù bị lỗi
          return; // bỏ qua cập nhật
        }
        _noteContent = updatedText;

        // Lưu với source lấy từ _deviceRef
        await _appendNoteToFirestore(
          data,
          source: source,
          language: displayLanguage,
        );

        if (mounted) {
          setState(() {
            _noteController.text = _noteContent!;
            _noteController.selection = TextSelection.fromPosition(
              TextPosition(offset: _noteController.text.length),
            );
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
        await _noteRef.set('');
      }
    });
  }

  void startListeningFromUpload() {
    debugPrint("Bắt đầu lắng nghe dữ liệu từ API sau khi upload");
    _startListeningToApiResult();
  }

  void _startListeningToApiResult() {
    widget.recognizedLanguage.addListener(_onLanguageOrContentChanged);
  }

  void _onLanguageOrContentChanged() async {
    final language = widget.recognizedLanguage.value?.toLowerCase().trim() ?? '';
    final displayLanguage = _mapLanguage(language);
        final user = FirebaseAuth.instance.currentUser;
        final snapshot =
        await FirebaseFirestore.instance
            .collection('User_Information')
            .doc(user?.uid)
            .get();
    final username = snapshot.data()?['Username'] ?? 'unknown';
    final content = widget.recognizedContent.value;

    if ((language.isNotEmpty) && (content?.isNotEmpty ?? false)) {
      final noteEntry = NoteEntry(
        source: 'User: $username',
        language: displayLanguage,
        data: content ?? '',
      );

      final current = _noteController.text;
      final updatedText = current.isEmpty
          ? noteEntry.toString()
          : '$current\n${noteEntry.toString()}';

        if (updatedText.length > _maxNoteLength) {
          if (kDebugMode) {
            debugPrint('🔴 Vượt quá giới hạn ký tự cho phép ($_maxNoteLength ký tự)');
          }
          await _noteRef.set(''); // reset dù bị lỗi
          return; // bỏ qua cập nhật
        }
        _noteContent = updatedText;
        
      await _appendNoteToFirestore(
        content ?? '',
        source: 'User: $username',
        language: displayLanguage,
      );

      if (mounted) {
        setState(() {
          _noteController.text = _noteContent!;
          _noteController.selection = TextSelection.fromPosition(
            TextPosition(offset: _noteController.text.length),
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
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
  final trimmedEntry = newEntry.trim();
  final now = DateTime.now();

  // Nếu đang lưu hoặc dữ liệu trùng trong 5 giây → bỏ qua
  if (_isSaving ||
      (_lastSavedContent == trimmedEntry &&
       _lastSavedTime != null &&
       now.difference(_lastSavedTime!).inSeconds < 5)) {
    if (kDebugMode) print('Bỏ qua lưu vì trùng hoặc đang xử lý');
    return;
  }

  _isSaving = true;

  final user = FirebaseAuth.instance.currentUser;
  final uid = user?.uid;

  if (uid != null) {
    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore
          .collection('User_Information')
          .doc(uid)
          .collection('Content_History');

      final userDoc = await firestore
          .collection('User_Information')
          .doc(uid)
          .get();

      final username = userDoc.data()?['Username'] ?? 'unknown';

      await docRef.add({
        'text': trimmedEntry,
        'language': language ?? '',
        'source': source,
        'isUser': source == username,
        'timestamp': Timestamp.now(),
      });

      // Cập nhật nội dung & thời gian lần lưu gần nhất
      _lastSavedContent = trimmedEntry;
      _lastSavedTime = now;

    } catch (e) {
      if (kDebugMode) print("Lỗi khi thêm entry vào Firestore: $e");
    } finally {
      _isSaving = false;
    }
  } else {
    _isSaving = false;
  }
}


  String _mapLanguage(String language) {
    const languageMap = {
      'vi': '🇻🇳 Tiếng Việt',
      'us': '🇺🇸 Tiếng Anh Mỹ',
      'en': '🇺🇸 Tiếng Anh',
      'gb': '🇬🇧 Tiếng Anh Anh',
      'jp': '🇯🇵 Tiếng Nhật',
      'kr': '🇰🇷 Tiếng Hàn',
      'fr': '🇫🇷 Tiếng Pháp',
      'de': '🇩🇪 Tiếng Đức',
      'cn': '🇨🇳 Tiếng Trung',
      'es': '🇪🇸 Tiếng Tây Ban Nha',
      'th': '🇹🇭 Tiếng Thái',
    };
    return languageMap[language.toLowerCase().trim()] ?? '🌐 Không xác định';
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

    List<TextSpan> _buildStyledNoteTextSpans(String text) {
    final lines = text.trim().split('\n');
    return lines.map((line) {
      final regex = RegExp(r'^\[(.*?)\] - \[(.*?)\]:(.*)$');
      final match = regex.firstMatch(line);
      if (match != null) {
        final source = match.group(1)!;
        final language = match.group(2)!;
        final content = match.group(3)!.trim();
        final sourceColor = source == 'User' ? Colors.red : Colors.blue;
        return TextSpan(
          children: [
            TextSpan(
              text: '[$source]',
              style: TextStyle(fontWeight: FontWeight.bold, color: sourceColor),
            ),
            const TextSpan(text: ' - ',style: TextStyle(fontWeight: FontWeight.bold),),
            TextSpan(
              text: '[$language]',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
            ),
            TextSpan(
              text: '$content\n',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ],
        );
      } else {
        return TextSpan(text: '$line\n');
      }
    }).toList();
  }

Widget _buildContentField(double width, double height) {
  return Container(
    margin: const EdgeInsets.only(top: 3),
    padding: const EdgeInsets.all(10),
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
            ),
          ],
        ),
        SizedBox(
          width: width,
          height: height * 0.65,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey, width: 1.2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Scrollbar(
              thumbVisibility: true,
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SelectableText.rich(
                  TextSpan(
                    children: _buildStyledNoteTextSpans(_noteController.text),
                  ),
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildContentField(width, height),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return _buildNhandienTab(screenWidth, screenHeight);
  }
}
