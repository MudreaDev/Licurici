import 'dart:math';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('nicio laudă nu se repetă de două ori la rând', () {
    final p = Praise(Random(1));
    var last = '';
    for (var i = 0; i < 200; i++) {
      final s = p.forCorrect();
      expect(s, isNot(last));
      expect(Praise.correct, contains(s));
      last = s;
    }
  });

  test('variate: în 30 de răspunsuri apar cel puțin 8 laude diferite', () {
    final p = Praise(Random(2));
    expect({for (var i = 0; i < 30; i++) p.forCorrect()}.length, greaterThanOrEqualTo(8));
  });

  test('cu ajutor: doar confirmare; seria de 3 din prima e numită', () {
    final p = Praise(Random(3));
    expect(Praise.helped, contains(p.forCorrect(firstTry: false, inARow: 3)));
    expect(Praise.streak, contains(p.forCorrect(inARow: 3)));
    expect(Praise.streak, contains(p.forCorrect(inARow: 6)));
    expect(Praise.correct, contains(p.forCorrect(inARow: 4)));
  });

  test('finalul și încurajarea vin din listele lor; fără „greșit”', () {
    final p = Praise(Random(4));
    expect(Praise.finish, contains(p.forFinish()));
    expect(Praise.retry, contains(p.forRetry()));
    for (final s in Praise.all) {
      expect(s.toLowerCase(), isNot(contains('greșit')));
    }
  });
}
