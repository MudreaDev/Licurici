import 'dart:convert';
import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  var now = DateTime.utc(2026, 10, 1, 16);
  DateTime clock() => now = now.add(const Duration(seconds: 5));

  ChoiceRound emotionRound() => const EmotiiGame()
      .build(GameContext(difficulty: const Difficulty(6), grade: Grade.gradinita, random: Random(1)))
      .rounds
      .first;

  test('runda choice: corect din prima = P0; după greșeli = P2/P3, cu ținta și ce a ales', () {
    final rec = SessionRecorder(childId: 'c', clock: clock);
    final round = emotionRound();
    final wrong = round.choices.firstWhere((c) => !c.correct);
    rec.choiceRound(gameId: 'emotii', round: round, wrongAttempts: 0, guideShown: false, latencyMs: 1200);
    rec.choiceRound(
      gameId: 'emotii',
      round: round,
      wrongAttempts: 2,
      guideShown: true,
      latencyMs: 4000,
      chosenKey: wrong.key,
    );
    final t = rec.trials;
    expect(t[0].independent, isTrue);
    expect(t[0].stepId, 'EMO1');
    expect(t[1].correct, isFalse);
    expect(t[1].promptLevel, PromptLevel.p3);
    expect(t[1].attempts, 3);
    // Cheile de emoție sunt stabile (nu etichetele), deci confuziile se pot număra.
    final keys = {'fericit', 'trist', 'suparat', 'speriat', 'surprins', 'obosit', 'calm', 'mandru'};
    expect(keys, contains(t[1].targetId));
    expect(keys, contains(t[1].chosenId));
  });

  test('nivelul reaction: o încercare pe stimul; comisia e greșeală', () {
    final rec = SessionRecorder(childId: 'c', clock: clock);
    final level = const PescarulGame().generate(5, seed: 2);
    rec.reactionLevel(level, [
      for (final s in level.stimuli) ReactionResponse(index: s.index, tapped: true, reactionMs: 500),
    ]);
    expect(rec.trials, hasLength(level.stimuli.length));
    expect(rec.trials.where((t) => !t.correct).length, level.stimuli.where((s) => !s.isGo).length);
    expect(rec.trials.first.stepId, 'FEX2');
  });

  test('secvența simon: a doua vizionare contează ca ajutor', () {
    final rec = SessionRecorder(childId: 'c', clock: clock);
    final l = const SimonGame().generate(4, seed: 1);
    rec.sequence(SequenceResult(l, l.expected), secondChance: true);
    expect(rec.trials.single.correct, isTrue);
    expect(rec.trials.single.independent, isFalse);
  });

  test('close(): sesiune goală → null; altfel record complet, serializabil dus-întors', () {
    expect(SessionRecorder(childId: 'c', clock: clock).close(), isNull);
    final rec = SessionRecorder(childId: 'c', clock: clock)
      ..moodBefore = Mood.obosit
      ..moodAfter = Mood.bucuros;
    rec.choiceRound(gameId: 'emotii', round: emotionRound(), wrongAttempts: 1, guideShown: false, latencyMs: 900);
    rec.event(SessionEventKind.pause);
    final r = rec.close()!;
    expect(rec.close(), isNull);
    final back = SessionRecord.fromJson(
      (jsonDecode(jsonEncode(r.toJson())) as Map).cast<String, Object?>(),
    );
    expect(back.id, r.id);
    expect(back.moodAfter, Mood.bucuros);
    expect(back.events.single.kind, SessionEventKind.pause);
    expect(back.trials.single.promptLevel, PromptLevel.p2);
    expect(back.trials.single.at, r.trials.single.at);
    expect(SessionReport.from(back).overall.count, 1);
  });

  test('id-ul sesiunii e un UUID v4', () {
    expect(
      SessionRecorder(childId: 'c').id,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
  });
}
