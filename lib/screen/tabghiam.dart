import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class GhiAmTab extends StatefulWidget {
  final ValueNotifier<String?> recognizedLanguage;
  final ValueNotifier<String?> recognizedContent;
  final VoidCallback? onUploadSuccess;
  const GhiAmTab({
    super.key,
    required this.recognizedLanguage,
    required this.recognizedContent,
    this.onUploadSuccess,
  });

  @override
  State<GhiAmTab> createState() => _GhiAmTabState();
}

class _GhiAmTabState extends State<GhiAmTab> {
  final record = AudioRecorder();
  final player = AudioPlayer();
  final List<String> _recordedFiles = [];
  Set<String> uploadingFiles = {};
  // ignore: unused_field
  String? _currentRecordingPath;
  bool isRecording = false;
  bool isPaused = false;
  bool isPlaying = false;
  String? currentlyPlayingPath;
  Timer? _timer;
  Duration _currentDuration = Duration.zero;

  @override
  void dispose() {
    player.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadExistingFiles();
    player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          isPlaying = false;
          currentlyPlayingPath = null;
        });
      }
    });
  }

  String sanitizeUsername(String username) {
    return username.replaceAll(RegExp(r'[\/:*?"<>|\\]'), '_');
  }

  Future<void> startRecord() async {
    final hasPermission = await record.hasPermission();
    if (!hasPermission) {
      throw 'Chưa cấp quyền micro';
    }

    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      throw 'Chưa đăng nhập';
    }
    if (kDebugMode) {
      print('UID: $uid');
    }
    final snapshot =
        await FirebaseFirestore.instance
            .collection('User_Information')
            .doc(uid)
            .get();
    if (!snapshot.exists) {
      throw 'Dữ liệu người dùng không tồn tại.';
    }
    final username = snapshot.data()?['Username'];

    if (username == null || username.isEmpty) {
      throw 'Không tìm thấy tên người dùng trong Firestore';
    }
    final sanitizedUsername = sanitizeUsername(username);

    // Lưu file theo username
    final dir = await getApplicationDocumentsDirectory();
    final userDir = Directory('${dir.path}/$sanitizedUsername');

    try {
      if (!await userDir.exists()) {
        await userDir.create(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Lỗi tạo thư mục: $e');
      }
      throw 'Không thể tạo thư mục lưu file ghi âm.';
    }
    final now = DateTime.now();
    final formattedTime = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
    final filePath = '${userDir.path}/audio_$formattedTime.wav';
    if (await record.isRecording()) {
      await record.stop();
    }
    await record.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    setState(() {
      _currentRecordingPath = filePath;
      isRecording = true;
      isPaused = false;
      _currentDuration = Duration.zero;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentDuration += const Duration(seconds: 1);
      });
    });
  }

  Future stopRecord() async {
    final path = await record.stop();
    _timer?.cancel();

    if (kDebugMode) {
      print('Đường dẫn file ghi âm: $path');
    }

    if (path != null) {
      if (mounted) {
        setState(() {
          _recordedFiles.insert(0, path);
          if (_recordedFiles.length > 10) {
            final removed = _recordedFiles.removeLast();
            File(removed).delete();
          }
          isRecording = false;
          isPaused = false;
          _currentDuration = Duration.zero;
        });
      }
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        if (kDebugMode) {
          print('Dung lượng file: $size bytes');
        }
      } else {
        if (kDebugMode) {
          print('❌ Không tìm thấy file tại $path');
        }
      }
      await loadExistingFiles();
    }
  }

  Future pauseRecord() async {
    await record.pause();
    _timer?.cancel();
    if (mounted) {
      setState(() {
        isPaused = true;
      });
    }
  }

  Future resumeRecord() async {
    await record.resume();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentDuration += const Duration(seconds: 1);
        });
      } else {
        _timer?.cancel();
      }
    });
    if (mounted) {
      setState(() {
        isPaused = false;
      });
    }
  }

  Future playAudio(String path) async {
    if (isPlaying && currentlyPlayingPath == path) {
      await player.stop();
      setState(() {
        isPlaying = false;
        currentlyPlayingPath = null;
      });
    } else {
      await player.stop();
      await player.play(DeviceFileSource(path));
      setState(() {
        isPlaying = true;
        currentlyPlayingPath = path;
      });
    }
  }

  Future<void> uploadFile(String path) async {
    setState(() {
      uploadingFiles.add(path);
      if (kDebugMode) print("⬆️ Bắt đầu upload: $uploadingFiles");
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://34.136.208.29:8080/detect-language/'),
      );
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          path,
          contentType: MediaType('audio', 'wav'),
        ),
      );
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(responseBody);
        if (kDebugMode) print('✅ Server response JSON: $jsonData');

        if (jsonData['language'] != null && jsonData['text'] != null) {
          if (mounted) {
            widget.recognizedLanguage.value = jsonData['language'] as String;
            widget.recognizedContent.value = jsonData['text'] as String;
            widget.onUploadSuccess?.call();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upload thành công!')),
            );
          }
        } else {
          if (kDebugMode) {
            print("⚠️ Dữ liệu thiếu trường 'language' hoặc 'text': $jsonData");
          }
        }
      } else {
        throw 'Lỗi upload: ${response.statusCode}';
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("❌ Exception khi upload: $e");
      }
      if (kDebugMode) {
        print("📌 Stacktrace: $stackTrace");
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload thất bại: $e')),
        );
        widget.recognizedLanguage.value = null;
      }
    } finally {
      if (mounted) {
        setState(() {
          uploadingFiles.remove(path);
          if (kDebugMode) {
            print("✅ Kết thúc upload: $uploadingFiles");
          }
        });
      }
    }
  }

  Future<void> loadExistingFiles() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      if (kDebugMode) {
        print('Người dùng chưa đăng nhập');
      }
      return;
    }
    // Lấy username từ Firestore
    final snapshot =
        await FirebaseFirestore.instance
            .collection('User_Information')
            .doc(uid)
            .get();
    final username = snapshot.data()?['Username'] ?? 'unknown';
    final dir = await getApplicationDocumentsDirectory();
    final sanitizedUsername = sanitizeUsername(username);
    final userDir = Directory('${dir.path}/$sanitizedUsername');

    if (!await userDir.exists()) {
      if (kDebugMode) {
        print('Thư mục người dùng không tồn tại: ${userDir.path}');
      }
      setState(() {
        _recordedFiles.clear();
      });
      return;
    }
    final files =
        userDir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.wav'))
            .toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    if (!mounted) return;
    setState(() {
      _recordedFiles.clear();
      _recordedFiles.addAll(files.map((f) => f.path));
    });
  }

  Future deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
    setState(() {
      _recordedFiles.remove(path);
    });
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              formatDuration(_currentDuration),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed:
                      (!isRecording && !isPlaying)
                          ? startRecord
                          : (isRecording
                              ? (isPaused ? resumeRecord : pauseRecord)
                              : null),
                  child: Icon(
                    isRecording
                        ? (isPaused ? Icons.play_arrow : Icons.pause)
                        : Icons.mic,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 20),
                if (isRecording)
                  ElevatedButton(
                    onPressed: stopRecord,
                    child: const Icon(Icons.stop, size: 36),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              'Danh sách file ghi âm:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _recordedFiles.length,
                itemBuilder: (context, index) {
                  final path = _recordedFiles[index];
                  final name = path.split('/').last;
                  return ListTile(
                    title: Text(name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlaying && currentlyPlayingPath == path
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          onPressed: () => playAudio(path),
                        ),
                        IconButton(
                          icon: uploadingFiles.contains(path)
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          onPressed: uploadingFiles.contains(path) ? null : () => uploadFile(path),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            // Nếu đang phát file, dừng phát âm thanh trước khi xóa
                            if (isPlaying && currentlyPlayingPath == path) {
                              await player.stop();
                              setState(() {
                                isPlaying = false;
                                currentlyPlayingPath = null;
                              });
                            }
                            // Xác nhận và xóa file nếu người dùng đồng ý
                            final confirm = await showDialog(
                              context: context,
                              builder:
                                  (_) => AlertDialog(
                                    title: const Text('Xóa file?'),
                                    content: Text(
                                      'Bạn có chắc muốn xóa "$name"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, false),
                                        child: const Text('Không'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: const Text('Xóa'),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirm == true) {
                              await deleteFile(path);
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
