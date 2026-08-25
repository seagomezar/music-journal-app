import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flute/models/piece.dart';
import 'package:flute/models/repertoire_folder.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/providers/repertoire_provider.dart';
import 'package:flute/screens/repertoire_view.dart';
import 'package:flute/services/database_service.dart';

Piece _piece({
  required String id,
  required String title,
  String? folderId,
  String? pdfPath,
}) {
  return Piece(
    id: id,
    title: title,
    composer: 'Composer',
    targetBpm: 80,
    measuresTotal: 20,
    measuresCompleted: 5,
    pdfPath: pdfPath,
    folderId: folderId,
  );
}

class MemoryRepertoireProvider extends RepertoireProvider {
  final List<RepertoireFolder> _memoryFolders = [];
  final List<Piece> _memoryPieces = [];
  var _nextFolder = 1;

  @override
  List<RepertoireFolder> get folders => List.unmodifiable(_memoryFolders);

  @override
  List<Piece> get pieces => List.unmodifiable(_memoryPieces);

  @override
  bool get isLoading => false;

  @override
  Future<void> loadPieces() async {}

  @override
  List<Piece> piecesInFolder(String? folderId) {
    return List.unmodifiable(
      _memoryPieces.where((piece) => piece.folderId == folderId),
    );
  }

  @override
  int pieceCountForFolder(String folderId) {
    return _memoryPieces.where((piece) => piece.folderId == folderId).length;
  }

  @override
  Future<RepertoireFolder> createFolder(String name) async {
    final folder = RepertoireFolder(
      id: 'folder_${_nextFolder++}',
      name: name.trim(),
    );
    _memoryFolders.add(folder);
    _memoryFolders.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return folder;
  }

  @override
  Future<void> renameFolder(String id, String name) async {
    final index = _memoryFolders.indexWhere((folder) => folder.id == id);
    _memoryFolders[index] = _memoryFolders[index].copyWith(name: name.trim());
    notifyListeners();
  }

  @override
  Future<void> deleteFolder(String id) async {
    for (var index = 0; index < _memoryPieces.length; index++) {
      if (_memoryPieces[index].folderId == id) {
        _memoryPieces[index] = _memoryPieces[index].copyWith(folderId: null);
      }
    }
    _memoryFolders.removeWhere((folder) => folder.id == id);
    notifyListeners();
  }

  @override
  Future<void> movePiece(String pieceId, String? folderId) async {
    final index = _memoryPieces.indexWhere((piece) => piece.id == pieceId);
    _memoryPieces[index] = _memoryPieces[index].copyWith(folderId: folderId);
    notifyListeners();
  }

  @override
  Future<void> savePiece(Piece piece, {String? pdfOriginalName}) async {
    _memoryPieces.add(piece);
    _memoryPieces.sort((a, b) => a.title.compareTo(b.title));
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory databaseDirectory;

  setUpAll(() async {
    databaseDirectory = await Directory.systemTemp.createTemp(
      'flute_repertoire_folders_',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => databaseDirectory.path,
        );
    await DatabaseService().init();
  });

  setUp(() async {
    await DatabaseService().clearAllUserData();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  test('piece folder membership is backward compatible and clearable', () {
    final legacy = Piece.fromJson({
      'id': 'legacy',
      'title': 'Legacy score',
      'composer': 'Composer',
      'targetBpm': 80,
    });

    expect(legacy.folderId, isNull);
    final filed = legacy.copyWith(folderId: 'folder_1');
    expect(filed.folderId, 'folder_1');
    expect(filed.copyWith(folderId: null).folderId, isNull);
    expect(Piece.fromJson(filed.toJson()).folderId, 'folder_1');
  });

  test('folders serialize their stable identity and name', () {
    const folder = RepertoireFolder(id: 'folder_1', name: 'Etudes');
    expect(RepertoireFolder.fromJson(folder.toJson()).id, folder.id);
    expect(RepertoireFolder.fromJson(folder.toJson()).name, folder.name);
  });

  test(
    'provider sorts folders and pieces and rejects duplicate names',
    () async {
      final provider = RepertoireProvider();
      await provider.loadPieces();

      final zulu = await provider.createFolder('Zulu');
      final alpha = await provider.createFolder('  alpha  ');
      expect(provider.folders.map((folder) => folder.name), ['alpha', 'Zulu']);
      await expectLater(provider.createFolder('ALPHA'), throwsArgumentError);

      await DatabaseService().savePiece(
        _piece(id: 'piece_z', title: 'Zulu piece', folderId: zulu.id),
      );
      await DatabaseService().savePiece(
        _piece(id: 'piece_a', title: 'Alpha piece', folderId: alpha.id),
      );
      await provider.loadPieces();
      expect(provider.pieces.map((piece) => piece.title), [
        'Alpha piece',
        'Zulu piece',
      ]);
    },
  );

  test(
    'moving and deleting folders preserves piece data and PDF paths',
    () async {
      final provider = RepertoireProvider();
      await provider.loadPieces();
      final folder = await provider.createFolder('Sonatas');
      const pdfPath = '/managed/scores/sonata.pdf';
      await DatabaseService().savePiece(
        _piece(
          id: 'piece_1',
          title: 'Sonata',
          folderId: folder.id,
          pdfPath: pdfPath,
        ),
      );
      await provider.loadPieces();

      await provider.movePiece('piece_1', null);
      expect(provider.pieces.single.folderId, isNull);
      expect(provider.pieces.single.pdfPath, pdfPath);
      expect(provider.pieces.single.measuresCompleted, 5);

      await provider.movePiece('piece_1', folder.id);
      await provider.deleteFolder(folder.id);
      expect(provider.folders, isEmpty);
      expect(provider.pieces.single.folderId, isNull);
      expect(provider.pieces.single.pdfPath, pdfPath);
    },
  );

  test('erasing app data also removes repertoire folders', () async {
    final provider = RepertoireProvider();
    await provider.loadPieces();
    await provider.createFolder('Temporary folder');
    expect(provider.folders, isNotEmpty);

    await DatabaseService().clearAllUserData();
    await provider.loadPieces();

    expect(provider.folders, isEmpty);
  });

  testWidgets('folder browser creates, files, moves, renames, and deletes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = MemoryRepertoireProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RepertoireProvider>.value(value: provider),
          ChangeNotifierProvider(
            create: (_) => LocalizationProvider(initialLocale: 'en'),
          ),
        ],
        child: const MaterialApp(home: RepertoireView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Etudes');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Etudes'), findsOneWidget);

    await tester.tap(find.text('Etudes'));
    await tester.pumpAndSettle();
    expect(find.text('This folder is empty.'), findsOneWidget);

    await tester.tap(find.byTooltip('Add Repertoire Piece'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'First Study');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(provider.pieces.single.folderId, provider.folders.single.id);
    expect(find.text('First Study'), findsOneWidget);

    await tester.tap(find.text('First Study'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unfiled'));
    await tester.pumpAndSettle();
    expect(provider.pieces.single.folderId, isNull);
    expect(find.text('This folder is empty.'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to repertoire'));
    await tester.pumpAndSettle();
    expect(find.text('First Study'), findsOneWidget);

    await tester.tap(find.byTooltip('Folder actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Studies');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Studies'), findsOneWidget);

    await tester.tap(find.byTooltip('Folder actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(provider.folders, isEmpty);
    expect(provider.pieces.single.title, 'First Study');
    expect(find.text('First Study'), findsOneWidget);
  });
}
