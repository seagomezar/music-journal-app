import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import '../models/pdf_annotation.dart';

class AnnotationPainter extends CustomPainter {
  final List<PdfInkStroke> strokes;
  final double pageWidthInPdfPoints;

  const AnnotationPainter({
    required this.strokes,
    required this.pageWidthInPdfPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pageWidthInPdfPoints <= 0) return;
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = Color(stroke.colorArgb)
        ..strokeWidth =
            stroke.widthInPdfPoints * size.width / pageWidthInPdfPoints
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final points = stroke.points
          .map((point) => Offset(point.x * size.width, point.y * size.height))
          .toList(growable: false);
      if (points.length == 1) {
        canvas.drawPoints(PointMode.points, points, paint);
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.pageWidthInPdfPoints != pageWidthInPdfPoints;
}
