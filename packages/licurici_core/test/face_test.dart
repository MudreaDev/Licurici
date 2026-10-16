import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  group('FaceSpec', () {
    test('textul stimulului se citește înapoi la aceeași față', () {
      final r = Random(1);
      for (var i = 0; i < 200; i++) {
        final f = FaceSpec(FaceLook.anyRandom(r), FaceEmotion.values[i % FaceEmotion.values.length], (i % 101) / 100);
        final back = FaceSpec.parse(f.art)!;
        expect(back.look, f.look);
        expect(back.emotion, f.emotion);
        expect(back.intensity, closeTo(f.intensity, 0.005));
        expect(back.art, f.art);
      }
      expect(FaceSpec.parse('🐶'), isNull);
      expect(FaceSpec.parse('face:nimic:00000:50'), isNull);
    });

    test('intensitatea 0 = față neutră, 1 = emoția întreagă; crește monoton', () {
      for (final e in FaceEmotion.values) {
        final zero = FaceShape.at(e, 0), full = FaceShape.at(e, 1), target = FaceShape.of(e);
        expect(zero.mouthCurve, FaceShape.neutral.mouthCurve);
        expect(zero.browTilt, FaceShape.neutral.browTilt);
        expect(full.mouthCurve, closeTo(target.mouthCurve, 1e-9));
        expect(full.eyeOpen, closeTo(target.eyeOpen, 1e-9));
        var prev = 0.0;
        for (var i = 0; i <= 10; i++) {
          final s = FaceShape.at(e, i / 10);
          final dist = (s.mouthCurve - zero.mouthCurve).abs() + (s.browTilt - zero.browTilt).abs() + (s.eyeOpen - zero.eyeOpen).abs();
          expect(dist, greaterThanOrEqualTo(prev - 1e-9));
          prev = dist;
        }
      }
    });

    test('emoțiile au forme distincte (altfel nu s-ar putea recunoaște)', () {
      final shapes = [for (final e in FaceEmotion.values) FaceShape.of(e)];
      for (var i = 0; i < shapes.length; i++) {
        for (var j = i + 1; j < shapes.length; j++) {
          final a = shapes[i], b = shapes[j];
          final d = (a.mouthCurve - b.mouthCurve).abs() + (a.mouthOpen - b.mouthOpen).abs() + (a.browTilt - b.browTilt).abs() + (a.eyeOpen - b.eyeOpen).abs();
          expect(d, greaterThan(0.3), reason: '${FaceEmotion.values[i]} ~ ${FaceEmotion.values[j]}');
        }
      }
    });

    test('distinctFaces: identități diferite, aceeași emoție, determinist', () {
      final a = distinctFaces(Random(5), FaceEmotion.trist, 12);
      final b = distinctFaces(Random(5), FaceEmotion.trist, 12);
      expect(a.map((f) => f.art), b.map((f) => f.art));
      // Cel mult câți copii pictați sunt.
      expect(a.map((f) => f.look).toSet(), hasLength(paintedLooks.length));
      expect(a.every((f) => f.emotion == FaceEmotion.trist && f.intensity >= 0.75), isTrue);
    });
  });

  group('jocurile de sortare', () {
    test('fiecare are cel puțin 4 grupe cu cel puțin 4 lucruri (nivelul maxim: 4 × 4)', () {
      for (final g in sortGames) {
        expect(g.categories.length, greaterThanOrEqualTo(4), reason: g.id);
        for (final b in g.categories) {
          expect(b.items.toSet().length, greaterThanOrEqualTo(4), reason: '${g.id}/${b.id}');
        }
        final ids = [for (final b in g.categories) ...b.items];
        expect(ids.toSet().length, ids.length, reason: '${g.id}: un lucru în două grupe');
        final top = g.generate(20, seed: 3);
        expect(top.items, hasLength(16));
      }
    });

    test('„Sortăm emoțiile”: fețele furioase pot fi evitate', () {
      final avoid = avoidedEmojis(['fete-furioase']);
      final level = generateAvoiding((seed) => sortEmotions.generate(12, seed: seed), (l) => l.art, avoid, seed: 1);
      expect(level, isNotNull);
      expect(level!.art.any((a) => a.contains('suparat') || a == '😠'), isFalse);
    });

    test('fiecare joc nou e legat de treapta lui', () {
      expect(stepsForGame('sortam-emotiile').map((s) => s.id), ['EMO2']);
      expect(stepsForGame('la-locul-lui').map((s) => s.id), ['COG3']);
    });
  });
}
