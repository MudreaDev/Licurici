import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('episoadele: fiecare oprire are grupe, iar fiecare lucru merge într-o grupă existentă', () {
    for (final e in exploreEpisodes) {
      expect(e.stops.length, inInclusiveRange(3, 4), reason: e.id);
      expect({for (final s in e.stops) s.id}, hasLength(e.stops.length), reason: 'opriri duplicate');
      for (final s in e.stops) {
        final bins = {for (final b in s.bins) b.id};
        expect(bins.length, greaterThanOrEqualTo(2));
        for (final (emoji, bin) in s.items) {
          expect(bins, contains(bin), reason: '${e.id}/${s.id}: $emoji');
        }
        // Fiecare grupă primește cel puțin un lucru; niciun lucru de două ori.
        expect({for (final i in s.items) i.$2}, bins);
        expect({for (final i in s.items) i.$1}, hasLength(s.items.length));
        expect(s.x, inInclusiveRange(0, 1));
        expect(s.y, inInclusiveRange(0, 1));
      }
    }
  });

  test('sortarea unei opriri: aceleași lucruri, amestecate din seed; se înregistrează pe treapta episodului', () {
    final e = exploreEpisodeById('explorare-viata')!;
    final stop = e.stops.first;
    final a = e.levelFor(stop, seed: 1), b = e.levelFor(stop, seed: 1);
    expect(a.items.map((i) => i.emoji), b.items.map((i) => i.emoji));
    expect(a.items.map((i) => i.emoji).toSet(), stop.items.map((i) => i.$1).toSet());
    expect([for (final (i, it) in a.items.indexed) it.index == i].every((x) => x), isTrue);
    expect(a.gameId, e.id);
    expect(stepFor(e.id), 'AUT6');
  });

  test('în catalog: fiecare episod cu ruta lui', () {
    for (final e in exploreEpisodes) {
      final entry = catalog.singleWhere((c) => c.id == e.id);
      expect(entry.kind, GameKind.explore);
      expect(entry.route, '/exploreaza/${e.id}');
    }
  });
}
