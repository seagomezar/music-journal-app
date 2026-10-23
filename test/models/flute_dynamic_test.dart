import 'package:flutter_test/flutter_test.dart';
import 'package:flute/models/flute_dynamic.dart';

void main() {
  group('FluteDynamic Classification', () {
    test('classifies quiet room / silence as ambient (< 36 dB)', () {
      expect(FluteDynamic.fromDecibels(0.0), FluteDynamic.ambient);
      expect(FluteDynamic.fromDecibels(30.0), FluteDynamic.ambient);
      expect(FluteDynamic.fromDecibels(35.9), FluteDynamic.ambient);
    });

    test('classifies ppp (36 - 42 dB)', () {
      expect(FluteDynamic.fromDecibels(36.0), FluteDynamic.ppp);
      expect(FluteDynamic.fromDecibels(39.0), FluteDynamic.ppp);
      expect(FluteDynamic.fromDecibels(41.9), FluteDynamic.ppp);
      expect(FluteDynamic.ppp.symbol, 'ppp');
      expect(FluteDynamic.ppp.minDb, 36.0);
      expect(FluteDynamic.ppp.maxDb, 42.0);
    });

    test('classifies pp (42 - 48 dB)', () {
      expect(FluteDynamic.fromDecibels(42.0), FluteDynamic.pp);
      expect(FluteDynamic.fromDecibels(45.0), FluteDynamic.pp);
      expect(FluteDynamic.fromDecibels(47.9), FluteDynamic.pp);
      expect(FluteDynamic.pp.symbol, 'pp');
      expect(FluteDynamic.pp.minDb, 42.0);
      expect(FluteDynamic.pp.maxDb, 48.0);
    });

    test('classifies p (48 - 54 dB)', () {
      expect(FluteDynamic.fromDecibels(48.0), FluteDynamic.p);
      expect(FluteDynamic.fromDecibels(51.0), FluteDynamic.p);
      expect(FluteDynamic.fromDecibels(53.9), FluteDynamic.p);
      expect(FluteDynamic.p.symbol, 'p');
      expect(FluteDynamic.p.minDb, 48.0);
      expect(FluteDynamic.p.maxDb, 54.0);
    });

    test('classifies mp (54 - 60 dB)', () {
      expect(FluteDynamic.fromDecibels(54.0), FluteDynamic.mp);
      expect(FluteDynamic.fromDecibels(57.0), FluteDynamic.mp);
      expect(FluteDynamic.fromDecibels(59.9), FluteDynamic.mp);
      expect(FluteDynamic.mp.symbol, 'mp');
      expect(FluteDynamic.mp.minDb, 54.0);
      expect(FluteDynamic.mp.maxDb, 60.0);
    });

    test('classifies mf (60 - 66 dB)', () {
      expect(FluteDynamic.fromDecibels(60.0), FluteDynamic.mf);
      expect(FluteDynamic.fromDecibels(63.0), FluteDynamic.mf);
      expect(FluteDynamic.fromDecibels(65.9), FluteDynamic.mf);
      expect(FluteDynamic.mf.symbol, 'mf');
      expect(FluteDynamic.mf.minDb, 60.0);
      expect(FluteDynamic.mf.maxDb, 66.0);
    });

    test('classifies f (66 - 72 dB)', () {
      expect(FluteDynamic.fromDecibels(66.0), FluteDynamic.f);
      expect(FluteDynamic.fromDecibels(69.0), FluteDynamic.f);
      expect(FluteDynamic.fromDecibels(71.9), FluteDynamic.f);
      expect(FluteDynamic.f.symbol, 'f');
      expect(FluteDynamic.f.minDb, 66.0);
      expect(FluteDynamic.f.maxDb, 72.0);
    });

    test('classifies ff (72 - 78 dB)', () {
      expect(FluteDynamic.fromDecibels(72.0), FluteDynamic.ff);
      expect(FluteDynamic.fromDecibels(75.0), FluteDynamic.ff);
      expect(FluteDynamic.fromDecibels(77.9), FluteDynamic.ff);
      expect(FluteDynamic.ff.symbol, 'ff');
      expect(FluteDynamic.ff.minDb, 72.0);
      expect(FluteDynamic.ff.maxDb, 78.0);
    });

    test('classifies fff (>= 78 dB, where old forte started)', () {
      expect(FluteDynamic.fromDecibels(78.0), FluteDynamic.fff);
      expect(FluteDynamic.fromDecibels(84.0), FluteDynamic.fff);
      expect(FluteDynamic.fromDecibels(100.0), FluteDynamic.fff);
      expect(FluteDynamic.fff.symbol, 'fff');
      expect(FluteDynamic.fff.minDb, 78.0);
      expect(FluteDynamic.fff.maxDb, 100.0);
    });
  });

  group('FluteDynamicReading', () {
    test('computes normalizedLevel and peak correctly for 30-84 dB scale', () {
      const reading = FluteDynamicReading(
        decibels: 63.0,
        smoothedDecibels: 63.0,
        peakDecibels: 78.0,
        dynamic: FluteDynamic.mf,
      );

      expect(reading.isAudible, isTrue);
      expect(reading.dynamic, FluteDynamic.mf);
      // (63 - 30) / (84 - 30) = 33 / 54 ≈ 0.6111
      expect(reading.normalizedLevel, closeTo(0.6111, 0.01));
      // (78 - 30) / (84 - 30) = 48 / 54 ≈ 0.8889
      expect(reading.normalizedPeak, closeTo(0.8889, 0.01));
    });

    test('ambient reading is marked as not audible', () {
      const ambientReading = FluteDynamicReading(
        decibels: 32.0,
        smoothedDecibels: 32.0,
        peakDecibels: 35.0,
        dynamic: FluteDynamic.ambient,
      );

      expect(ambientReading.isAudible, isFalse);
      expect(ambientReading.normalizedLevel, closeTo(0.037, 0.01));
    });
  });
}
