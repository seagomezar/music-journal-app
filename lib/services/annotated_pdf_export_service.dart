import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../models/pdf_annotation.dart';

abstract class AnnotatedPdfExporter {
  Future<Uint8List> build({
    required String sourcePath,
    required PdfAnnotationDocument annotations,
  });
}

class SyncfusionAnnotatedPdfExporter implements AnnotatedPdfExporter {
  @override
  Future<Uint8List> build({
    required String sourcePath,
    required PdfAnnotationDocument annotations,
  }) async {
    final sourceBytes = await File(sourcePath).readAsBytes();
    return compute(buildAnnotatedPdfBytes, {
      'sourceBytes': sourceBytes,
      'annotations': annotations.toJson(),
    });
  }
}

@visibleForTesting
Uint8List buildAnnotatedPdfBytes(Map<String, dynamic> input) {
  final sourceBytes = input['sourceBytes'] as Uint8List;
  final annotations = PdfAnnotationDocument.fromJson(
    Map<String, dynamic>.from(input['annotations'] as Map),
  );
  final document = sf.PdfDocument(inputBytes: sourceBytes);
  try {
    for (final entry in annotations.pages.entries) {
      final pageIndex = entry.key - 1;
      if (pageIndex < 0 || pageIndex >= document.pages.count) continue;

      final page = document.pages[pageIndex];
      final clientSize = page.getClientSize();
      final pageSize = switch (page.rotation) {
        sf.PdfPageRotateAngle.rotateAngle90 ||
        sf.PdfPageRotateAngle.rotateAngle270 => Size(
          clientSize.height,
          clientSize.width,
        ),
        _ => clientSize,
      };
      for (final stroke in entry.value) {
        if (stroke.points.isEmpty) continue;
        final color = stroke.colorArgb;
        final pen = sf.PdfPen(
          sf.PdfColor((color >> 16) & 0xff, (color >> 8) & 0xff, color & 0xff),
          width: stroke.widthInPdfPoints,
          lineCap: sf.PdfLineCap.round,
          lineJoin: sf.PdfLineJoin.round,
        );
        final points = stroke.points
            .map(
              (point) =>
                  Offset(point.x * pageSize.width, point.y * pageSize.height),
            )
            .toList(growable: false);
        if (points.length == 1) {
          page.graphics.drawLine(pen, points.first, points.first);
          continue;
        }
        for (var index = 0; index < points.length - 1; index++) {
          page.graphics.drawLine(pen, points[index], points[index + 1]);
        }
      }
    }
    return Uint8List.fromList(document.saveSync());
  } finally {
    document.dispose();
  }
}
