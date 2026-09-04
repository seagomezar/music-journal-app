import 'package:flutter_test/flutter_test.dart';
import 'package:flute/models/flute_dynamic.dart';

void main() {
  group('FluteDynamic Classification', () {
    test('classifies quiet room / silence as ambient (< 38 dB)', () {
      expect(FluteDynamic.fromDecibels(0.0), FluteDynamic.ambient);
      expect(FluteDynamic.fromDecibels(30.0), FluteDynamic.ambient);
      expect(FluteDynamic.fromDecibels(37.9), FluteDynamic.ambient);
    });

    test('classifies ppp (38 - 46 dB)', () {
      expect(FluteDynamic.fromDecibels(38.0), FluteDynamic.ppp);
      expect(FluteDynamic.fromDecibels(42.0), FluteDynamic.ppp);
      expect(FluteDynamic.fromDecibels(45.9), FluteDynamic.ppp);
      expect(FluteDynamic.ppp.symbol, 'ppp');
      expect(FluteDynamic.ppp.minDb, 38.0);
      expect(FluteDynamic.ppp.maxDb, 46.0);
    });

    test('classifies pp (46 - 54 dB)', () {
      expect(FluteDynamic.fromDecibels(46.0), FluteDynamic.pp);
      expect(FluteDynamic.fromDecibels(50.0), FluteDynamic.pp);
      expect(FluteDynamic.fromDecibels(53.9), FluteDynamic.pp);
      expect(FluteDynamic.pp.symbol, 'pp');
      expect(FluteDynamic.pp.minDb, 46.0);
      expect(FluteDynamic.pp.maxDb, 54.0);
    });

    test('classifies p (54 - 62 dB)', () {
      expect(FluteDynamic.fromDecibels(54.0), FluteDynamic.p);
      expect(FluteDynamic.fromDecibels(58.0), FluteDynamic.p);
      expect(FluteDynamic.fromDecibels(61.9), FluteDynamic.p);
      expect(FluteDynamic.p.symbol, 'p');
      expect(FluteDynamic.p.minDb, 54.0);
      expect(FluteDynamic.p.maxDb, 62.0);
    });

    test('classifies mp (62 - 70 dB)', () {
      expect(FluteDynamic.fromDecibels(62.0), FluteDynamic.mp);
      expect(FluteDynamic.fromDecibels(66.0), FluteDynamic.mp);
      expect(FluteDynamic.fromDecibels(69.9), FluteDynamic.mp);
      expect(FluteDynamic.mp.symbol, 'mp');
      expect(FluteDynamic.mp.minDb, 62.0);
      expect(FluteDynamic.mp.maxDb, 70.0);
    });

    test('classifies mf (70 - 78 dB)', () {
      expect(FluteDynamic.fromDecibels(70.0), FluteDynamic.mf);
      expect(FluteDynamic.fromDecibels(74.0), FluteDynamic.mf);
      expect(FluteDynamic.fromDecibels(77.9), FluteDynamic.mf);
      expect(FluteDynamic.mf.symbol, 'mf');
      expect(FluteDynamic.mf.minDb, 70.0);
      expect(FluteDynamic.mf.maxDb, 78.0);
    });

    test('classifies f (78 - 86 dB)', () {
      expect(FluteDynamic.fromDecibels(78.0), FluteDynamic.f);
      expect(FluteDynamic.fromDecibels(82.0), FluteDynamic.f);
      expect(FluteDynamic.fromDecibels(85.9), FluteDynamic.f);
      expect(FluteDynamic.f.symbol, 'f');
      expect(FluteDynamic.f.minDb, 78.0);
      expect(FluteDynamic.f.maxDb, 86.0);
    });

    test('classifies ff (86 - 94 dB)', () {
      expect(FluteDynamic.fromDecibels(86.0), FluteDynamic.ff);
      expect(FluteDynamic.fromDecibels(90.0), FluteDynamic.ff);
      expect(FluteDynamic.fromDecibels(93.9), FluteDynamic.ff);
      expect(FluteDynamic.ff.symbol, 'ff');
      expect(FluteDynamic.ff.minDb, 86.0);
      expect(FluteDynamic.ff.maxDb, 94.0);
    });

    test('classifies fff (>= 94 dB)', () {
      expect(FluteDynamic.fromDecibels(94.0), FluteDynamic.fff);
      expect(FluteDynamic.fromDecibels(98.0), FluteDynamic.fff);
      expect(FluteDynamic.fromDecibels(110.0), FluteDynamic.fff);
      expect(FluteDynamic.fff.symbol, 'fff');
      expect(FluteDynamic.fff.minDb, 94.0);
      expect(FluteDynamic.fff.maxDb, 110.0);
    });
  });

  group('FluteDynamicReading', () {
    test('computes normalizedLevel and peak correctly for 30-100 dB scale', () {
      const reading = FluteDynamicReading(
        decibels: 76.0,
        smoothedDecibels: 76.0,
        peakDecibels: 82.0,
        dynamic: FluteDynamic.mf,
      );

      expect(reading.isAudible, isTrue);
      expect(reading.dynamic, FluteDynamic.mf);
      // (76 - 30) / (100 - 30) = 46 / 70 ≈ 0.6571
      expect(reading.normalizedLevel, closeTo(0.6571, 0.01));
      // (82 - 30) / (100 - 30) = 52 / 70 ≈ 0.7428
      expect(reading.normalizedPeak, closeTo(0.7428, 0.01));
    });

    test('ambient reading is marked as not audible', () {
      const ambientReading = FluteDynamicReading(
        decibels: 32.0,
        smoothedDecibels: 32.0,
        peakDecibels: 35.0,
        dynamic: FluteDynamic.ambient,
      );

      expect(ambientReading.isAudible, isFalse);
      expect(ambientReading.normalizedLevel, closeTo(0.028, 0.01));
    });
  });
}
