import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_dashboard/progress.dart';

SessionRecord _session(int day, String step, int ok) {
  final start = DateTime.utc(2026, 9, day, 16);
  return SessionRecord(
    id: 's$day$step',
    childId: 'c',
    start: start,
    end: start.add(const Duration(minutes: 10)),
    trials: [
      for (var i = 0; i < 10; i++)
        Trial(
          stepId: step,
          gameId: stepById(step)!.games.first,
          correct: i < ok,
          promptLevel: i < ok ? PromptLevel.p0 : PromptLevel.p3,
          at: start.add(Duration(seconds: 20 * i)),
        ),
    ],
  );
}

ChildHistory _history(List<SessionRecord> sessions) => ChildHistory(
  const ChildProfile(id: 'c', nickname: 'Test', ageYears: 6, activeSteps: ['EMO2'], masteredSteps: ['EMO1']),
  sessions,
);

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: w)));

void main() {
  testWidgets('arată treapta grea și treapta la care se întoarce drumul', (tester) async {
    await tester.pumpWidget(_wrap(StepBackNotice(_history([
      _session(1, 'EMO1', 9),
      _session(10, 'EMO2', 2),
      _session(12, 'EMO2', 1),
    ]))));
    expect(find.text('Trepte grele acum'), findsOneWidget);
    expect(find.textContaining('20%, 10%'), findsOneWidget);
    expect(find.textContaining('reia întâi EMO1'), findsOneWidget);
  });

  testWidgets('stăpânire: pe un joc „de verificat”, pe două jocuri „generalizată”', (tester) async {
    SessionRecord on(int day, String game, String set) {
      final s = _session(day, 'POT5', 9);
      return SessionRecord(
        id: '${s.id}$game',
        childId: s.childId,
        start: s.start,
        end: s.end,
        trials: [
          for (final (i, t) in s.trials.indexed)
            Trial(stepId: t.stepId, gameId: game, correct: t.correct, promptLevel: t.promptLevel, stimulusSet: '$set${i % 2}', at: t.at),
        ],
      );
    }

    await tester.pumpWidget(_wrap(MasteryPanel(_history([on(1, 'culori', 'a'), on(2, 'culori', 'a')]))));
    expect(find.textContaining('de verificat pe alt joc'), findsOneWidget);
    await tester.pumpWidget(_wrap(MasteryPanel(_history([on(1, 'culori', 'a'), on(2, 'culori', 'a'), on(3, 'forme', 'b')]))));
    expect(find.textContaining('generalizată ('), findsOneWidget);
  });

  testWidgets('nimic de arătat când totul merge', (tester) async {
    await tester.pumpWidget(_wrap(StepBackNotice(_history([_session(1, 'EMO1', 9), _session(2, 'EMO2', 8)]))));
    expect(find.text('Trepte grele acum'), findsNothing);
  });
}
