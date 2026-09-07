import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import '../models/piece.dart';
import '../models/repertoire_folder.dart';
import '../services/database_service.dart';
import '../services/file_storage_service.dart';
import '../services/seed_localization.dart';

class RepertoireProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final FileStorageService _storage = FileStorageService();
  List<Piece> _pieces = [];
  List<RepertoireFolder> _folders = [];
  bool _isLoading = false;

  List<Piece> get pieces => List.unmodifiable(
    _pieces.map((piece) => localizeSeedPiece(piece, _db.getPreferredLocale())),
  );
  List<RepertoireFolder> get folders => List.unmodifiable(_folders);
  bool get isLoading => _isLoading;

  Future<void> loadPieces() async {
    _isLoading = true;
    notifyListeners();
    try {
      _folders = _db.getRepertoireFolders();
      _pieces = _db.getPieces();
      final folderIds = _folders.map((folder) => folder.id).toSet();
      for (var index = 0; index < _pieces.length; index++) {
        final piece = _pieces[index];
        if (piece.folderId != null && !folderIds.contains(piece.folderId)) {
          final unfiledPiece = piece.copyWith(folderId: null);
          await _db.savePiece(unfiledPiece);
          _pieces[index] = unfiledPiece;
        }
      }
      _pieces.sort(_comparePieces);
      _folders.sort(_compareFolders);
    } catch (e) {
      debugPrint('Error loading pieces: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Piece> piecesInFolder(String? folderId) {
    return List.unmodifiable(
      pieces.where((piece) => piece.folderId == folderId),
    );
  }

  int pieceCountForFolder(String folderId) {
    return _pieces.where((piece) => piece.folderId == folderId).length;
  }

  Future<RepertoireFolder> createFolder(String name) async {
    final normalizedName = _validateFolderName(name);
    final folder = RepertoireFolder(
      id: 'folder_${const Uuid().v7()}',
      name: normalizedName,
    );
    try {
      await _db.saveRepertoireFolder(folder);
      await loadPieces();
      return folder;
    } catch (error) {
      await _reloadAfterFailure();
      debugPrint('Error creating repertoire folder: $error');
      rethrow;
    }
  }

  Future<void> renameFolder(String id, String name) async {
    final index = _folders.indexWhere((folder) => folder.id == id);
    if (index == -1) throw StateError('Repertoire folder not found.');
    final normalizedName = _validateFolderName(name, excludingId: id);
    try {
      await _db.saveRepertoireFolder(
        _folders[index].copyWith(name: normalizedName),
      );
      await loadPieces();
    } catch (error) {
      await _reloadAfterFailure();
      debugPrint('Error renaming repertoire folder: $error');
      rethrow;
    }
  }

  Future<void> deleteFolder(String id) async {
    if (!_folders.any((folder) => folder.id == id)) {
      throw StateError('Repertoire folder not found.');
    }
    try {
      for (final piece in _pieces.where((piece) => piece.folderId == id)) {
        await _db.savePiece(piece.copyWith(folderId: null));
      }
      await _db.deleteRepertoireFolder(id);
      await loadPieces();
    } catch (error) {
      await _reloadAfterFailure();
      debugPrint('Error deleting repertoire folder: $error');
      rethrow;
    }
  }

  Future<void> movePiece(String pieceId, String? folderId) async {
    final pieceIndex = _pieces.indexWhere((piece) => piece.id == pieceId);
    if (pieceIndex == -1) throw StateError('Repertoire piece not found.');
    if (folderId != null && !_folders.any((folder) => folder.id == folderId)) {
      throw StateError('Repertoire folder not found.');
    }
    try {
      await _db.savePiece(_pieces[pieceIndex].copyWith(folderId: folderId));
      await loadPieces();
    } catch (error) {
      await _reloadAfterFailure();
      debugPrint('Error moving repertoire piece: $error');
      rethrow;
    }
  }

  Future<void> savePiece(Piece piece, {String? pdfOriginalName}) async {
    try {
      if (piece.folderId != null &&
          !_folders.any((folder) => folder.id == piece.folderId)) {
        throw StateError('Repertoire folder not found.');
      }
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

  String _validateFolderName(String value, {String? excludingId}) {
    final name = value.trim();
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError.value(value, 'name', 'Invalid folder name.');
    }
    final normalized = name.toLowerCase();
    if (_folders.any(
      (folder) =>
          folder.id != excludingId && folder.name.toLowerCase() == normalized,
    )) {
      throw ArgumentError.value(value, 'name', 'Duplicate folder name.');
    }
    return name;
  }

  Future<void> _reloadAfterFailure() async {
    try {
      await loadPieces();
    } catch (_) {}
  }

  static int _compareFolders(RepertoireFolder a, RepertoireFolder b) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static int _comparePieces(Piece a, Piece b) {
    final titleOrder = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (titleOrder != 0) return titleOrder;
    return a.composer.toLowerCase().compareTo(b.composer.toLowerCase());
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
      if (piece?.pdfPath != null) {
        await _db.scheduleMediaCleanup([piece!.pdfPath!]);
      }
      await _db.deletePiece(id);
      await _db.retryMediaCleanup();
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
