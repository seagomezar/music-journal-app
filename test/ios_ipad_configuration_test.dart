import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  final skipNativeChecks = kIsWeb || !Platform.isMacOS;

  test(
    'all iOS build configurations target iPhone and iPad',
    () async {
      for (final configuration in ['Debug', 'Profile', 'Release']) {
        final settings = await _effectiveBuildSettings(configuration);
        final families = (settings['TARGETED_DEVICE_FAMILY'] as String)
            .split(',')
            .map((family) => family.trim())
            .toSet();

        expect(families, {'1', '2'}, reason: configuration);
      }
    },
    skip: skipNativeChecks,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('iPad supports rotation and resizable multitasking', () async {
    final result = await Process.run('plutil', [
      '-convert',
      'json',
      '-o',
      '-',
      'ios/Runner/Info.plist',
    ]);
    expect(result.exitCode, 0, reason: result.stderr as String);

    final infoPlist =
        jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final orientations =
        (infoPlist['UISupportedInterfaceOrientations~ipad'] as List<dynamic>)
            .cast<String>();

    expect(
      orientations,
      unorderedEquals([
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
      ]),
    );
    expect(infoPlist['UIRequiresFullScreen'], anyOf(isNull, isFalse));
  }, skip: skipNativeChecks);
}

Future<Map<String, dynamic>> _effectiveBuildSettings(
  String configuration,
) async {
  final result = await Process.run('xcodebuild', [
    '-project',
    'ios/Runner.xcodeproj',
    '-target',
    'Runner',
    '-configuration',
    configuration,
    '-sdk',
    'iphonesimulator',
    '-showBuildSettings',
    '-json',
  ]);
  expect(result.exitCode, 0, reason: result.stderr as String);

  final targets = jsonDecode(result.stdout as String) as List<dynamic>;
  final runner = targets.cast<Map<String, dynamic>>().singleWhere(
    (target) => target['target'] == 'Runner',
  );
  return runner['buildSettings'] as Map<String, dynamic>;
}
