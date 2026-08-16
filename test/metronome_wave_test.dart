import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flute/services/metronome_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MetronomeWave', () {
    test('uses sample-balanced beat intervals at every supported BPM', () {
      for (var bpm = 40; bpm <= 240; bpm++) {
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
            (interval) => interval == ideal.floor() || interval == ideal.ceil(),
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
    });

    test('stays within the ten-minute tempo accuracy target', () {
      for (var bpm = 40; bpm <= 240; bpm++) {
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
      for (final bpm in [40, 80, 120, 180, 240]) {
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
