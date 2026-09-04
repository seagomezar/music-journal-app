import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flute/services/metronome_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MetronomeWave', () {
    test(
      'uses sample-balanced beat intervals at every supported BPM (30-252)',
      () {
        for (var bpm = 30; bpm <= 252; bpm++) {
          final offsets = MetronomeWave.beatSampleOffsets(bpm);
          final total = MetronomeWave.totalSamplesForBpm(bpm);
          final boundaries = [...offsets, total];
          final intervals = <int>[
            for (var index = 1; index < boundaries.length; index++)
              boundaries[index] - boundaries[index - 1],
          ];
          final ideal = MetronomeWave.sampleRate * 60 / bpm;

          expect(offsets.first, 0, reason: '$bpm BPM');
          expect(
            intervals.every(
              (interval) =>
                  interval == ideal.floor() || interval == ideal.ceil(),
            ),
            isTrue,
            reason: '$bpm BPM intervals: $intervals',
          );
          expect(
            (total - (ideal * MetronomeWave.beatCount)).abs(),
            lessThanOrEqualTo(0.5),
            reason: '$bpm BPM',
          );
        }
      },
    );

    test('stays within the ten-minute tempo accuracy target (30-252)', () {
      for (var bpm = 30; bpm <= 252; bpm++) {
        final samplesPerBar = MetronomeWave.totalSamplesForBpm(bpm);
        final measuredBpm =
            60 *
            MetronomeWave.sampleRate *
            MetronomeWave.beatCount /
            samplesPerBar;
        final relativeError = (measuredBpm - bpm).abs() / bpm;
        expect(
          relativeError,
          lessThan(0.0005),
          reason: '$bpm BPM measured as $measuredBpm',
        );
      }
    });

    test('writes exact PCM length and leaves a silent loop seam', () {
      for (final bpm in [30, 40, 80, 120, 180, 240, 252]) {
        final wave = MetronomeWave.create(bpm);
        final sampleCount = MetronomeWave.totalSamplesForBpm(bpm);
        expect(wave.length, 44 + sampleCount * 2);

        final pcm = ByteData.sublistView(wave, 44);
        final seamSamples = math.min(512, sampleCount);
        for (
          var index = sampleCount - seamSamples;
          index < sampleCount;
          index++
        ) {
          expect(pcm.getInt16(index * 2, Endian.little), 0);
        }
      }
    });

    test('generates valid single-click percussive wave', () {
      final clickWave = MetronomeWave.createClick();
      expect(clickWave.length, greaterThan(44));
      // Verify valid WAV RIFF header
      expect(String.fromCharCodes(clickWave.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(clickWave.sublist(8, 12)), 'WAVE');
      expect(String.fromCharCodes(clickWave.sublist(12, 16)), 'fmt ');
      expect(String.fromCharCodes(clickWave.sublist(36, 40)), 'data');
    });

    test('generates seamless reference tone for Sound Out mode', () {
      final toneWave = MetronomeWave.createTone(440);
      expect(toneWave.length, greaterThan(44));
      expect(String.fromCharCodes(toneWave.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(toneWave.sublist(8, 12)), 'WAVE');
      final pcm = ByteData.sublistView(toneWave, 44);
      final sampleCount = (toneWave.length - 44) ~/ 2;
      // First sample should be close to zero (sine wave starts at 0)
      expect(pcm.getInt16(0, Endian.little).abs(), lessThan(50));
      // End sample before zero-crossing is within 1 sample step of sine fundamental
      expect(
        pcm.getInt16((sampleCount - 1) * 2, Endian.little).abs(),
        lessThan(2000),
      );
    });

    test('preserves the four-beat accent phase after a tempo swap', () {
      final wave = MetronomeWave.create(120, startingBeat: 1);
      final pcm = ByteData.sublistView(wave, 44);
      final offsets = MetronomeWave.beatSampleOffsets(120);
      final energies = <int>[];

      for (final start in offsets) {
        var energy = 0;
        for (var index = 0; index < 1920; index++) {
          energy += pcm.getInt16((start + index) * 2, Endian.little).abs();
        }
        energies.add(energy);
      }

      expect(energies.indexOf(energies.reduce(math.max)), 3);
    });
  });
}
