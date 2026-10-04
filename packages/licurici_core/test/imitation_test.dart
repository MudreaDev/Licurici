import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  const game = ImitationGame();

  test('nivelurile: 1 acțiune pe 2 obiecte → 3 acțiuni cu tragere pe 5 obiecte', () {
    expect(game.axesFor(1).toJson(), {'objects': 2, 'actions': 1, 'drag': false});
    expect(game.axesFor(3).drag, isTrue);
    expect(game.axesFor(20).toJson(), {'objects': 5, 'actions': 3, 'drag': true});
    ImitationAxes? prev;
    for (var l = 1; l <= 30; l++) {
      final ax = game.axesFor(l);
      if (prev != null) {
        expect(ax.objects, greaterThanOrEqualTo(prev.objects));
        expect(ax.actions, greaterThanOrEqualTo(prev.actions));
      }
      prev = ax;
    }
  });

  test('rundele respectă regulile pe multe seed-uri', () {
    for (var level = 1; level <= 12; level++) {
      for (var seed = 0; seed < 40; seed++) {
        final l = game.generate(level, seed: seed);
        expect(l.rounds, hasLength(4));
        for (final r in l.rounds) {
          expect(r.objects, hasLength(l.axes.objects));
          expect(r.objects.toSet(), hasLength(r.objects.length));
          expect(r.actions, hasLength(l.axes.actions));
          final dragged = <int>{};
          for (final (i, a) in r.actions.indexed) {
            expect(a.target, inInclusiveRange(0, r.objects.length - 1));
            if (i > 0) expect(a.target, isNot(r.actions[i - 1].target));
            expect(dragged, isNot(contains(a.target)), reason: 'obiect deja dus în coș');
            if (a.kind == ImitationKind.drag) dragged.add(a.target);
          }
          if (!l.axes.drag) expect(r.actions.every((a) => a.kind == ImitationKind.tap), isTrue);
        }
      }
    }
    // Prima rundă a nivelului 3 introduce tragerea.
    expect(game.generate(3, seed: 1).rounds.first.actions.first.kind, ImitationKind.drag);
    expect(game.generate(3, seed: 1).hasBasket, isTrue);
    expect(game.generate(1, seed: 1).art, isNot(contains(imitationBasket)));
  });

  test('verificarea: în ordine e corect; greșeala se numără, apoi se poate continua', () {
    const round = ImitationRound(objects: ['🐶', '🐱', '🐇'], actions: [
      ImitationAction(ImitationKind.tap, 0),
      ImitationAction(ImitationKind.drag, 2),
    ]);
    final c = ImitationCheck(round);
    expect(c.perform(const ImitationAction(ImitationKind.tap, 1)), isFalse);
    expect(c.perform(const ImitationAction(ImitationKind.drag, 0)), isFalse);
    expect(c.wrongHere, 2);
    expect(c.firstWrong, 'tap-1');
    expect(c.perform(const ImitationAction(ImitationKind.tap, 0)), isTrue);
    expect(c.wrongHere, 0);
    expect(c.perform(const ImitationAction(ImitationKind.drag, 2)), isTrue);
    expect(c.complete, isTrue);
    expect(c.wrong, 2);
  });

  test('înregistrarea și catalogul', () {
    final level = game.generate(1, seed: 2);
    final rec = SessionRecorder(childId: 'c')
      ..imitationLevel(ImitationResult(level, [
        ImitationAttempt(level.rounds[0], startMs: 1200),
        ImitationAttempt(level.rounds[1], wrong: 2, firstWrong: 'tap-1', modelRepeated: true),
      ]));
    expect(rec.trials.first.independent, isTrue);
    expect(rec.trials.first.stepId, 'IMI1');
    expect(rec.trials.last.promptLevel, PromptLevel.p4);
    expect(catalogEntry('fa-ca-licuriciul')!.domain, Domain.imi);
  });
}
