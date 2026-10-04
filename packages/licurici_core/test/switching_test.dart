import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = SwitchGame();

  test('fiecare cartonaș seamănă cu o cutie la culoare și cu cealaltă la formă', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 50; seed++) {
        final l = game.generate(level, seed: seed);
        final t = l.targets;
        expect(t[0].color, isNot(t[1].color));
        expect(t[0].shape, isNot(t[1].shape));
        for (final it in l.items) {
          final byColor = it.card.color == t[0].color ? 0 : 1;
          final byShape = it.card.shape == t[0].shape ? 0 : 1;
          expect(byColor, isNot(byShape), reason: 'regula trebuie să conteze');
          expect(it.answer, it.rule == SortRule.color ? byColor : byShape);
        }
        // Cel mult două cartonașe identice la rând.
        for (var i = 2; i < l.items.length; i++) {
          expect(
            l.items[i].card == l.items[i - 1].card && l.items[i].card == l.items[i - 2].card,
            isFalse,
          );
        }
      }
    }
  });

  test('progresia: o regulă → o schimbare → mai multe → amestecat', () {
    expect(game.generate(1, seed: 1).switches, isEmpty);
    expect(game.generate(3, seed: 1).switches, [5]);
    expect(game.generate(5, seed: 1).switches, [4, 8]);
    for (var seed = 0; seed < 30; seed++) {
      final l = game.generate(8, seed: seed);
      expect(l.axes.mixed, isTrue);
      expect(l.switches.length, greaterThanOrEqualTo(4));
    }
    expect(game.generate(1, seed: 1).items.first.rule, SortRule.color);
  });

  test('perseverare și costul schimbării', () {
    final l = game.generate(3, seed: 2); // schimbare la 5
    final responses = [
      for (final it in l.items)
        SwitchResponse(
          it,
          // Greșește primele două după schimbare (sortează tot după culoare).
          chosen: it.index == 5 || it.index == 6 ? it.otherRuleAnswer : it.answer,
          ms: it.index == 5 ? 2000 : 800,
        ),
    ];
    final r = SwitchResult(l, responses);
    expect(r.perseverativeErrors, 2);
    expect(r.switchCostMs, 1200);
    final rec = SessionRecorder(childId: 'c')..switchLevel(r);
    expect(rec.trials.first.stepId, 'FEX4');
    expect(rec.trials[5].chosenId, 'color');
    expect(rec.trials[5].targetId, 'shape');
    expect(catalogEntry('regula-se-schimba')!.domain, Domain.fex);
  });
}
