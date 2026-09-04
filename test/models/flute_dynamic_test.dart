import 'package:flutter_test/flutter_test.dart';
import 'package:flute/models/flute_dynamic.dart';

void main() {
  group('FluteDynamic Classification', () {
    test('classifies quiet room / silence as ambient', () {
      expect(FluteDynamic.fromDecibels(0.0), FluteDynamic.ambient);
      expect(FluteDynamic.fromDecibels(35.0), FluteDynamic.ambient);
      expect(FluteDynamic.fromDecibels(47.9), FluteDynamic.ambient);
    });

    test('classifies ppp (48 - 56 dB)', () {
      expect(FluteDynamic.fromDecibels(48.0), FluteDynamic.ppp);
      expect(FluteDynamic.fromDecibels(52.5), FluteDynamic.ppp);
      expect(FluteDynamic.fromDecibels(55.9), FluteDynamic.ppp);
      expect(FluteDynamic.ppp.symbol, 'ppp');
      expect(FluteDynamic.ppp.minDb, 48.0);
      expect(FluteDynamic.ppp.maxDb, 56.0);
    });

    test('classifies pp (56 - 63 dB)', () {
      expect(FluteDynamic.fromDecibels(56.0), FluteDynamic.pp);
      expect(FluteDynamic.fromDecibels(60.0), FluteDynamic.pp);
      expect(FluteDynamic.fromDecibels(62.9), FluteDynamic.pp);
      expect(FluteDynamic.pp.symbol, 'pp');
    });

    test('classifies p (63 - 70 dB)', () {
      expect(FluteDynamic.fromDecibels(63.0), FluteDynamic.p);
      expect(FluteDynamic.fromDecibels(66.5), FluteDynamic.p);
      expect(FluteDynamic.fromDecibels(69.9), FluteDynamic.p);
      expect(FluteDynamic.p.symbol, 'p');
    });

    test('classifies mp (70 - 76 dB)', () {
      expect(FluteDynamic.fromDecibels(70.0), FluteDynamic.mp);
      expect(FluteDynamic.fromDecibels(73.0), FluteDynamic.mp);
      expect(FluteDynamic.fromDecibels(75.9), FluteDynamic.mp);
      expect(FluteDynamic.mp.symbol, 'mp');
    });

    test('classifies mf (76 - 82 dB)', () {
      expect(FluteDynamic.fromDecibels(76.0), FluteDynamic.mf);
      expect(FluteDynamic.fromDecibels(79.0), FluteDynamic.mf);
      expect(FluteDynamic.fromDecibels(81.9), FluteDynamic.mf);
      expect(FluteDynamic.mf.symbol, 'mf');
    });

    test('classifies f (82 - 88 dB)', () {
      expect(FluteDynamic.fromDecibels(82.0), FluteDynamic.f);
      expect(FluteDynamic.fromDecibels(85.0), FluteDynamic.f);
      expect(FluteDynamic.fromDecibels(87.9), FluteDynamic.f);
      expect(FluteDynamic.f.symbol, 'f');
    });

    test('classifies ff (88 - 94 dB)', () {
      expect(FluteDynamic.fromDecibels(88.0), FluteDynamic.ff);
      expect(FluteDynamic.fromDecibels(91.0), FluteDynamic.ff);
      expect(FluteDynamic.fromDecibels(93.9), FluteDynamic.ff);
      expect(FluteDynamic.ff.symbol, 'ff');
    });

    test('classifies fff (>= 94 dB)', () {
      expect(FluteDynamic.fromDecibels(94.0), FluteDynamic.fff);
      expect(FluteDynamic.fromDecibels(98.0), FluteDynamic.fff);
      expect(FluteDynamic.fromDecibels(110.0), FluteDynamic.fff);
      expect(FluteDynamic.fff.symbol, 'fff');
    });
  });

  group('FluteDynamicReading', () {
    test('computes normalizedLevel and peak correctly', () {
      const reading = FluteDynamicReading(
        decibels: 76.0,
        smoothedDecibels: 76.0,
        peakDecibels: 82.0,
        dynamic: FluteDynamic.mf,
      );

      expect(reading.isAudible, isTrue);
      expect(reading.dynamic, FluteDynamic.mf);
      expect(reading.normalizedLevel, closeTo(0.6206, 0.01));
      expect(reading.normalizedPeak, closeTo(0.7241, 0.01));
    });

    test('ambient reading is marked as not audible', () {
      const ambientReading = FluteDynamicReading(
        decibels: 35.0,
        smoothedDecibels: 35.0,
        peakDecibels: 38.0,
        dynamic: FluteDynamic.ambient,
      );

      expect(ambientReading.isAudible, isFalse);
      expect(ambientReading.normalizedLevel, 0.0);
    });
  });
}
