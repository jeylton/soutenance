import 'dart:math' as math;

import 'package:flutter/material.dart';

class BackgroundWavePainter extends CustomPainter {
  BackgroundWavePainter(this.animationValue);

  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFEFF8FF),
          Color(0xFFDFF2FF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    final wave1 = Paint()
      ..color = const Color(0xFFB9E6FF).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final wave2 = Paint()
      ..color = const Color(0xFF8BD2F6).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final phase = animationValue * 2 * math.pi;

    final path1 = Path()..moveTo(0, size.height * 0.2);
    path1.quadraticBezierTo(
      size.width * 0.25,
      size.height * (0.12 + 0.02 * math.sin(phase)),
      size.width * 0.5,
      size.height * (0.2 + 0.02 * math.sin(phase + 1.2)),
    );
    path1.quadraticBezierTo(
      size.width * 0.75,
      size.height * (0.28 + 0.02 * math.sin(phase + 2.1)),
      size.width,
      size.height * (0.18 + 0.02 * math.sin(phase + 2.9)),
    );
    path1.lineTo(size.width, 0);
    path1.lineTo(0, 0);
    path1.close();

    final path2 = Path()..moveTo(0, size.height * 0.35);
    path2.quadraticBezierTo(
      size.width * 0.3,
      size.height * (0.42 + 0.02 * math.sin(phase + 0.7)),
      size.width * 0.6,
      size.height * (0.34 + 0.02 * math.sin(phase + 1.8)),
    );
    path2.quadraticBezierTo(
      size.width * 0.85,
      size.height * (0.28 + 0.02 * math.sin(phase + 2.8)),
      size.width,
      size.height * (0.36 + 0.02 * math.sin(phase + 3.7)),
    );
    path2.lineTo(size.width, 0);
    path2.lineTo(0, 0);
    path2.close();

    canvas.drawPath(path1, wave1);
    canvas.drawPath(path2, wave2);
  }

  @override
  bool shouldRepaint(covariant BackgroundWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
