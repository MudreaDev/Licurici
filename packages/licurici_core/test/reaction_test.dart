import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  for (final game in reactionGames) {
    group(game.id, () {
      test('același seed → același nivel (reproductibil)', () {
        final a = game.generate(7, seed: 42);
        final b = game.generate(7, seed: 42);
        expect([for (final s in a.stimuli) '${s.kind}${s.x}${s.y}${s.gapBeforeMs}'],
            [for (final s in b.stimuli) '${s.kind}${s.x}${s.y}${s.gapBeforeMs}']);
      });

      test('pe 2000 de seed-uri și 30 de niveluri: reguli respectate', () {
        for (var level = 1; level <= 30; level++) {
          for (var seed = 0; seed < 2000 ~/ 30 + 1; seed++) {
            final l = game.generate(level, seed: seed * 31 + level);
            final ax = l.axes;
            expect(l.stimuli.length, ax.count);
            // Început cu succes: primii doi sunt „atinge”.
            expect(l.stimuli.take(2).every((s) => s.isGo), isTrue);
            // Cel mult două „nu atinge” la rând.
            var run = 0;
            for (final s in l.stimuli) {
              run = s.isGo ? 0 : run + 1;
              expect(run, lessThanOrEqualTo(2));
            }
            final noGo = l.stimuli.where((s) => !s.isGo).length;
            if (ax.noGoRatio == 0) {
              expect(noGo, 0);
            } else {
              expect(noGo, greaterThanOrEqualTo(1));
            }
            for (final s in l.stimuli) {
              // Ținta rămâne în ecran și după ce înoată.
              expect(s.x, inInclusiveRange(0.1, 0.9));
              expect(s.x + s.driftX, inInclusiveRange(0.1, 0.9));
              expect(s.y, inInclusiveRange(0.1, 0.9));
              // Siguranță: fără apariții mai rapide decât ~3/s, ținte nu prea mici.
              expect(s.gapBeforeMs + s.visibleMs, greaterThanOrEqualTo(1000));
              expect(s.size, greaterThanOrEqualTo(0.85));
            }
          }
        }
      });

      test('dificultatea crește monoton cu nivelul și se plafonează', () {
        ReactionAxes? prev;
        for (var level = 1; level <= 40; level++) {
          final ax = game.axesFor(level);
          if (prev != null) {
            expect(ax.gapMs, lessThanOrEqualTo(prev.gapMs));
            expect(ax.visibleMs, lessThanOrEqualTo(prev.visibleMs));
            expect(ax.noGoRatio, greaterThanOrEqualTo(prev.noGoRatio));
            expect(ax.similarity, greaterThanOrEqualTo(prev.similarity));
            expect(ax.count, greaterThanOrEqualTo(prev.count));
          }
          prev = ax;
        }
        expect(game.axesFor(500).toJson(), game.axesFor(40).toJson());
      });
    });
  }

  group('ReactionSummary', () {
    final level = const PescarulGame().generate(10, seed: 3);

    test('toate corecte → 3 stele, fără comisii', () {
      final responses = [
        for (final s in level.stimuli)
          ReactionResponse(index: s.index, tapped: s.isGo, reactionMs: s.isGo ? 500 : null),
      ];
      final r = ReactionSummary.score(level, responses);
      expect(r.accuracy, 1);
      expect(r.commissions, 0);
      expect(r.omissions, 0);
      expect(r.stars, 3);
      expect(r.medianRtMs, 500);
      expect(r.rtVariabilityMs, 0);
    });

    test('atinge tot → comisii = no-go; nimic → omisiuni = go; minim o stea', () {
      final goN = level.stimuli.where((s) => s.isGo).length;
      final all = ReactionSummary.score(level, [
        for (final s in level.stimuli) ReactionResponse(index: s.index, tapped: true, reactionMs: 400),
      ]);
      expect(all.commissions, level.stimuli.length - goN);
      expect(all.hits, goN);
      final none = ReactionSummary.score(level, const []);
      expect(none.omissions, goN);
      expect(none.medianRtMs, isNull);
      expect(none.stars, 1);
    });
  });

  test('nivelul următor urmează performanța și nu coboară sub 1', () {
    final level = const PescarulGame().generate(5, seed: 9);
    ReactionSummary play(bool Function(ReactionStimulus) tap) => ReactionSummary.score(level, [
          for (final s in level.stimuli) ReactionResponse(index: s.index, tapped: tap(s), reactionMs: 600),
        ]);
    expect(play((s) => s.isGo).suggestedNextLevel(5), 7);
    expect(play((s) => false).suggestedNextLevel(5), 4);
    expect(play((s) => false).suggestedNextLevel(1), 1);
    // Atinge tot: acuratețe mare pe hârtie, dar impulsiv → nu urcă.
    expect(play((s) => true).suggestedNextLevel(5), lessThanOrEqualTo(5));
  });

  test('registrul găsește jocurile după id', () {
    expect(reactionGameById('pescarul'), isA<PescarulGame>());
    expect(reactionGameById('nu-exista'), isNull);
  });
}
