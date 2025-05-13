import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'tabnhandien.dart';
import 'tabghiam.dart';

class ManHinhChinhScreen extends StatelessWidget {
  const ManHinhChinhScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 🌊 NỀN TRÊN
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

            // 🌊 NỀN DƯỚI
            Positioned(
              bottom: 0,
              right: 0,
              child: Image.asset("assets/images/bottom1.png", width: size.width),
            ),


            // 📱 Nội dung giao diện chính
            Column(
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
                      IconButton(
                        icon: const Icon(Icons.exit_to_app, color: Colors.white),
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
                const Expanded(
                  child: TabBarView(
                    children: [
                      NhanDienTab(),
                      GhiAmTab(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'tabnhandien.dart';
// import 'tabghiam.dart';
//
// class ManHinhChinhScreen extends StatefulWidget {
//   const ManHinhChinhScreen({super.key});
//
//   @override
//   State<ManHinhChinhScreen> createState() => _ManHinhChinhScreenState();
// }
//
// class _ManHinhChinhScreenState extends State<ManHinhChinhScreen> {
//   final TextEditingController _textController = TextEditingController();
//
//   // Biến mẫu cho cờ và ngôn ngữ
//   String flagPath = "assets/images/vietnam_flag.png";
//   String currentLanguage = "Tiếng Việt";
//
//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.of(context).size;
//
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: Colors.transparent,
//         body: Stack(
//           children: [
//             // Nền
//             Positioned(top: 0, right: 0, child: Image.asset("assets/images/top1.png", width: size.width)),
//             Positioned(top: 0, right: 0, child: Image.asset("assets/images/top2.png", width: size.width)),
//             Positioned(bottom: 0, right: 0, child: Image.asset("assets/images/bottom1.png", width: size.width)),
//
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 const SizedBox(height: 60),
//
//                 // AppBar tùy chỉnh
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 20),
//                   child: Row(
//                     children: [
//                       const Expanded(
//                         child: Text(
//                           "IOTWSRA",
//                           style: TextStyle(
//                             color: Color(0xFF2661FA),
//                             fontSize: 28,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.exit_to_app, color: Colors.white),
//                         onPressed: () async {
//                           await FirebaseAuth.instance.signOut();
//                           Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // TabBar bo tròn đẹp
//                 Container(
//                   margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//                   padding: const EdgeInsets.all(4),
//                   decoration: BoxDecoration(
//                     color: Colors.white,
//                     borderRadius: BorderRadius.circular(50),
//                   ),
//                   child: const TabBar(
//                     indicator: BoxDecoration(
//                       color: Color(0xFF2661FA),
//                       borderRadius: BorderRadius.all(Radius.circular(50)),
//                     ),
//                     labelColor: Colors.white,
//                     unselectedLabelColor: Colors.black54,
//                     indicatorPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
//                     tabs: [
//                       Tab(icon: Icon(Icons.language), text: "Nhận diện"),
//                       Tab(icon: Icon(Icons.mic), text: "Ghi âm"),
//                     ],
//                   ),
//                 ),
//
//                 // Tab nội dung
//                 Expanded(
//                   child: TabBarView(
//                     children: [
//                       // 🔍 Tab NHẬN DIỆN
//                       SingleChildScrollView(
//                         padding: const EdgeInsets.all(20),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.stretch,
//                           children: [
//                             // Cờ & ngôn ngữ
//                             Container(
//                               margin: const EdgeInsets.only(bottom: 12),
//                               padding: const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(20),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.black.withOpacity(0.1),
//                                     blurRadius: 4,
//                                     offset: const Offset(0, 2),
//                                   )
//                                 ],
//                               ),
//                               child: Row(
//                                 children: [
//                                   Image.asset(flagPath, width: 32),
//                                   const SizedBox(width: 12),
//                                   Text(currentLanguage, style: const TextStyle(fontSize: 16)),
//                                   const Spacer(),
//                                   const Icon(Icons.arrow_drop_down),
//                                 ],
//                               ),
//                             ),
//
//                             // Nội dung
//                             Container(
//                               padding: const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: Colors.white,
//                                 borderRadius: BorderRadius.circular(20),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.black.withOpacity(0.1),
//                                     blurRadius: 6,
//                                     offset: const Offset(0, 3),
//                                   ),
//                                 ],
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                     children: [
//                                       const Text("📝 Nội dung", style: TextStyle(fontWeight: FontWeight.bold)),
//                                       IconButton(
//                                         onPressed: () => _textController.clear(),
//                                         icon: const Icon(Icons.close, color: Colors.red, size: 20),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 10),
//                                   TextField(
//                                     controller: _textController,
//                                     maxLines: 8,
//                                     decoration: const InputDecoration(
//                                       hintText: "Nhập nội dung tại đây...",
//                                       border: OutlineInputBorder(),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(height: 20),
//
//                             // Nút nhận diện (màu cam)
//                             ElevatedButton.icon(
//                               onPressed: () {
//                                 // TODO: xử lý nhận diện
//                               },
//                               icon: const Icon(Icons.search),
//                               label: const Text("Nhận diện"),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Color(0xFFFFB129),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(20),
//                                 ),
//                                 padding: const EdgeInsets.symmetric(vertical: 14),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//
//                       // 🎤 Tab GHI ÂM: chỉ timer + danh sách
//                       Container(
//                         width: double.infinity,
//                         padding: const EdgeInsets.symmetric(horizontal: 20),
//                         child: Column(
//                           children: [
//                             const SizedBox(height: 30),
//                             const Text(
//                               "00:00",
//                               style: TextStyle(
//                                 fontSize: 48,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             const SizedBox(height: 30),
//                             ElevatedButton(
//                               onPressed: () {
//                                 // TODO: bắt đầu ghi âm
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: const Color(0xFFB388FF),
//                                 shape: const CircleBorder(),
//                                 padding: const EdgeInsets.all(20),
//                               ),
//                               child: const Icon(Icons.mic, size: 36, color: Colors.white),
//                             ),
//                             const SizedBox(height: 30),
//                             const Divider(color: Colors.white54),
//                             const Align(
//                               alignment: Alignment.centerLeft,
//                               child: Text(
//                                 "Danh sách file ghi âm:",
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w500,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                             ),
//                             // TODO: hiện danh sách file ghi âm
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

