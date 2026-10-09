import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('plafonul oprește urcarea, fără să coboare sub 1', () {
    expect(capLevel(7, 5), 5);
    expect(capLevel(3, 5), 3);
    expect(capLevel(9, null), 9);
    expect(capLevel(0, 4), 1);
    expect(gameParams.map((p) => p.id), ['start', 'max', 'rounds']);
    expect(roundsParam.appliesTo(GameKind.choice), isTrue);
    expect(roundsParam.appliesTo(GameKind.maze), isFalse);
    expect(maxLevelParam.appliesTo(GameKind.maze), isTrue);
  });

  test('transferul: un joc nou pornește aproape de nivelul atins într-un joc de pe aceeași treaptă', () {
    final step = ladders.expand((l) => l.steps).firstWhere((s) => s.games.length >= 2);
    final [a, b, ...] = step.games;
    expect(transferredLevel(b, {a: 7}), 5);
    expect(transferredLevel(b, {a: 2}), isNull);
    expect(transferredLevel(b, const {}), isNull);
    expect(transferredLevel(b, {b: 9}), isNull); // doar frații contează
  });
}

