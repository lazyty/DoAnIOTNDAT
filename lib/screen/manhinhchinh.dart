import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'tabnhandien.dart';
import 'tabghiam.dart';
import '../components/background.dart'; // thêm để dùng nền sáng

class ManHinhChinhScreen extends StatefulWidget {

  const ManHinhChinhScreen({super.key});

  @override
  State<ManHinhChinhScreen> createState() => _ManHinhChinhScreenState();
}

class _ManHinhChinhScreenState extends State<ManHinhChinhScreen> {
  bool isDarkMode = false; // Mặc định chế độ tối
  final ValueNotifier<String?> recognizedLanguage = ValueNotifier<String?>(null);
  final ValueNotifier<String?> recognizedContent = ValueNotifier<String?>(null);
  final GlobalKey<NhanDienTabState> _nhanDienTabKey = GlobalKey<NhanDienTabState>();

  @override
  void dispose() {
    recognizedLanguage.dispose();
    recognizedContent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    final content = Column(
      children: [
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "IOTWSRA",
                  style: TextStyle(
                    color: Color(0xFF2661FA),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Nút chuyển chế độ sáng/tối
              IconButton(
                icon: Icon(
                  isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  setState(() {
                    isDarkMode = !isDarkMode;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const TabBar(
          indicatorColor: Color(0xFF2661FA),
          labelColor: Color(0xFF2661FA),
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(icon: Icon(Icons.language), text: "Nhận diện"),
            Tab(icon: Icon(Icons.mic), text: "Ghi âm"),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              NhanDienTab(key: _nhanDienTabKey,recognizedLanguage: recognizedLanguage, recognizedContent: recognizedContent,),
                      GhiAmTab(recognizedLanguage: recognizedLanguage, recognizedContent: recognizedContent,
                        onUploadSuccess: () {
                          _nhanDienTabKey.currentState?.startListeningFromUpload();
                        },
                      ),
            ],
          ),
        ),
      ],
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDarkMode ? Colors.transparent : null,
        body: Stack(
          children: [
            if (isDarkMode) ...[
              // 🌊 NỀN TỐI
              Positioned(
                top: 0,
                right: 0,
                child: Image.asset("assets/images/top1.png", width: size.width),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Image.asset("assets/images/top2.png", width: size.width),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Image.asset("assets/images/bottom1.png", width: size.width),
              ),
              content,
            ] else ...[
              // 🌞 NỀN SÁNG như login.dart
              // Background(child: content)
              Background(
                showIotIcon: false,          // Ẩn iot.png nếu muốn
                showProfileImage: false,     // ⚠️ Ẩn img.png (ảnh tròn)
                child: content,
              ),
            ],
          ],
        ),
      ),
    );
  }
}


