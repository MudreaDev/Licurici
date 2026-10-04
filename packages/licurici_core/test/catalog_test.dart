import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('fiecare joc are o arie și un id unic', () {
    final ids = catalog.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids, containsAll(['simon', 'pescarul', 'prinde-licuriciul', 'emotii', 'adunam']));
  });

  test('grupare pe arii, în ordinea din Domain, fără arii goale', () {
    final byDomain = catalogByDomain();
    expect(byDomain.keys.toList(), [
      for (final d in Domain.values)
        if (byDomain.containsKey(d)) d,
    ]);
    expect(byDomain.values.every((l) => l.isNotEmpty), isTrue);
    expect(byDomain[Domain.fex]!.map((e) => e.id), containsAll(['simon', 'pescarul']));
    expect(byDomain[Domain.atn]!.map((e) => e.id), ['prinde-licuriciul', 'cauta']);
    expect(byDomain[Domain.pac]!.map((e) => e.id), contains('numaram'));
  });

  test('restrângerea la jocurile alocate copilului', () {
    final byDomain = catalogByDomain(only: {'emotii', 'simon'});
    expect(byDomain.keys, [Domain.emo, Domain.fex]);
  });

  test('rutele după mecanică', () {
    expect(catalogEntry('simon')!.route, '/secventa/simon');
    expect(catalogEntry('pescarul')!.route, '/reactie/pescarul');
    expect(catalogEntry('emotii')!.route, '/joc/emotii');
    expect(childLabel(Domain.emo), isNotEmpty);
  });
}
