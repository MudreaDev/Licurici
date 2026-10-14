import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const g = StopSignalGame();

  test('opririle: exact proporția, nu la început, niciodată două la rând', () {
    for (var level = 1; level <= 12; level++) {
      for (var seed = 0; seed < 50; seed++) {
        final l = g.generate(level, seed: seed);
        expect(l.stops, hasLength(l.axes.count));
        expect(l.stops.take(3).any((s) => s), isFalse);
        for (var i = 1; i < l.stops.length; i++) {
          expect(l.stops[i] && l.stops[i - 1], isFalse);
        }
        expect(l.stops.where((s) => s).length, (l.axes.count * l.axes.stopRatio).round().clamp(1, 99));
        expect(l.gapsMs.every((x) => x >= 900 && x < 1600), isTrue);
      }
    }
    expect(g.axesFor(1).windowMs, greaterThan(g.axesFor(9).windowMs));
  });

  test('scara: oprire reușită → semnalul mai târziu; ratată → mai devreme; în limite', () {
    final s = StopStaircase(g.axesFor(1));
    expect(s.ssdMs, 250);
    s.update(stopped: true);
    expect(s.ssdMs, 300);
    s.update(stopped: false);
    s.update(stopped: false);
    expect(s.ssdMs, 200);
    for (var i = 0; i < 50; i++) {
      s.update(stopped: false);
    }
    expect(s.ssdMs, 50);
    for (var i = 0; i < 100; i++) {
      s.update(stopped: true);
    }
    expect(s.ssdMs, g.axesFor(1).windowMs - 100);
  });

  test('SSRT = RT median la verde − SSD medie; înregistrarea', () {
    final l = g.generate(2, seed: 1);
    final r = StopResult(l, const [
      StopTrial(stop: false, tapped: true, rtMs: 500),
      StopTrial(stop: false, tapped: true, rtMs: 600),
      StopTrial(stop: false, tapped: true, rtMs: 700),
      StopTrial(stop: true, tapped: false, ssdMs: 250),
      StopTrial(stop: true, tapped: true, rtMs: 450, ssdMs: 350),
    ]);
    expect(r.goRtMedian, 600);
    expect(r.meanSsd, 300);
    expect(r.ssrt, 300);
    expect(r.stopRate, 0.5);
    expect(r.accuracy, 0.8);
    final rec = SessionRecorder(childId: 'c')..stopLevel(r);
    expect(rec.trials, hasLength(5));
    expect(rec.trials.last.correct, isFalse);
    expect(rec.trials.last.difficulty, 350);
    expect(rec.trials.first.stepId, 'FEX2c');
    expect(catalogEntry('stop')!.domain, Domain.fex);
  });
}
