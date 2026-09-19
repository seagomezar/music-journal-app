import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flute/screens/startup_recovery_screen.dart';

class TolerantGoldenFileComparator extends LocalFileComparator {
  TolerantGoldenFileComparator(super.testFile, {this.tolerance = 0.01});

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent <= tolerance) {
      debugPrint(
        'A pixel difference of ${(result.diffPercent * 100).toStringAsFixed(3)}% was detected, '
        'which is within the allowed tolerance of ${(tolerance * 100).toStringAsFixed(1)}%.',
      );
      return true;
    }
    if (!result.passed) {
      final error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return result.passed;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final testFileUri = Uri.parse('test/recovery_golden_test.dart');
    goldenFileComparator = TolerantGoldenFileComparator(
      testFileUri,
      tolerance: 0.01,
    );
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root == null) {
      throw StateError('Flutter SDK font location is unavailable.');
    }
    for (final entry in {
      'Roboto': ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
      'MaterialIcons': ['MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final name in entry.value) {
        loader.addFont(
          File(
            '$root/bin/cache/artifacts/material_fonts/$name',
          ).readAsBytes().then((bytes) => bytes.buffer.asByteData()),
        );
      }
      await loader.load();
    }
  });
  testWidgets('startup recovery phone layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(StartupRecoveryScreen(onRetry: () async {}));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/startup_recovery.png'),
    );
  }, tags: 'golden');
}
