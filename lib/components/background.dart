import 'package:flutter/material.dart';

class Background extends StatelessWidget {
  final Widget child;

  const Background({
    super.key,
    required this.child,
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
            child: Image.asset(
                "assets/images/top1.png",
                width: size.width
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Image.asset(
                "assets/images/top2.png",
                width: size.width
            ),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: Image.asset(
                "assets/images/iot.png",
                width: size.width * 0.25
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset(
                "assets/images/bottom1.png",
                width: size.width
            ),
          ),
          Positioned(
            top: 50,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(60), // Tùy chỉnh độ bo tròn
              child: Image.asset(
                "assets/images/img.png",
                width: size.width * 0.30,
                height: size.width * 0.30,
                fit: BoxFit.cover,
              ),
            ),
          ),
          child
        ],
      ),
    );
  }
}