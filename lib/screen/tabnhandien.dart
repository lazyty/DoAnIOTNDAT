// ignore_for_file: avoid_types_as_parameter_names, duplicate_ignore
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';

class NhanDienTab extends StatefulWidget {
  final ValueNotifier<String?> recognizedLanguage;
  final ValueNotifier<String?> recognizedContent;
  final ValueNotifier<String?> recognizedModel;
  const NhanDienTab({
    super.key,
    required this.recognizedLanguage,
    required this.recognizedContent,
    required this.recognizedModel,
  });

  @override
  State<NhanDienTab> createState() => NhanDienTabState();
}

class NoteEntry {
  final String source;
  final String data;
  final String language;
  final DateTime timestamp;
  final String modelname;

  NoteEntry({
    required this.source,
    required this.language,
    required this.data,
    required this.timestamp,
    required this.modelname,
  });

  @override
  String toString() {
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    return '[$source] - [$language]\n[$formattedTime][Model: $modelname]: $data';
  }
}

class NhanDienTabState extends State<NhanDienTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final AnimationController _controller;
  late final DatabaseReference _languageRef;
  late final DatabaseReference _noteRef;
  late final DatabaseReference _deviceRef;
  late final DatabaseReference _modelRef;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _noteSub;
  bool _isListeningToApi = false;

  String? _lastSavedContent;
  DateTime? _lastSavedTime;
  bool _isSaving = false;
  List<NoteEntry> _noteEntries = [];

  static const int _maxNoteLength = 30000;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _languageRef = FirebaseDatabase.instance.ref("Results/language");
    _noteRef = FirebaseDatabase.instance.ref("Results/text");
    _deviceRef = FirebaseDatabase.instance.ref("Results/device");
    _modelRef = FirebaseDatabase.instance.ref("Results/model");

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadNotesFromFirestore().then((_) {
      _startListeningToRealtimeDatabase();
    });

    widget.recognizedLanguage.addListener(_onLanguageOrContentChanged);
    widget.recognizedContent.addListener(_onLanguageOrContentChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteSub?.cancel();
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
                return NoteEntry(
                  source: data['source'] ?? '',
                  language: data['language'] ?? '',
                  data: data['text'] ?? '',
                  modelname: data['model'] ?? '',
                  timestamp:
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                );
              }).toList();

          setState(() {
            _noteEntries = entries;
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
        final modelSnapshot = await _modelRef.get();
        final modelname = modelSnapshot.value?.toString() ?? 'unknown';
        // Cắt bớt nội dung nếu vượt quá _maxNoteLength
        String trimmedData = data!;
        if (trimmedData.length > _maxNoteLength) {
          trimmedData = '${trimmedData.substring(0, _maxNoteLength - 3)}...';
          if (kDebugMode) {
            debugPrint(
              '🔴 Ghi chú quá dài (${data.length} ký tự), đã cắt xuống còn $_maxNoteLength ký tự.',
            );
          }
        }

        final noteEntry = NoteEntry(
          source: source,
          language: displayLanguage,
          data: trimmedData,
          timestamp: DateTime.now(),
          modelname: modelname,
        );

        await _appendNoteToFirestore(
          trimmedData,
          source: source,
          language: displayLanguage,
          timestamp: noteEntry.timestamp,
          modelname: modelname,
        );

        if (mounted) {
          setState(() {
            _noteEntries.add(noteEntry);
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
    if (!_isListeningToApi) {
      widget.recognizedLanguage.addListener(_onLanguageOrContentChanged);
      _isListeningToApi = true;
    }
  }

  void _onLanguageOrContentChanged() async {
    final language =
        widget.recognizedLanguage.value?.toLowerCase().trim() ?? '';
    final displayLanguage = _mapLanguage(language);
    final user = FirebaseAuth.instance.currentUser;
    final snapshot =
        await FirebaseFirestore.instance
            .collection('User_Information')
            .doc(user?.uid)
            .get();
    final username = snapshot.data()?['Username'] ?? 'unknown';
    String? content = widget.recognizedContent.value;
    String? namemodel = widget.recognizedModel.value;

    if ((language.isNotEmpty) && (content?.isNotEmpty ?? false)) {
      // Cắt content nếu vượt quá giới hạn
      if (content!.length > _maxNoteLength) {
        content = '${content.substring(0, _maxNoteLength - 3)}...';
        if (kDebugMode) {
          debugPrint(
            '🔴 Nội dung quá dài (${content.length} ký tự), đã rút gọn còn $_maxNoteLength ký tự.',
          );
        }
      }

      final noteEntry = NoteEntry(
        source: 'User: $username',
        language: displayLanguage,
        data: content,
        timestamp: DateTime.now(),
        modelname: namemodel!,
      );

      await _appendNoteToFirestore(
        content,
        source: 'User: $username',
        language: displayLanguage,
        timestamp: noteEntry.timestamp,
        modelname: namemodel,
      );

      if (mounted) {
        setState(() {
          _noteEntries.add(noteEntry);
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
      widget.recognizedModel.value = null;
    }
  }

  Future<void> _appendNoteToFirestore(
    String newEntry, {
    required String source,
    String? language,
    required DateTime timestamp,
    required String modelname,
  }) async {
    final trimmedEntry = newEntry.trim();
    final now = DateTime.now();

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

        await docRef.add({
          'text': trimmedEntry,
          'language': language ?? '',
          'source': source,
          'isUser': source.contains('User'),
          'timestamp': Timestamp.fromDate(timestamp),
          'model': modelname,
        });

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

  List<Map<String, dynamic>> _groupNotesByDate(List<NoteEntry> notes) {
    final Map<String, List<NoteEntry>> groupedNotes = {};
    for (var note in notes) {
      final dateKey =
          '${note.timestamp.day}/${note.timestamp.month}/${note.timestamp.year}';
      if (!groupedNotes.containsKey(dateKey)) {
        groupedNotes[dateKey] = [];
      }
      groupedNotes[dateKey]!.add(note);
    }
    return groupedNotes.entries.map((entry) {
      return {'date': entry.key, 'notes': entry.value};
    }).toList();
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

  void _showChatOptionsDialog(BuildContext context, String fullText) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Tùy chọn"),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                    children: _buildStyledNoteTextSpans(fullText),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: fullText));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text("Đã sao chép")));
                },
                child: const Text("Copy"),
              ),
              TextButton(
                onPressed: () => _handleDelete(context, fullText),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _handleDelete(BuildContext context, String fullText) async {
    final deleted = await _deleteNoteEntryByText(fullText);
    if (deleted) {
      setState(() {
        _noteEntries.removeWhere(
          (note) => note.toString().trim() == fullText.trim(),
        );
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Xóa thành công")));
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Không thể xóa")));
    }
  }

  Future<bool> _deleteNoteEntryByText(String fullText) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    // Regex để tách [source] - [language]\n[00:00:00]: nội dung
    final regex = RegExp(
      r'^\[(.*?)\] - \[(.*?)\]\n\[\d{2}:\d{2}:\d{2}\]: (.*)$',
      dotAll: true,
    );
    final match = regex.firstMatch(fullText.trim());
    if (match == null) return false;

    final source = match.group(1);
    final language = match.group(2);
    final data = match.group(3)?.trim();

    if (data == null) return false;

    final snapshot =
        await FirebaseFirestore.instance
            .collection("User_Information")
            .doc(uid)
            .collection("Content_History")
            .where("text", isEqualTo: data)
            .where("language", isEqualTo: language)
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.delete();
      return true;
    }

    return false;
  }

  List<TextSpan> _buildStyledNoteTextSpans(String text) {
    final lines = text.trim().split('\n');
    List<TextSpan> spans = [];

    final metaRegex = RegExp(r'^\[(.*?)\] - \[(.*?)\]$');
    final timeRegex = RegExp(r'^\[(\d{2}:\d{2}:\d{2})\]:(.*)$');
    final modelTimeRegex =
        RegExp(r'^\[(\d{2}:\d{2}:\d{2})\]\s*\["?Model:\s*(.*?)"?\]\s*:(.*)$');

    for (final line in lines) {
      if (metaRegex.hasMatch(line)) {
        final match = metaRegex.firstMatch(line)!;
        final source = match.group(1)!;
        final language = match.group(2)!;
        final sourceColor = source.contains('User') ? Colors.red : Colors.blue;

        spans.add(
          TextSpan(
            children: [
              TextSpan(
                text: '[$source] - ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: sourceColor,
                ),
              ),
              TextSpan(
                text: '[$language]\n',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
        );
      } else if (modelTimeRegex.hasMatch(line)) {
        final match = modelTimeRegex.firstMatch(line)!;
        final time = match.group(1)!;
        final model = match.group(2)!;
        final content = match.group(3)!.trim();

        spans.add(
          TextSpan(
            children: [
              TextSpan(
                text: '[$time] ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              TextSpan(
                text: '[Model: $model] ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              TextSpan(
                text: ': $content',
                style: const TextStyle(color: Colors.black),
              ),
            ],
          ),
        );
      } else if (timeRegex.hasMatch(line)) {
        final match = timeRegex.firstMatch(line)!;
        final time = match.group(1)!;
        final content = match.group(2)!.trim();

        spans.add(
          TextSpan(
            children: [
              TextSpan(
                text: '[$time]: ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              TextSpan(
                text: content,
                style: const TextStyle(color: Colors.black),
              ),
            ],
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: '$line\n',
            style: const TextStyle(color: Colors.black),
          ),
        );
      }
    }
    return spans;
  }

  Widget _buildContentField(double width, double height) {
    final groupedNotes = _groupNotesByDate(_noteEntries);

    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.all(10),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề và nút xoá
          Row(
            children: [
              const Text(
                "📝 Nội dung",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red),
                tooltip: "Xoá toàn bộ khung nội dung",
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text("Xác nhận xoá"),
                          content: const Text(
                            "Bạn có chắc muốn xoá toàn bộ nội dung không?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Huỷ"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                "Xoá",
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                  );

                  if (confirm == true) {
                    setState(() {
                      _noteEntries.clear();
                    });
                    await _clearContentHistoryForCurrentUser();
                  }
                },
              ),
            ],
          ),
          // Khung hiển thị nội dung
          SizedBox(
            width: width,
            height: height * 0.65,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey, width: 1.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: groupedNotes.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, groupIndex) {
                    final group = groupedNotes[groupIndex];
                    final date = group['date'] as String;
                    final notes = group['notes'] as List<NoteEntry>;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (groupIndex != 0) const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'Ngày $date',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...notes.map((note) {
                          final fullText = note.toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              // Bọc Material để dùng InkWell
                              color: Colors.transparent,
                              child: InkWell(
                                onLongPress:
                                    () => _showChatOptionsDialog(
                                      context,
                                      fullText,
                                    ),
                                child: AbsorbPointer(
                                  absorbing: true,
                                  child: SelectableText.rich(
                                    TextSpan(
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                      children: _buildStyledNoteTextSpans(
                                        fullText,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
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
