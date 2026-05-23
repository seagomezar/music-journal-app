import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? dotColor;
  final bool showShadow;

  const AppLogo({
    super.key,
    this.size = 120,
    this.color,
    this.dotColor,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showShadow
          ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (color ?? AppTheme.primary).withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            )
          : null,
      child: CustomPaint(
        painter: _FluteLogoPainter(
          color: color ?? AppTheme.primary,
          dotColor: dotColor ?? AppTheme.background,
        ),
      ),
    );
  }
}

class _FluteLogoPainter extends CustomPainter {
  final Color color;
  final Color dotColor;

  _FluteLogoPainter({
    required this.color,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Outer circle
    final Paint circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025; // stroke-width = 2.5px in 100x100
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.48, circlePaint);

    // Flute body: M45 20 L45 80 Q45 85 50 85 Q55 85 55 80 L55 20 Q55 15 50 15 Q45 15 45 20 Z
    final Paint bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path bodyPath = Path();
    bodyPath.moveTo(w * 0.45, h * 0.20);
    bodyPath.lineTo(w * 0.45, h * 0.80);
    bodyPath.quadraticBezierTo(w * 0.45, h * 0.85, w * 0.50, h * 0.85);
    bodyPath.quadraticBezierTo(w * 0.55, h * 0.85, w * 0.55, h * 0.80);
    bodyPath.lineTo(w * 0.55, h * 0.20);
    bodyPath.quadraticBezierTo(w * 0.55, h * 0.15, w * 0.50, h * 0.15);
    bodyPath.quadraticBezierTo(w * 0.45, h * 0.15, w * 0.45, h * 0.20);
    bodyPath.close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Flute holes (small dots): cx=50, cy=30, 45, 60, r=2.5
    final Paint dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.50, h * 0.30), w * 0.025, dotPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.45), w * 0.025, dotPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.60), w * 0.025, dotPaint);

    // Flute keys path: M55 25 L65 25 Q70 25 70 35 L70 45 Q70 55 60 55 L55 55
    final Paint keysPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04 // stroke-width = 4
      ..strokeCap = StrokeCap.round;

    final Path keysPath = Path();
    keysPath.moveTo(w * 0.55, h * 0.25);
    keysPath.lineTo(w * 0.65, h * 0.25);
    keysPath.quadraticBezierTo(w * 0.70, h * 0.25, w * 0.70, h * 0.35);
    keysPath.lineTo(w * 0.70, h * 0.45);
    keysPath.quadraticBezierTo(w * 0.70, h * 0.55, w * 0.60, h * 0.55);
    keysPath.lineTo(w * 0.55, h * 0.55);
    canvas.drawPath(keysPath, keysPaint);
  }

  @override
  bool shouldRepaint(covariant _FluteLogoPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dotColor != dotColor;
  }
}
