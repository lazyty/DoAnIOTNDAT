// ignore_for_file: unused_field
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class GhiAmFlutterTab extends StatefulWidget {
  const GhiAmFlutterTab({super.key});

  @override
  State<GhiAmFlutterTab> createState() => _GhiAmFlutterTabState();
}

class _GhiAmFlutterTabState extends State<GhiAmFlutterTab> {
  final recorder = FlutterSoundRecorder();
  final player = FlutterSoundPlayer();
  final List<String> _recordedFiles = [];
  String? _currentRecordingPath;
  bool isRecording = false;
  bool isPaused = false;
  bool isPlaying = false;
  bool _isInitialized = false;
  String? currentlyPlayingPath;
  Duration _currentDuration = Duration.zero;
  Duration _pausedDuration = Duration.zero; // Thời gian đã dừng khi pause
  final Duration _totalDuration = Duration.zero;
  StreamSubscription<RecordingDisposition>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    initRecorder();
    initPlayer();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    recorder.closeRecorder();
    player.closePlayer();
    super.dispose();
  }

Future initRecorder() async {
    try {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw 'Chưa cấp quyền micro';
      }
      await recorder.openRecorder();
      recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
      _progressSubscription = recorder.onProgress?.listen((disposition) {
        if (isRecording && !isPaused) {
          setState(() {
            _currentDuration = disposition.duration.isNegative
                ? _pausedDuration
                : disposition.duration + _pausedDuration;
          });
        }
      });
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Lỗi khi khởi tạo recorder: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khởi tạo recorder: $e')),
      );
    }
  }

  Future initPlayer() async {
    try {
      await player.openPlayer();
    } catch (e) {
      debugPrint('Lỗi khi khởi tạo player: $e');
    }
  }

  Future startRecord() async {
    try {
      if (!recorder.isRecording && recorder.isStopped) {
        final dir = await getApplicationDocumentsDirectory();
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String filePath = '${dir.path}/audio_$timestamp.aac';

        await recorder.startRecorder(
          toFile: filePath,
          codec: Codec.aacADTS,
        );

        setState(() {
          _currentRecordingPath = filePath;
          isRecording = true;
          isPaused = false;
          _currentDuration = Duration.zero;  // Reset time to 00:00
        });
      }
    } catch (e) {
      debugPrint('Lỗi khi startRecorder: $e');
    }
  }

  Future pauseRecording() async {
    await recorder.pauseRecorder();
    setState(() {
      isPaused = true;
      _pausedDuration = _currentDuration; // Lưu lại thời gian pause
    });
  }

  Future resumeRecording() async {
    await recorder.resumeRecorder();
    setState(() {
      isPaused = false;
    });
  }

  Future stopRecorder() async {
    final path = await recorder.stopRecorder();
    if (path != null) {
      final file = File(path);
      if (kDebugMode) {
        print('File size: ${await file.length()} bytes');
      }
      setState(() {
        _recordedFiles.add(path);
        if (_recordedFiles.length > 20) {
          final oldestFile = _recordedFiles.removeAt(0);
          File(oldestFile).delete(); // Delete oldest file from storage
        }
      });
    }

    setState(() {
      isRecording = false;
      isPaused = false;
      _currentRecordingPath = null;
      _currentDuration = Duration.zero; // Reset lại khi stop
      _pausedDuration = Duration.zero;
    });
  }

  Future playAudio(String filePath) async {
    if (isPlaying && currentlyPlayingPath == filePath) {
      await stopAudio();
    } else {
      if (isPlaying) {
        await stopAudio(); // Dừng file trước đó nếu đang phát
      }

      await player.startPlayer(
        fromURI: filePath,
        whenFinished: () {
          setState(() {
            isPlaying = false;
            currentlyPlayingPath = null;
          });
        },
      );
      setState(() {
        isPlaying = true;
        currentlyPlayingPath = filePath;
      });
    }
  }

  Future stopAudio() async {
    await player.stopPlayer();
    setState(() {
      isPlaying = false;
      currentlyPlayingPath = null;
    });
  }

  Future uploadFile(String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://your.api/upload'), // Replace with real URL
      );
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload thành công!')),
        );
      } else {
        throw 'Upload failed with status: ${response.statusCode}';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload thất bại: $e')),
      );
    }
  }

  Future deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
    setState(() {
      _recordedFiles.remove(filePath);
      if (_recordedFiles.length > 20) {
        _recordedFiles.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            StreamBuilder<RecordingDisposition>(
              stream: recorder.onProgress,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                      return const Text(
                        'Error in recording',
                        style: TextStyle(color: Colors.red, fontSize: 24),
                      );
                    }
                if (!snapshot.hasData && isRecording) {
                  return const CircularProgressIndicator();
                }
                String twoDigits(int n) => n.toString().padLeft(2, '0');
                final minutes = twoDigits(_currentDuration.inMinutes.remainder(60));
                final seconds = twoDigits(_currentDuration.inSeconds.remainder(60));

                return Text(
                  '$minutes:$seconds',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: !_isInitialized
                      ? null
                      : isRecording
                          ? (isPaused ? resumeRecording : pauseRecording)
                          : startRecord,
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
                    onPressed: stopRecorder,
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
                cacheExtent: 1000,
                itemBuilder: (context, index) {
                  final filePath = _recordedFiles[index];
                  final fileName = filePath.split('/').last;
                  return ListTile(
                    title: Text(fileName),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            isPlaying && currentlyPlayingPath == filePath
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          onPressed: () => playAudio(filePath),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cloud_upload),
                          onPressed: () => uploadFile(filePath),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final confirm = await showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: Text('Xóa file?'),
                                content: Text('Bạn có chắc muốn xóa "$fileName"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Không')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Xóa')),
                                ],
                              ),
                            );
                            if (confirm == true) deleteFile(filePath);
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
