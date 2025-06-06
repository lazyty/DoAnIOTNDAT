// ignore_for_file: avoid_types_as_parameter_names, duplicate_ignore
import 'dart:math' as math show min;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String? translatedText;
  final String? flagAndLang;

  NoteEntry({
    required this.source,
    required this.language,
    required this.data,
    required this.timestamp,
    required this.modelname,
    this.translatedText,
    this.flagAndLang,
  });

  NoteEntry copyWith({
    String? source,
    String? data,
    String? language,
    DateTime? timestamp,
    String? modelname,
    String? translatedText,
    String? flagAndLang,
  }) {
    return NoteEntry(
      source: source ?? this.source,
      data: data ?? this.data,
      language: language ?? this.language,
      timestamp: timestamp ?? this.timestamp,
      modelname: modelname ?? this.modelname,
      translatedText: translatedText ?? this.translatedText,
      flagAndLang: flagAndLang ?? this.flagAndLang,
    );
  }

  @override
  String toString() {
    final formattedTime =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';

    String result =
        '[$source] - [$language]\n[$formattedTime][Model: $modelname]: $data';

    if (translatedText != null && translatedText!.isNotEmpty && flagAndLang != null) {
      result += '\n🌐 Dịch sang $flagAndLang: $translatedText';
    }
    return result;
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

  String? _lastSavedContent;
  DateTime? _lastSavedTime;
  bool _isSaving = false;
  List<NoteEntry> _noteEntries = [];

  String? _recentlyDeletedContent;
  String? _recentlyDeletedSource;
  String? _recentlyDeletedLanguage;
  String? _recentlyDeletedModel;
  DateTime? _deletionTime;

  // Translation settings
  static const String _geminiApiKey = '';
  String _selectedTargetLanguage = 'vi';
  final Map<String, String> _translationCache = {};

  // Available target languages for translation
  final Map<String, String> _availableLanguages = {
    'vi': '🇻🇳 Tiếng Việt',
    'en': '🇬🇧 English',
    'ja': '🇯🇵 日本語',
    'ko': '🇰🇷 한국어',
    'zh': '🇨🇳 中文',
    'fr': '🇫🇷 Français',
    'de': '🇩🇪 Deutsch',
    'es': '🇪🇸 Español',
    'pt': '🇵🇹 Português',
    'it': '🇮🇹 Italiano',
    'ru': '🇷🇺 Русский',
    'th': '🇹🇭 ไทย',
    'ar': '🇸🇦 العربية',
  };

  static const int _maxNoteLength = 30000;
  static const int _deletionIgnoreDurationSeconds = 300;

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
    _loadSelectedLanguage();
    widget.recognizedLanguage.addListener(_onLanguageOrContentChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteSub?.cancel();
    _scrollController.dispose();
    widget.recognizedLanguage.removeListener(_onLanguageOrContentChanged);
    super.dispose();
  }

  Future<String?> _translateText(String text, String sourceLanguage) async {
    try {
      final cacheKey = '${text}_${sourceLanguage}_$_selectedTargetLanguage';
      if (_translationCache.containsKey(cacheKey)) {
        return _translationCache[cacheKey];
      }

      if (_getLanguageCode(sourceLanguage) == _selectedTargetLanguage) {
        return null;
      }

      const url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

      final prompt =
          'Translate the following ${_getLanguageName(_getLanguageCode(sourceLanguage))} sentence into ${_getLanguageName(_selectedTargetLanguage)} in one sentence only. '
          'Return only the translated text, no explanations or additional text: "$text"';

      final response = await http.post(
        Uri.parse('$url?key=$_geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText =
            data['candidates']?[0]?['content']?['parts']?[0]?['text']
                ?.toString()
                .trim();

        if (translatedText != null && translatedText.isNotEmpty) {
          _translationCache[cacheKey] = translatedText;
          return translatedText;
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            'Translation API error: ${response.statusCode} - ${response.body}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Translation error: $e');
      }
    }
    return null;
  }

  String _getLanguageCode(String displayLanguage) {
    const languageCodeMap = {
      "🇻🇳 Tiếng Việt": "vi",
      "🇬🇧 Tiếng Anh": "en",
      "🇺🇸 Tiếng Anh Mỹ": "en",
      "🇬🇧 Tiếng Anh Anh": "en",
      "🇯🇵 Tiếng Nhật": "ja",
      "🇰🇷 Tiếng Hàn": "ko",
      "🇨🇳 Tiếng Trung": "zh",
      "🇹🇼 Tiếng Trung Phồn thể": "zh",
      "🇫🇷 Tiếng Pháp": "fr",
      "🇩🇪 Tiếng Đức": "de",
      "🇪🇸 Tiếng Tây Ban Nha": "es",
      "🇵🇹 Tiếng Bồ Đào Nha": "pt",
      "🇧🇷 Tiếng Bồ Đào Nha (Brazil)": "pt",
      "🇮🇹 Tiếng Ý": "it",
      "🇳🇱 Tiếng Hà Lan": "nl",
      "🇷🇺 Tiếng Nga": "ru",
      "🇵🇱 Tiếng Ba Lan": "pl",
      "🇹🇷 Tiếng Thổ Nhĩ Kỳ": "tr",
      "🇸🇪 Tiếng Thụy Điển": "sv",
      "🇫🇮 Tiếng Phần Lan": "fi",
      "🇳🇴 Tiếng Na Uy": "no",
      "🇩🇰 Tiếng Đan Mạch": "da",
      "🇨🇿 Tiếng Séc": "cs",
      "🇭🇺 Tiếng Hungary": "hu",
      "🇷🇴 Tiếng Romania": "ro",
      "🇹🇭 Tiếng Thái": "th",
      "🇮🇩 Tiếng Indonesia": "id",
      "🇲🇾 Tiếng Malaysia": "ms",
      "🇮🇳 Tiếng Hindi": "hi",
      "🇧🇩 Tiếng Bengal": "bn",
      "🇺🇦 Tiếng Ukraina": "uk",
      "🇮🇱 Tiếng Do Thái": "he",
      "🇸🇦 Tiếng Ả Rập": "ar",
    };
    return languageCodeMap[displayLanguage] ?? 'unknown';
  }

  String _getLanguageName(String languageCode) {
    const languageNameMap = {
      'vi': 'Vietnamese',
      'en': 'English',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'fr': 'French',
      'de': 'German',
      'es': 'Spanish',
      'pt': 'Portuguese',
      'it': 'Italian',
      'nl': 'Dutch',
      'ru': 'Russian',
      'pl': 'Polish',
      'tr': 'Turkish',
      'sv': 'Swedish',
      'fi': 'Finnish',
      'no': 'Norwegian',
      'da': 'Danish',
      'cs': 'Czech',
      'hu': 'Hungarian',
      'ro': 'Romanian',
      'th': 'Thai',
      'id': 'Indonesian',
      'ms': 'Malay',
      'hi': 'Hindi',
      'bn': 'Bengali',
      'uk': 'Ukrainian',
      'he': 'Hebrew',
      'ar': 'Arabic',
    };
    return languageNameMap[languageCode] ?? 'Unknown';
  }

  Future<void> _loadSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('selectedLanguage');
    if (savedLang != null && _availableLanguages.containsKey(savedLang)) {
      setState(() {
        _selectedTargetLanguage = savedLang;
      });
    }
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
                  translatedText: data['translatedText'],
                  timestamp:
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                );
              }).toList();

          setState(() {
            _noteEntries = entries;
          });

          _translateMissingEntries();

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
          debugPrint("Không tìm thấy tài liệu người dùng với uid: ${user.uid}");
        }
      } catch (e, stack) {
        debugPrint("Lỗi khi tải ghi chú từ Firestore: $e\n$stack");
      }
    } else {
      debugPrint("Không tìm thấy user hiện tại.");
    }
  }

  Future<void> _translateMissingEntries() async {
    for (int i = 0; i < _noteEntries.length; i++) {
      final entry = _noteEntries[i];
      final selectedLangName = _availableLanguages[_selectedTargetLanguage];
      final sourceCode = _getLanguageCode(entry.language);
      if (sourceCode == _selectedTargetLanguage) {
        if (entry.translatedText != null || entry.flagAndLang != null) {
          _noteEntries[i] = entry.copyWith(
            translatedText: null,
            flagAndLang: null,
          );
          if (mounted) setState(() {});
        }
        continue;
      }

      if (entry.translatedText == null ||
          entry.translatedText!.isEmpty ||
          entry.flagAndLang != selectedLangName) {

        final translatedText = await _translateText(entry.data, entry.language);

        if (translatedText != null) {
          _noteEntries[i] = entry.copyWith(
            translatedText: translatedText,
            flagAndLang: selectedLangName,
          );

          await _updateTranslationInFirestore(entry, translatedText);
          if (mounted) setState(() {});
        }
      }
    }
  }

  Future<void> _updateTranslationInFirestore(
    NoteEntry entry,
    String translatedText,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final historyCollection = firestore
          .collection('User_Information')
          .doc(user.uid)
          .collection('Content_History');

      final querySnapshot = await historyCollection
          .where('text', isEqualTo: entry.data)
          .where('language', isEqualTo: entry.language)
          .where('source', isEqualTo: entry.source)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'translatedText': translatedText,
          'translatedLanguage': _availableLanguages[_selectedTargetLanguage] ?? _selectedTargetLanguage,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating translation in Firestore: $e');
      }
    }
  }

  void _startListeningToRealtimeDatabase() {
    debugPrint('Bắt đầu lắng nghe Firebase Realtime Database...');
    _noteSub = _noteRef.onValue.listen((event) async {
      try {
        final data = event.snapshot.value?.toString();
        if (data?.isEmpty ?? true) return;

        // Get current user and username
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (kDebugMode) debugPrint('Không có user đăng nhập');
          return;
        }

        final snapshot =
            await FirebaseFirestore.instance
                .collection('User_Information')
                .doc(user.uid)
                .get();
        final username = snapshot.data()?['Username'] ?? 'unknown';

        // Get other data
        final languageSnapshot = await _languageRef.get();
        final language = languageSnapshot.value?.toString() ?? 'unknown';
        final displayLanguage = _mapLanguage(language);

        final deviceSnapshot = await _deviceRef.get();
        final source = deviceSnapshot.value?.toString() ?? 'unknown';

        final modelSnapshot = await _modelRef.get();
        final modelname = modelSnapshot.value?.toString() ?? 'unknown';

        if (source == 'User: $username') {
          if (kDebugMode) {
            debugPrint('Bỏ qua entry từ current user: $source');
          }
          return;
        }

        String trimmedData = data!;
        if (trimmedData.length > _maxNoteLength) {
          trimmedData = '${trimmedData.substring(0, _maxNoteLength - 3)}...';
          if (kDebugMode) {
            debugPrint(
              'Ghi chú quá dài (${data.length} ký tự), đã cắt xuống còn $_maxNoteLength ký tự.',
            );
          }
        }
        if (_isRecentlyDeletedContent(
          trimmedData,
          source,
          displayLanguage,
          modelname,
        )) {
          if (kDebugMode) {
            debugPrint('Bỏ qua do trùng với nội dung vừa bị xóa.');
          }
          return;
        }

        final isDuplicate =
            _noteEntries.isNotEmpty &&
            _noteEntries.last.data == trimmedData &&
            _noteEntries.last.source == source &&
            _noteEntries.last.language == displayLanguage &&
            _noteEntries.last.modelname == modelname;

        if (isDuplicate) {
          if (kDebugMode) {
            debugPrint('Bỏ qua do trùng lặp nội dung với entry trước đó.');
          }
          return;
        }

        final translatedText = await _translateText(
          trimmedData,
          displayLanguage,
        );

        final langCode = _selectedTargetLanguage;
        final flagAndLang = _availableLanguages[langCode] ?? langCode;

        final noteEntry = NoteEntry(
          source: source,
          language: displayLanguage,
          data: trimmedData,
          timestamp: DateTime.now(),
          modelname: modelname,
          flagAndLang: flagAndLang,
          translatedText: translatedText,
        );

        // Add to Firestore
        await _appendNoteToFirestore(
          trimmedData,
          source: source,
          language: displayLanguage,
          timestamp: noteEntry.timestamp,
          modelname: modelname,
          translatedText: translatedText,
          translatedLanguage: flagAndLang,
        );

        // Update UI
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
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Lỗi khi xử lý Realtime Database event: $e');
        }
      }
    });
  }

  void startListeningFromUpload() {
    debugPrint("Nhận được thông báo từ upload - listener đã sẵn sàng");
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
            'Nội dung quá dài (${content.length} ký tự), đã rút gọn còn $_maxNoteLength ký tự.',
          );
        }
      }

      // Translate the content
      final translatedText = await _translateText(content, displayLanguage);

      final langCode = _selectedTargetLanguage;
      final flagAndLang = _availableLanguages[langCode] ?? langCode;

      final noteEntry = NoteEntry(
        source: 'User: $username (me)',
        language: displayLanguage,
        data: content,
        timestamp: DateTime.now(),
        modelname: namemodel!,
        translatedText: translatedText,
        flagAndLang: flagAndLang,
      );

      await _appendNoteToFirestore(
        content,
        source: 'User: $username (me)',
        language: displayLanguage,
        timestamp: noteEntry.timestamp,
        modelname: namemodel,
        translatedText: translatedText,
        translatedLanguage: flagAndLang,
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
    String? translatedText,
    String? translatedLanguage,
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

        final documentData = {
          'text': trimmedEntry,
          'language': language ?? '',
          'source': source,
          'isUser': source.contains('User'),
          'timestamp': Timestamp.fromDate(timestamp),
          'model': modelname,
        };

        if (translatedText != null && translatedText.isNotEmpty) {
          documentData['translatedText'] = translatedText;
        }

        await docRef.add(documentData);

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
      "vi": "🇻🇳 Tiếng Việt",
      "en": "🇬🇧 Tiếng Anh",
      "en-US": "🇺🇸 Tiếng Anh Mỹ",
      "en-GB": "🇬🇧 Tiếng Anh Anh",
      "ja": "🇯🇵 Tiếng Nhật",
      "ko": "🇰🇷 Tiếng Hàn",
      "zh": "🇨🇳 Tiếng Trung",
      "zh-TW": "🇹🇼 Tiếng Trung Phồn thể",
      "fr": "🇫🇷 Tiếng Pháp",
      "de": "🇩🇪 Tiếng Đức",
      "es": "🇪🇸 Tiếng Tây Ban Nha",
      "pt": "🇵🇹 Tiếng Bồ Đào Nha",
      "pt-BR": "🇧🇷 Tiếng Bồ Đào Nha (Brazil)",
      "it": "🇮🇹 Tiếng Ý",
      "nl": "🇳🇱 Tiếng Hà Lan",
      "ru": "🇷🇺 Tiếng Nga",
      "pl": "🇵🇱 Tiếng Ba Lan",
      "tr": "🇹🇷 Tiếng Thổ Nhĩ Kỳ",
      "sv": "🇸🇪 Tiếng Thụy Điển",
      "fi": "🇫🇮 Tiếng Phần Lan",
      "no": "🇳🇴 Tiếng Na Uy",
      "da": "🇩🇰 Tiếng Đan Mạch",
      "cs": "🇨🇿 Tiếng Séc",
      "hu": "🇭🇺 Tiếng Hungary",
      "ro": "🇷🇴 Tiếng Romania",
      "th": "🇹🇭 Tiếng Thái",
      "id": "🇮🇩 Tiếng Indonesia",
      "ms": "🇲🇾 Tiếng Malaysia",
      "hi": "🇮🇳 Tiếng Hindi",
      "bn": "🇧🇩 Tiếng Bengal",
      "uk": "🇺🇦 Tiếng Ukraina",
      "he": "🇮🇱 Tiếng Do Thái",
      "ar": "🇸🇦 Tiếng Ả Rập",
    };
    return languageMap[language.toLowerCase().trim()] ?? '🌐 Không xác định';
  }

  bool _isRecentlyDeletedContent(
    String content,
    String source,
    String language,
    String model,
  ) {
    if (_recentlyDeletedContent == null || _deletionTime == null) {
      return false;
    }

    final now = DateTime.now();
    final timeSinceDeletion = now.difference(_deletionTime!);

    if (timeSinceDeletion.inSeconds > _deletionIgnoreDurationSeconds) {
      _clearRecentlyDeletedData();
      return false;
    }

    return _recentlyDeletedContent == content &&
        _recentlyDeletedSource == source &&
        _recentlyDeletedLanguage == language &&
        _recentlyDeletedModel == model;
  }

  void _storeRecentlyDeletedContent(NoteEntry deletedNote) {
    _recentlyDeletedContent = deletedNote.data;
    _recentlyDeletedSource = deletedNote.source;
    _recentlyDeletedLanguage = deletedNote.language;
    _recentlyDeletedModel = deletedNote.modelname;
    _deletionTime = DateTime.now();

    if (kDebugMode) {
      debugPrint(
        'Stored recently deleted content: ${deletedNote.data.substring(0, math.min(50, deletedNote.data.length))}...',
      );
    }
  }

  void _clearRecentlyDeletedData() {
    _recentlyDeletedContent = null;
    _recentlyDeletedSource = null;
    _recentlyDeletedLanguage = null;
    _recentlyDeletedModel = null;
    _deletionTime = null;

    if (kDebugMode) {
      debugPrint('Cleared recently deleted content data');
    }
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
    _clearRecentlyDeletedData();
  }

  Future<bool> _deleteNoteEntryByText(String fullText) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      // Parse the fullText to extract the actual data content
      final lines = fullText.trim().split('\n');
      if (lines.length < 2) return false;

      // Extract source and language from first line: [source] - [language]
      final firstLineRegex = RegExp(r'^\[(.*?)\] - \[(.*?)\]$');
      final firstLineMatch = firstLineRegex.firstMatch(lines[0].trim());
      if (firstLineMatch == null) return false;

      final source = firstLineMatch.group(1)?.trim();
      final language = firstLineMatch.group(2)?.trim();

      // Extract actual content from the remaining lines
      String actualData = '';
      bool foundContent = false;

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();

        // Skip translation lines that start with 🌐
        if (line.startsWith('🌐 Dịch:')) continue;

        // Parse time and content line: [HH:MM:SS][Model: modelname]: content
        final timeContentRegex = RegExp(
          r'^\[(\d{2}:\d{2}:\d{2})\](?:\[Model:\s*(.*?)\])?\s*:\s*(.*)$',
        );
        final timeContentMatch = timeContentRegex.firstMatch(line);

        if (timeContentMatch != null) {
          actualData = timeContentMatch.group(3)?.trim() ?? '';
          foundContent = true;
          break;
        }
      }

      if (!foundContent || actualData.isEmpty) {
        if (kDebugMode) {
          debugPrint('Could not extract actual data from: $fullText');
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint(
          'Attempting to delete: source=$source, language=$language, data=$actualData',
        );
      }

      final historyCollection = FirebaseFirestore.instance
          .collection("User_Information")
          .doc(uid)
          .collection("Content_History");

      QuerySnapshot snapshot =
          await historyCollection
              .where("text", isEqualTo: actualData)
              .where("language", isEqualTo: language)
              .where("source", isEqualTo: source)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        snapshot =
            await historyCollection
                .where("text", isEqualTo: actualData)
                .where("language", isEqualTo: language)
                .limit(1)
                .get();
      }

      if (snapshot.docs.isEmpty) {
        snapshot =
            await historyCollection
                .where("text", isEqualTo: actualData)
                .limit(1)
                .get();
      }

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
        if (kDebugMode) {
          debugPrint('Successfully deleted document');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('No matching document found in Firestore');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting note: $e');
      }
      return false;
    }
  }

  void _handleDelete(BuildContext context, String fullText) async {
    try {
      NoteEntry? noteToDelete;
      for (final note in _noteEntries) {
        if (note.toString().trim() == fullText.trim()) {
          noteToDelete = note;
          break;
        }
      }
      if (noteToDelete == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không tìm thấy ghi chú để xóa"),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
        return;
      }
      final deleted = await _deleteNoteEntryByText(fullText);
      if (deleted) {
        _storeRecentlyDeletedContent(noteToDelete);

        setState(() {
          _noteEntries.removeWhere(
            (note) => note.toString().trim() == fullText.trim(),
          );
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Xóa thành công"),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 2000),
          ),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Không thể xóa ghi chú"),
            backgroundColor: Colors.red,
            duration: Duration(milliseconds: 2000),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi khi xóa: $e"), backgroundColor: Colors.red),
      );

      if (kDebugMode) {
        debugPrint('Error in _handleDelete: $e');
      }
    }
  }

  List<TextSpan> _buildStyledNoteTextSpans(String text) {
    final lines = text.trim().split('\n');
    List<TextSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final metaRegex = RegExp(r'^\[(.*?)\] - \[(.*?)\]$');
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
                  fontSize: 14,
                ),
              ),
              TextSpan(
                text: '[$language]',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
        continue;
      }
      final modelTimeRegex = RegExp(
        r'^\[(\d{2}:\d{2}:\d{2})\]\s*\[Model:\s*(.*?)\]\s*:\s*(.*)$',
      );
      if (modelTimeRegex.hasMatch(line)) {
        final match = modelTimeRegex.firstMatch(line)!;
        final time = match.group(1)!;
        final model = match.group(2)!;
        final content = match.group(3)!.trim();

        spans.add(const TextSpan(text: '\n'));
        spans.add(
          TextSpan(
            children: [
              TextSpan(
                text: '[$time] ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 13,
                ),
              ),
              TextSpan(
                text: '[Model: $model] ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 13,
                ),
              ),
              const TextSpan(
                text: ': ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: content,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
              ),
            ],
          ),
        );
        continue;
      }

      final translationRegex = RegExp(r'^🌐\s*Dịch sang\s*(.*?)\s*:\s*(.*)$');
      final match = translationRegex.firstMatch(line);
      if (match != null) {
        final label = match.group(1)?.trim() ?? '';
        final translatedText = match.group(2)?.trim() ?? '';
        if (translatedText.isNotEmpty) {
          spans.add(const TextSpan(text: '\n'));
          spans.add(
            TextSpan(
              children: [
                const TextSpan(
                  text: '🌐 Dịch sang ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: translatedText,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }
        continue;
      }
      spans.add(
        TextSpan(
          text: '\n$line',
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
      );
    }
    return spans;
  }

  void _showChatOptionsDialog(BuildContext context, String fullText) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Tùy chọn"),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                child: SelectableText.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                    children: _buildStyledNoteTextSpans(fullText),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Hủy"),
              ),
              TextButton(
                onPressed: () {
                  final cleanText = _extractCleanText(fullText);
                  Clipboard.setData(ClipboardData(text: cleanText));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Đã sao chép nội dung"),
                      backgroundColor: Colors.green,
                      duration: Duration(milliseconds: 2000),
                    ),
                  );
                },
                child: const Text("Sao chép"),
              ),
              TextButton(
                onPressed: () => _handleDelete(context, fullText),
                child: const Text("Xóa", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  String _extractCleanText(String fullText) {
    final lines = fullText.trim().split('\n');
    final StringBuffer cleanText = StringBuffer();

    for (final line in lines) {
      final lineTrimmed = line.trim();
      if (RegExp(r'^\[(.*?)\] - \[(.*?)\]$').hasMatch(lineTrimmed)) {
        continue;
      }
      final timeContentRegex = RegExp(
        r'^\[(\d{2}:\d{2}:\d{2})\](?:\s*\[Model:\s*(.*?)\])?\s*:\s*(.*)$',
      );
      final match = timeContentRegex.firstMatch(lineTrimmed);
      if (match != null) {
        final content = match.group(3)?.trim() ?? '';
        if (content.isNotEmpty) {
          if (cleanText.isNotEmpty) cleanText.write('\n\n');
          cleanText.write(content);
        }
        continue;
      }

      if (lineTrimmed.startsWith('🌐 Dịch:')) {
        final translatedText = lineTrimmed.substring(8).trim();
        if (translatedText.isNotEmpty) {
          cleanText.write('\n(Dịch: $translatedText)');
        }
        continue;
      }
    }

    return cleanText.toString().trim();
  }

  Widget _buildLanguageDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.translate, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Dịch sang: ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedTargetLanguage,
              isExpanded: true,
              underline: Container(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              items:
                  _availableLanguages.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
              onChanged: (String? newValue) async {
                if (newValue != null && newValue != _selectedTargetLanguage) {
                  setState(() {
                    _selectedTargetLanguage = newValue;
                    _translationCache.clear();
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('selectedLanguage', newValue);
                  _translateMissingEntries();
                }
              }
            ),
          ),
        ],
      ),
    );
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
          SizedBox(
            width: width,
            height: height * 0.56,
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
            child: Column(
              children: [
                _buildLanguageDropdown(),
                _buildContentField(width, height),
              ],
            ),
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
