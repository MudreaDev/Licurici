import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('anotimpurile lunilor', () {
    expect(seasonOf(0), 0); // ianuarie — iarna
    expect(seasonOf(2), 1); // martie — primăvara
    expect(seasonOf(6), 2); // iulie — vara
    expect(seasonOf(9), 3); // octombrie — toamna
    expect(seasonOf(11), 0); // decembrie — iarna
  });

  test('răspunsul e mereu cel din locul gol al benzii', () {
    for (final tier in [1, 3, 5, 6, 9]) {
      for (var seed = 0; seed < 20; seed++) {
        final ctx = GameContext(difficulty: Difficulty(tier), grade: Grade.parseCodes('1').first, random: Random(seed));
        for (final r in const CalendarGame().generate(ctx).rounds) {
          final strip = r.visuals.single as StripVisual;
          final right = r.choices.singleWhere((c) => c.correct);
          if (strip.missing case final m?) {
            expect(right.label, strip.labels[m], reason: r.prompt);
          } else {
            expect(right.label, seasons[seasonOf(months.indexOf(strip.labels.single))].$1);
          }
        }
      }
    }
  });

  test('„ieri” și „mâine” se citesc din ziua de azi', () {
    final ctx = GameContext(difficulty: Difficulty(5), grade: Grade.parseCodes('1').first, random: Random(3));
    final rounds = const CalendarGame().generate(ctx).rounds.where((r) => r.prompt.startsWith('Azi e'));
    expect(rounds, isNotEmpty);
    for (final r in rounds) {
      final strip = r.visuals.single as StripVisual;
      final today = weekDays.indexOf(strip.labels[1]);
      final right = r.choices.singleWhere((c) => c.correct).label!;
      expect(right, r.prompt.contains('ieri') ? weekDays[(today + 6) % 7] : weekDays[(today + 1) % 7]);
    }
  });
}
