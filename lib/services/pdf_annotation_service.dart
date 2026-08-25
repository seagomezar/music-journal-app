import '../models/pdf_annotation.dart';
import 'database_service.dart';

abstract class PdfAnnotationRepository {
  Future<PdfAnnotationDocument> load({
    required String pieceId,
    required String sourcePath,
  });

  Future<void> save(PdfAnnotationDocument document);

  Future<void> delete(String pieceId);
}

class PdfAnnotationService implements PdfAnnotationRepository {
  final DatabaseService _database;

  PdfAnnotationService({DatabaseService? database})
    : _database = database ?? DatabaseService();

  @override
  Future<PdfAnnotationDocument> load({
    required String pieceId,
    required String sourcePath,
  }) async {
    final stored = _database.getPdfAnnotations(pieceId);
    if (stored == null) {
      return PdfAnnotationDocument.empty(
        pieceId: pieceId,
        sourcePath: sourcePath,
      );
    }

    if (stored.sourcePath != sourcePath) {
      await delete(pieceId);
      return PdfAnnotationDocument.empty(
        pieceId: pieceId,
        sourcePath: sourcePath,
      );
    }
    return stored;
  }

  @override
  Future<void> save(PdfAnnotationDocument document) {
    return _database.savePdfAnnotations(document);
  }

  @override
  Future<void> delete(String pieceId) {
    return _database.deletePdfAnnotations(pieceId);
  }
}
