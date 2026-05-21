import 'package:flutter/material.dart';
import '../models/piece.dart';
import '../services/database_service.dart';

class RepertoireProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
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

  Future<void> savePiece(Piece piece) async {
    try {
      await _db.savePiece(piece);
      await loadPieces();
    } catch (e) {
      debugPrint('Error saving piece: $e');
    }
  }

  Future<void> deletePiece(String id) async {
    try {
      await _db.deletePiece(id);
      await loadPieces();
    } catch (e) {
      debugPrint('Error deleting piece: $e');
    }
  }

  Future<void> updatePieceProgress(String id, int completedMeasures) async {
    try {
      final index = _pieces.indexWhere((p) => p.id == id);
      if (index != -1) {
        final updated = _pieces[index].copyWith(measuresCompleted: completedMeasures);
        await savePiece(updated);
      }
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }
  }
}
