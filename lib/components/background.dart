
import 'package:flutter/material.dart';
class Background extends StatelessWidget {
  final Widget child;
  final bool showIotIcon;
  final bool showProfileImage; // 👈 Thêm biến mới

  const Background({
    super.key,
    required this.child,
    this.showIotIcon = true,
    this.showProfileImage = true, // 👈 Mặc định hiện ảnh img.png
  });

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return SizedBox(
      width: double.infinity,
      height: size.height,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
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

          if (showIotIcon)
            Positioned(
              top: 50,
              right: 20,
              child: Image.asset("assets/images/iot.png", width: size.width * 0.25),
            ),

          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset("assets/images/bottom1.png", width: size.width),
          ),

          /// ✅ Ẩn/hiện ảnh img.png
          if (showProfileImage)
            Positioned(
              top: 50,
              right: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: Image.asset(
                  "assets/images/img.png",
                  width: size.width * 0.30,
                  height: size.width * 0.30,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          child,
        ],
      ),
    );
  }
}






