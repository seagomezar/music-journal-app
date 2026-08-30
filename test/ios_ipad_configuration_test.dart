import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all iOS build configurations target iPhone and iPad', () {
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(
      RegExp(r'TARGETED_DEVICE_FAMILY = "1,2";').allMatches(project).length,
      3,
    );
    expect(project, isNot(contains('TARGETED_DEVICE_FAMILY = 1;')));
  }, skip: kIsWeb);

  test('iPad supports rotation and resizable multitasking', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(infoPlist, contains('UISupportedInterfaceOrientations~ipad'));
    expect(infoPlist, contains('UIInterfaceOrientationPortraitUpsideDown'));
    expect(infoPlist, isNot(contains('UIRequiresFullScreen')));
  }, skip: kIsWeb);
}
