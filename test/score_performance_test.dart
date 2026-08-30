import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flute/models/score_view_preferences.dart';
import 'package:flute/screens/score_viewer_screen.dart';
import 'package:flute/services/screen_awake_service.dart';

class _FakeScreenAwakeController implements ScreenAwakeController {
  final states = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async => states.add(enabled);
}

class _FailingScreenAwakeController implements ScreenAwakeController {
  final states = <bool>[];
  var failuresRemaining = 1;

  @override
  Future<void> setEnabled(bool enabled) async {
    states.add(enabled);
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('platform failure');
    }
  }
}

void main() {
  test('iPad multitasking keeps score orientation automatic', () {
    expect(
      supportsScoreOrientationPreference(
        platform: TargetPlatform.iOS,
        isTablet: true,
      ),
      isFalse,
    );
    expect(
      supportsScoreOrientationPreference(
        platform: TargetPlatform.iOS,
        isTablet: false,
      ),
      isTrue,
    );
  });

  test('two-page scores fall back to a whole page in portrait', () {
    const portrait = Size(390, 844);
    const landscape = Size(844, 390);

    expect(
      scoreLayoutForViewport(ScoreLayoutMode.twoPage, portrait),
      ScoreLayoutMode.singlePage,
    );
    expect(
      scoreFitForViewport(
        layoutMode: ScoreLayoutMode.twoPage,
        fitMode: ScoreFitMode.fitWidth,
        viewportSize: portrait,
      ),
      ScoreFitMode.fitPage,
    );
    expect(
      scoreLayoutForViewport(ScoreLayoutMode.twoPage, landscape),
      ScoreLayoutMode.twoPage,
    );
    expect(
      scoreFitForViewport(
        layoutMode: ScoreLayoutMode.twoPage,
        fitMode: ScoreFitMode.fitWidth,
        viewportSize: landscape,
      ),
      ScoreFitMode.fitWidth,
    );
  });

  test('explicit single-page fit-width remains available in portrait', () {
    expect(
      scoreFitForViewport(
        layoutMode: ScoreLayoutMode.singlePage,
        fitMode: ScoreFitMode.fitWidth,
        viewportSize: const Size(390, 844),
      ),
      ScoreFitMode.fitWidth,
    );
  });

  test('score preferences serialize performance display controls', () {
    final preferences = ScoreViewPreferences(
      pieceId: 'piece_1',
      sourcePath: '/scores/one.pdf',
      layoutMode: ScoreLayoutMode.halfPage,
      fitMode: ScoreFitMode.fitWidth,
      orientationMode: ScoreOrientationMode.landscape,
      colorMode: ScoreColorMode.sepia,
      autoScrollPaceMode: AutoScrollPaceMode.duration,
      lastPage: 8,
      halfPageSplitRatios: const {7: 0.63},
      firstPageOnRight: true,
      autoScrollDurationSeconds: 720,
    );

    final restored = ScoreViewPreferences.fromJson(preferences.toJson());

    expect(restored.layoutMode, ScoreLayoutMode.halfPage);
    expect(restored.fitMode, ScoreFitMode.fitWidth);
    expect(restored.orientationMode, ScoreOrientationMode.landscape);
    expect(restored.colorMode, ScoreColorMode.sepia);
    expect(restored.autoScrollPaceMode, AutoScrollPaceMode.duration);
    expect(restored.lastPage, 8);
    expect(restored.splitRatioForPage(7), 0.63);
    expect(restored.splitRatioForPage(8), 0.5);
    expect(restored.firstPageOnRight, isTrue);
    expect(restored.autoScrollDurationSeconds, 720);
  });

  test('facing-page navigation respects first-page placement', () {
    expect(scoreSpreadStart(1, firstPageOnRight: false), 1);
    expect(scoreSpreadStart(2, firstPageOnRight: false), 1);
    expect(nextScoreSpread(1, 7, firstPageOnRight: false), 3);
    expect(previousScoreSpread(5, firstPageOnRight: false), 3);

    expect(scoreSpreadStart(1, firstPageOnRight: true), 1);
    expect(scoreSpreadStart(2, firstPageOnRight: true), 2);
    expect(scoreSpreadStart(3, firstPageOnRight: true), 2);
    expect(nextScoreSpread(1, 7, firstPageOnRight: true), 2);
    expect(nextScoreSpread(6, 7, firstPageOnRight: true), 6);
    expect(previousScoreSpread(2, firstPageOnRight: true), 1);
    expect(
      scorePageLabel(
        page: 1,
        pageCount: 7,
        layoutMode: ScoreLayoutMode.twoPage,
        firstPageOnRight: true,
      ),
      '1/7',
    );
    expect(
      scorePageLabel(
        page: 2,
        pageCount: 7,
        layoutMode: ScoreLayoutMode.twoPage,
        firstPageOnRight: true,
      ),
      '2–3/7',
    );
  });

  test('auto-scroll rate supports speed and duration pacing', () {
    expect(
      scoreAutoScrollRate(
        mode: AutoScrollPaceMode.speed,
        visibleHeight: 600,
        documentHeight: 6000,
        viewportHeightsPerMinute: 1.5,
        durationSeconds: 300,
      ),
      15,
    );
    expect(
      scoreAutoScrollRate(
        mode: AutoScrollPaceMode.duration,
        visibleHeight: 600,
        documentHeight: 6000,
        viewportHeightsPerMinute: 1,
        durationSeconds: 300,
      ),
      18,
    );
  });

  test('screen-awake coordinator keeps independent reasons active', () async {
    final platform = _FakeScreenAwakeController();
    final coordinator = ScreenAwakeCoordinator(platform);

    await coordinator.setEnabled(true);
    await coordinator.setPerformanceEnabled(true);
    await coordinator.setEnabled(false);
    await coordinator.setPerformanceEnabled(false);

    expect(platform.states, [true, false]);
  });

  test('screen-awake coordinator recovers after a platform failure', () async {
    final platform = _FailingScreenAwakeController();
    final coordinator = ScreenAwakeCoordinator(platform);

    await expectLater(coordinator.setEnabled(true), throwsStateError);
    await coordinator.setEnabled(true);
    await coordinator.setEnabled(false);

    expect(platform.states, [true, true, false]);
  });
}
