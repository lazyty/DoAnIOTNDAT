import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'wave_form_painter.dart';
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

  static const int _maxNoteLength = 100000;

  late FlutterSoundRecorder _recorder;
  late FlutterSoundPlayer _player;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isPlaying = false;
  String? _recordedFilePath;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  // ignore: prefer_final_fields
  List<double> _decibels = [];

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

    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    _initRecorderAndPlayer();

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

  Future<void> _initRecorderAndPlayer() async {
    await _recorder.openRecorder();
    await _player.openPlayer();
  }
  @override
  void dispose() {
    _controller.dispose();
    _languageSub.cancel();
    _noteSub.cancel();
    _noteController.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/recorded.wav';
    await _recorder.startRecorder(toFile: path, codec: Codec.pcm16WAV);
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recordedFilePath = path;
    _startTimer();
    DateTime lastUpdate = DateTime.now();
    _recorder.onProgress!.listen((e) {
      if (e.decibels != null) {
        final now = DateTime.now();
        if (now.difference(lastUpdate).inMilliseconds > 100) {
          lastUpdate = now;
          setState(() {
            _decibels.add(e.decibels!);
            if (_decibels.length > 100) _decibels.removeAt(0);
          });
        }
      }
    });
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    // stopRecorder sẽ trả về đường dẫn file hoàn chỉnh
    final path = await _recorder.stopRecorder();
    _stopTimer();
    // debug: kiểm tra file đã có dữ liệu chưa
    final f = File(path!);
    if (kDebugMode) {
      print('▶ Recorded file: $path, exists=${f.existsSync()}, size=${f.lengthSync()} bytes');
    }

    setState(() {
      _recordedFilePath = path;
      _isRecording = false;
      _isPaused = false;
    });
  }


  Future<void> _pauseOrResume() async {
    if (_isPaused) {
      await _recorder.resumeRecorder();
      _startTimer();
    } else {
      await _recorder.pauseRecorder();
      _stopTimer();
    }
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _playRecording() async {
    if (_recordedFilePath == null || !File(_recordedFilePath!).existsSync()) {
      if (kDebugMode) print('⚠️ File không tồn tại');
      return;
    }

    try {
      await _player.stopPlayer();
      await _player.startPlayer(
        fromURI: _recordedFilePath!,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          setState(() => _isPlaying = false);
        },
      );
      setState(() => _isPlaying = true);
    } catch (e) {
      if (kDebugMode) print('⚠️ Playback error: $e');
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _uploadRecording() async {
    if (_recordedFilePath == null) return;
    final uri = Uri.parse(
      "http://iot-language-ai-wo9z6s-f672fe-143-192-88-121.traefik.me/detect-language/",
    );
    final req = http.MultipartRequest('POST', uri);
    req.files.add(
      await http.MultipartFile.fromPath(
        'file',
        _recordedFilePath!,
        contentType: MediaType('audio', 'wav'),
      ),
    );
    await req.send();
  }

  void _startTimer() {
    _timer?.cancel();
    _recordDuration = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
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
              _ngonNguHienTai!,
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
      child = const Center(child: Text("Không có dữ liệu.",style: TextStyle(color: Colors.red),));
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
            "\u23F3 Đang chờ dữ liệu từ server...",
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
                "\ud83d\udcdd Nội dung",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red),
                tooltip: "Xoá toàn bộ ghi chú",
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text("Xác nhận xoá"),
                          content: const Text(
                            "Bạn có chắc muốn xoá toàn bộ nội dung ghi chú không?",
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

  Widget _buildGhiAmTab() {
    final durationStr = "${_recordDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}";
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("⏱ $durationStr"),
          const SizedBox(height: 12),
          if (_isRecording)
            SizedBox(
              height: 80,
              width: double.infinity,
              child: CustomPaint(painter: WaveformPainter(_decibels)),
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            children: [
              ElevatedButton.icon(
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? "Dừng" : "Ghi âm"),
                onPressed: _isRecording ? _stopRecording : _startRecording,
              ),
              if (_isRecording)
                ElevatedButton.icon(
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(_isPaused ? "Tiếp tục" : "Tạm dừng"),
                  onPressed: _pauseOrResume,
                ),
              ElevatedButton.icon(
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlaying ? "Dừng phát" : "Phát lại"),
                onPressed: () async {
                  if (_isPlaying) {
                    await _player.stopPlayer();
                    setState(() => _isPlaying = false);
                  } else {
                    await _playRecording();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_upload),
            label: const Text("Gửi lên API"),
            onPressed: _uploadRecording,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                Navigator.pushNamedAndRemoveUntil(context,'/dangnhap',(route) => false,);
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.notes), text: "Ghi chú"),
              Tab(icon: Icon(Icons.mic), text: "Ghi âm"),
            ],
          ),
        ),
        body: SafeArea(
          top: true,
          bottom: true,
          child: TabBarView(
            children: [
              _buildNhandienTab(screenWidth, screenHeight),
              _buildGhiAmTab(),
            ],
          ),
        ),
      ),
    );
  }
}
