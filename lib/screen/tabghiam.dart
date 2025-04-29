// ignore_for_file: unused_field

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

class GhiAmTab extends StatefulWidget {
  const GhiAmTab({super.key});

  @override
  State<GhiAmTab> createState() => _GhiAmTabState();
}

class _GhiAmTabState extends State<GhiAmTab> {
  final record = AudioRecorder();
  final player = AudioPlayer();
  final List<String> _recordedFiles = [];

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
  }

  Future<void> startRecord() async {
    final hasPermission = await record.hasPermission();
    if (!hasPermission) {
      throw 'Chưa cấp quyền micro';
    }

    final dir = await getApplicationDocumentsDirectory();
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String filePath = '${dir.path}/audio_$timestamp.wav';

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
    }
  }

  Future pauseRecord() async {
    await record.pause();
    _timer?.cancel();
    setState(() {
      isPaused = true;
    });
  }

  Future resumeRecord() async {
    await record.resume();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _currentDuration += const Duration(seconds: 1);
      });
    });
    setState(() {
      isPaused = false;
    });
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

      player.onPlayerComplete.listen((event) {
        setState(() {
          isPlaying = false;
          currentlyPlayingPath = null;
        });
      });
    }
  }

  Future uploadFile(String path) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://your.api/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', path));
      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Upload thành công!')));
      } else {
        throw 'Lỗi upload: ${response.statusCode}';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload thất bại: $e')));
    }
  }

  Future<void> loadExistingFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.wav'))
        .toList();

    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

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
                          icon: const Icon(Icons.cloud_upload),
                          onPressed: () => uploadFile(path),
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
                            builder: (_) => AlertDialog(
                              title: const Text('Xóa file?'),
                              content: Text(
                                'Bạn có chắc muốn xóa "$name"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Không'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await deleteFile(path);
                          }
                        },
                      )
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
