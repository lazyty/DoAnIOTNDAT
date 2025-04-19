import 'dart:math';
import 'package:flutter/material.dart';

class WavePainter extends CustomPainter {
  final double angle;
  WavePainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint circlePaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    // Đặt bán kính là nửa chiều rộng hoặc chiều cao của màn hình (tuỳ cái nào nhỏ hơn)
    final double radius = sqrt(size.width * size.width + size.height * size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Vẽ vòng tròn nền
    canvas.drawCircle(center, radius, circlePaint);

    // Vẽ đường sóng quanh vòng tròn
    final Paint wavePaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final Path path = Path();
    const waveCount = 16;
    for (int i = 0; i <= waveCount; i++) {
      double t = i / waveCount;
      double theta = t * 2 * pi + angle;
      double waveRadius = radius + sin(t * 2 * pi + angle) * 5;
      double x = center.dx + cos(theta) * waveRadius;
      double y = center.dy + sin(theta) * waveRadius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
