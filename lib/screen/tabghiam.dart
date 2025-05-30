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
  final ValueNotifier<String?> recognizedModel;
  final VoidCallback? onUploadSuccess;
  const GhiAmTab({
    super.key,
    required this.recognizedLanguage,
    required this.recognizedContent,
    required this.recognizedModel,
    this.onUploadSuccess,
  });

  @override
  State<GhiAmTab> createState() => _GhiAmTabState();
}

class _GhiAmTabState extends State<GhiAmTab>
    with AutomaticKeepAliveClientMixin {
  final record = AudioRecorder();
  final player = AudioPlayer();
  final List<String> _recordedFiles = [];
  Set<String> uploadingFiles = {};
  // ignore: unused_field
  String? _currentRecordingPath;
  bool isRecording = false;
  bool isPaused = false;
  bool isPlaying = false;
  bool isPlaybackPaused = false;
  String? currentlyPlayingPath;
  Timer? _timer;
  Duration _currentDuration = Duration.zero;
  Duration _currentPlaybackPosition = Duration.zero;
  final Map<String, Duration> _audioDurations = {}; // Cache for audio durations

  // Custom Colors - You can change these to your preferred colors
  static const Color recordButtonColor = Color(0xFF4CAF50); // Green
  static const Color pauseButtonColor = Color(0xFFFF9800); // Orange
  static const Color stopButtonColor = Color(0xFFF44336); // Red
  static const Color playButtonColor = Color(0xFF2196F3); // Blue
  static const Color uploadButtonColor = Color(0xFF9C27B0); // Purple
  static const Color deleteButtonColor = Color(0xFFF44336); // Red

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

    // Listen to player completion
    player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          isPlaying = false;
          isPlaybackPaused = false;
          currentlyPlayingPath = null;
          _currentPlaybackPosition = Duration.zero;
        });
      }
    });

    // Listen to position changes - but throttle updates to reduce flickering
    Duration lastPosition = Duration.zero;
    player.onPositionChanged.listen((position) {
      // Only update if position changed significantly (reduce flickering)
      if (mounted &&
          isPlaying &&
          !isPlaybackPaused &&
          (position.inSeconds != lastPosition.inSeconds)) {
        lastPosition = position;
        setState(() {
          _currentPlaybackPosition = position;
        });
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  String sanitizeUsername(String username) {
    return username.replaceAll(RegExp(r'[\/:*?"<>|\\]'), '_');
  }

  Future<void> startRecord() async {
    // Stop any active audio playback before starting recording
    if (isPlaying) {
      await player.stop();
      setState(() {
        isPlaying = false;
        isPlaybackPaused = false;
        currentlyPlayingPath = null;
        _currentPlaybackPosition = Duration.zero;
      });
    }

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
    final formattedTime = DateFormat('dd-MM-yyyy_HHmmss').format(now);
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
      if (mounted) {
        setState(() {
          _currentDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  Future stopRecord() async {
    if (_currentDuration.inSeconds < 5) {
      if (kDebugMode) {
        print('Ghi âm quá ngắn (< 5s), không dừng.');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ghi âm phải dài ít nhất 5 giây')));
      return;
    }

    final path = await record.stop();
    _timer?.cancel();

    if (kDebugMode) {
      print('Đường dẫn file ghi âm: $path');
    }

    if (path != null) {
      // Pre-load duration to avoid flickering later
      await _preloadAudioDuration(path);

      if (mounted) {
        setState(() {
          _recordedFiles.insert(0, path);
          if (_recordedFiles.length > 50) {
            final removed = _recordedFiles.removeLast();
            File(removed).delete();
            _audioDurations.remove(removed); // Clean cache
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
          print('Không tìm thấy file tại $path');
        }
      }
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
      // If currently playing this file, pause it
      if (!isPlaybackPaused) {
        await player.pause();
        setState(() {
          isPlaybackPaused = true;
        });
      } else {
        // If paused, resume playback
        await player.resume();
        setState(() {
          isPlaybackPaused = false;
        });
      }
    } else {
      // Stop any current playback and start new one
      await player.stop();
      await player.play(DeviceFileSource(path));
      setState(() {
        isPlaying = true;
        isPlaybackPaused = false;
        currentlyPlayingPath = path;
        _currentPlaybackPosition = Duration.zero;
      });
    }
  }

  Future pauseAudio() async {
    await player.pause();
    setState(() {
      isPaused = true;
      isPlaying = false;
    });
  }

  Future resumeAudio() async {
    await player.resume();
    setState(() {
      isPaused = false;
      isPlaying = true;
    });
  }

  Future seekAudio(Duration newPosition) async {
    await player.seek(newPosition);
    setState(() {
      _currentPlaybackPosition = newPosition;
    });
  }

  Future<void> uploadFile(String path) async {
    setState(() {
      uploadingFiles.add(path);
      if (kDebugMode) print("Bắt đầu upload: $uploadingFiles");
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://35.239.125.114:30090/detect-language/'),
      );

      request.headers.addAll({
        'Connection': 'keep-alive',
        'Accept': 'application/json',
      });

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
        if (kDebugMode) print('Server response JSON: $jsonData');

        if (jsonData['language'] != null && jsonData['text'] != null) {
          if (mounted) {
            widget.recognizedLanguage.value = jsonData['language'] as String;
            widget.recognizedContent.value = jsonData['text'] as String;
            widget.recognizedModel.value = jsonData['model'] as String;
            widget.onUploadSuccess?.call();

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Upload thành công!')));
          }
        } else {
          if (kDebugMode) {
            print("Dữ liệu thiếu trường 'language' hoặc 'text': $jsonData");
          }
        }
      } else {
        throw 'Lỗi upload: ${response.statusCode}';
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("Exception khi upload: $e");
        print("Stacktrace: $stackTrace");
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload thất bại: $e')));
        widget.recognizedLanguage.value = null;
      }
    } finally {
      if (mounted) {
        setState(() {
          uploadingFiles.remove(path);
          if (kDebugMode) {
            print("Kết thúc upload: $uploadingFiles");
          }
        });
      }
    }
  }

  // Pre-load audio duration to avoid flickering
  Future<void> _preloadAudioDuration(String path) async {
    if (_audioDurations.containsKey(path)) return;

    try {
      final tempPlayer = AudioPlayer();
      try {
        await tempPlayer.setSource(DeviceFileSource(path));
        final duration = await tempPlayer.getDuration();
        if (duration != null && duration.inMilliseconds > 0) {
          _audioDurations[path] = duration;
        }
      } finally {
        await tempPlayer.dispose();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error preloading duration for $path: $e');
      }
    }
  }

  Future<void> loadExistingFiles() async {
    _audioDurations.clear();
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

    // Pre-load durations for all files to avoid flickering
    for (String path in _recordedFiles) {
      await _preloadAudioDuration(path);
    }
    if (mounted) setState(() {}); // Refresh UI with loaded durations
  }

  Future deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
    setState(() {
      _recordedFiles.remove(path);
      _audioDurations.remove(path);
    });
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  Future<Duration> getAudioDuration(String path) async {
    if (_audioDurations.containsKey(path)) {
      return _audioDurations[path]!;
    }
    return Duration.zero; // Return zero immediately if not cached
  }

  // Optimized audio timeline widget that doesn't cause flickering
  Widget _buildAudioTimeline(String path) {
    // Get cached duration immediately - no async here
    final duration = _audioDurations[path] ?? Duration.zero;

    if (duration == Duration.zero || duration.inMilliseconds <= 0) {
      return const SizedBox(height: 10);
    }

    final isCurrentlyPlaying = isPlaying && currentlyPlayingPath == path;
    final progress =
        isCurrentlyPlaying && duration.inMilliseconds > 0
            ? (_currentPlaybackPosition.inMilliseconds /
                    duration.inMilliseconds)
                .clamp(0.0, 1.0)
            : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              formatDuration(
                isCurrentlyPlaying ? _currentPlaybackPosition : Duration.zero,
              ),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Spacer(),
            Text(
              formatDuration(duration),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: progress,
            onChanged:
                isCurrentlyPlaying
                    ? (value) {
                      final newPosition = Duration(
                        milliseconds: (value * duration.inMilliseconds).round(),
                      );
                      seekAudio(newPosition);
                    }
                    : null,
            activeColor:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
            inactiveColor: Colors.grey[300],
          ),
        ),
      ],
    );
  }

  void clearAudioDurationCache() {
    _audioDurations.clear();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isRecording
                            ? (isPaused ? recordButtonColor : pauseButtonColor)
                            : recordButtonColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(60, 40),
                    padding: const EdgeInsets.all(8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 3,
                  ),
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
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                if (isRecording)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: stopButtonColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(60, 40),
                      padding: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 3,
                    ),
                    onPressed: stopRecord,
                    child: const Icon(Icons.stop, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const Text(
              'Danh sách file ghi âm (tối đa 50)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child:
                  _recordedFiles.isEmpty
                      ? const Center(
                        child: Text(
                          'Chưa có file ghi âm nào',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        // Add key to prevent unnecessary rebuilds
                        key: const PageStorageKey('recordedList'),
                        padding: EdgeInsets.zero,
                        itemCount: _recordedFiles.length,
                        itemBuilder: (context, index) {
                          final path = _recordedFiles[index];
                          final name = path.split('/').last;
                          final isCurrentlyPlaying =
                              isPlaying && currentlyPlayingPath == path;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            style: IconButton.styleFrom(
                                              backgroundColor: playButtonColor
                                                  .withOpacity(0.1),
                                              foregroundColor: playButtonColor,
                                            ),
                                            icon: Icon(
                                              isCurrentlyPlaying
                                                  ? (isPlaybackPaused
                                                      ? Icons.play_arrow
                                                      : Icons.pause)
                                                  : Icons.play_arrow,
                                            ),
                                            onPressed: () => playAudio(path),
                                          ),
                                          IconButton(
                                            style: IconButton.styleFrom(
                                              backgroundColor: uploadButtonColor
                                                  .withOpacity(0.1),
                                              foregroundColor:
                                                  uploadButtonColor,
                                            ),
                                            icon:
                                                uploadingFiles.contains(path)
                                                    ? SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              uploadButtonColor,
                                                            ),
                                                      ),
                                                    )
                                                    : const Icon(
                                                      Icons.cloud_upload,
                                                    ),
                                            onPressed:
                                                uploadingFiles.contains(path)
                                                    ? null
                                                    : () => uploadFile(path),
                                          ),
                                          IconButton(
                                            style: IconButton.styleFrom(
                                              backgroundColor: deleteButtonColor
                                                  .withOpacity(0.1),
                                              foregroundColor:
                                                  deleteButtonColor,
                                            ),
                                            icon: const Icon(Icons.delete),
                                            onPressed: () async {
                                              // Nếu đang phát file, dừng phát âm thanh trước khi xóa
                                              if (isPlaying &&
                                                  currentlyPlayingPath ==
                                                      path) {
                                                await player.stop();
                                                setState(() {
                                                  isPlaying = false;
                                                  isPlaybackPaused = false;
                                                  currentlyPlayingPath = null;
                                                  _currentPlaybackPosition =
                                                      Duration.zero;
                                                });
                                              }
                                              // Xác nhận và xóa file nếu người dùng đồng ý
                                              final confirm = await showDialog<
                                                bool
                                              >(
                                                context: context,
                                                builder:
                                                    (context) => AlertDialog(
                                                      backgroundColor:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.surface,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      title: Text(
                                                        'Xóa file?',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      content: Text(
                                                        'Bạn có chắc muốn xóa "$name"?',
                                                        style: TextStyle(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          style: TextButton.styleFrom(
                                                            foregroundColor:
                                                                Colors.grey,
                                                            backgroundColor:
                                                                Colors.black
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      20,
                                                                  vertical: 10,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                          ),
                                                          onPressed:
                                                              () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    false,
                                                                  ),
                                                          child: const Text(
                                                            'Không',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          style: TextButton.styleFrom(
                                                            foregroundColor:
                                                                Colors.white,
                                                            backgroundColor:
                                                                deleteButtonColor,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      20,
                                                                  vertical: 10,
                                                                ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                          ),
                                                          onPressed:
                                                              () =>
                                                                  Navigator.pop(
                                                                    context,
                                                                    true,
                                                                  ),
                                                          child: const Text(
                                                            'Xóa',
                                                          ),
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
                                    ],
                                  ),
                                  _buildAudioTimeline(path),
                                ],
                              ),
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
