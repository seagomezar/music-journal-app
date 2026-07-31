import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/piece.dart';
import '../services/database_service.dart';
import '../services/file_storage_service.dart';

class RepertoireProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final FileStorageService _storage = FileStorageService();
  List<Piece> _pieces = [];
  bool _isLoading = false;

  List<Piece> get pieces => _pieces;
  bool get isLoading => _isLoading;

  Future<void> loadPieces() async {
    _isLoading = true;
    notifyListeners();
    try {
      _pieces = _db.getPieces();
    } catch (e) {
      debugPrint('Error loading pieces: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> savePiece(Piece piece, {String? pdfOriginalName}) async {
    try {
      var pieceToSave = piece;
      final pdfPath = piece.pdfPath;
      if (!kIsWeb &&
          pdfPath != null &&
          pdfPath.isNotEmpty &&
          !await _storage.isManagedPath(pdfPath)) {
        final importedPath = await _storage.importPdf(
          pdfPath,
          originalName: pdfOriginalName,
        );
        pieceToSave = piece.copyWith(pdfPath: importedPath);
      }
      await _db.savePiece(pieceToSave);
      await loadPieces();
    } catch (e) {
      debugPrint('Error saving piece: $e');
      rethrow;
    }
  }

  Future<void> deletePiece(String id) async {
    try {
      Piece? piece;
      for (final item in _pieces) {
        if (item.id == id) {
          piece = item;
          break;
        }
      }
      await _db.deletePiece(id);
      await _storage.deleteManagedFile(piece?.pdfPath);
      await loadPieces();
    } catch (e) {
      debugPrint('Error deleting piece: $e');
      rethrow;
    }
  }

  Future<void> updatePieceProgress(String id, int completedMeasures) async {
    try {
      final index = _pieces.indexWhere((p) => p.id == id);
      if (index != -1) {
        final piece = _pieces[index];
        final updated = piece.copyWith(
          measuresCompleted: completedMeasures
              .clamp(0, piece.measuresTotal)
              .toInt(),
        );
        await savePiece(updated);
      }
    } catch (e) {
      debugPrint('Error updating progress: $e');
      rethrow;
    }
  }
}
