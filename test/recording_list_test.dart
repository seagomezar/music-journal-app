import 'package:flute/models/session_recording.dart';
import 'package:flute/providers/localization_provider.dart';
import 'package:flute/widgets/recording_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('shows every recording and exposes playback action', (
    tester,
  ) async {
    final recordings = [
      SessionRecording(
        id: 'recording-1',
        name: 'Warm-up',
        createdAt: DateTime.utc(2026, 7, 20, 15),
        storagePath: '/one.m4a',
      ),
      SessionRecording(
        id: 'recording-2',
        name: 'Final take',
        createdAt: DateTime.utc(2026, 7, 20, 15, 1),
        storagePath: '/two.m4a',
      ),
    ];
    SessionRecording? played;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LocalizationProvider(initialLocale: 'en'),
        child: MaterialApp(
          home: Scaffold(
            body: RecordingList(
              recordings: recordings,
              playingPath: null,
              isPlaying: false,
              onPlay: (recording) async => played = recording,
              onRename: (_) async {},
              onDelete: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Warm-up'), findsOneWidget);
    expect(find.text('Final take'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pump();
    expect(played?.id, 'recording-1');
  });
}
