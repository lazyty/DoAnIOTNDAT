import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iotwsra/components/theme_provider.dart';
import 'package:provider/provider.dart';
import 'tabnhandien.dart';
import 'tabghiam.dart';
import '../components/background.dart';

class ManHinhChinhScreen extends StatefulWidget {
  const ManHinhChinhScreen({super.key});

  @override
  State<ManHinhChinhScreen> createState() => _ManHinhChinhScreenState();
}

class _ManHinhChinhScreenState extends State<ManHinhChinhScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<String?> recognizedLanguage = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> recognizedContent = ValueNotifier<String?>(null);
  final ValueNotifier<String?> recognizedModel = ValueNotifier<String?>(null);
  final GlobalKey<NhanDienTabState> _nhanDienTabKey =
      GlobalKey<NhanDienTabState>();

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    recognizedLanguage.dispose();
    recognizedContent.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                  Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  ).toggleTheme();
                },
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                onPressed: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Xác nhận'),
                          content: const Text(
                            'Bạn có chắc chắn muốn đăng xuất không?',
                          ),
                          actions: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey,
                                backgroundColor: Colors.grey.withOpacity(0.1),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Hủy'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                  );
                  if (shouldLogout == true) {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
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
              NhanDienTab(
                key: _nhanDienTabKey,
                recognizedLanguage: recognizedLanguage,
                recognizedContent: recognizedContent,
                recognizedModel: recognizedModel,
              ),
              GhiAmTab(
                recognizedLanguage: recognizedLanguage,
                recognizedContent: recognizedContent,
                recognizedModel: recognizedModel,
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
                child: Image.asset(
                  "assets/images/bottom1.png",
                  width: size.width,
                ),
              ),
              content,
            ] else ...[
              // 🌞 NỀN SÁNG như login.dart
              // Background(child: content)
              Background(
                showIotIcon: false, // Ẩn iot.png nếu muốn
                showProfileImage: false, // ⚠️ Ẩn img.png (ảnh tròn)
                child: content,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
