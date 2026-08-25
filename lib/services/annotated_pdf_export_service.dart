import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdf_document/pdf_document.dart' as pdf;

import '../models/pdf_annotation.dart';

abstract class AnnotatedPdfExporter {
  Future<Uint8List> build({
    required String sourcePath,
    required PdfAnnotationDocument annotations,
  });
}

class OpenSourceAnnotatedPdfExporter implements AnnotatedPdfExporter {
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
  final document = pdf.PdfDocument.open(sourceBytes);
  final editor = pdf.PdfEditor(document);
  for (final entry in annotations.pages.entries) {
    final pageIndex = entry.key - 1;
    if (pageIndex < 0 || pageIndex >= document.pageCount) continue;

    final page = document.page(pageIndex);
    for (final stroke in entry.value) {
      if (stroke.points.isEmpty) continue;
      editor.addInk(
        pageIndex,
        [
          stroke.points
              .map((point) => _pointInPageSpace(point, page))
              .toList(growable: false),
        ],
        color: stroke.colorArgb & 0x00ffffff,
        strokeWidth: stroke.widthInPdfPoints,
      );
      editor.flattenAnnotations(
        pageIndex,
        annotations: [page.annotations.last],
      );
    }
  }
  return editor.save();
}

(double, double) _pointInPageSpace(PdfAnnotationPoint point, pdf.PdfPage page) {
  final box = page.cropBox;
  final x = point.x.clamp(0.0, 1.0);
  final y = point.y.clamp(0.0, 1.0);
  return switch (page.rotation) {
    90 => (box.left + y * box.width, box.bottom + x * box.height),
    180 => (box.left + (1 - x) * box.width, box.bottom + y * box.height),
    270 => (box.left + (1 - y) * box.width, box.bottom + (1 - x) * box.height),
    _ => (box.left + x * box.width, box.bottom + (1 - y) * box.height),
  };
}
