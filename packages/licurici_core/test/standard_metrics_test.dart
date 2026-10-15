import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

Trial _t(String game, {bool correct = true, String? stim, String? target, int? latency, double? difficulty, int? level, int attempts = 1}) => Trial(
  stepId: 'X',
  gameId: game,
  correct: correct,
  promptLevel: PromptLevel.p0,
  at: DateTime.utc(2026, 10, 16),
  stimulusId: stim,
  targetId: target,
  latencyMs: latency,
  difficulty: difficulty,
  level: level,
  attempts: attempts,
);

StandardMetric _one(List<Trial> ts) => standardMetrics(ts).single;

void main() {
  test('Linia numerelor: PAE medie', () {
    final m = _one([_t('linia-numerelor', stim: 'eroare-10'), _t('linia-numerelor', stim: 'eroare-20'), _t('linia-numerelor', stim: 'eroare-0')]);
    expect(m.raw, closeTo(0.1, 1e-9));
    expect(m.value, '10%');
    expect(m.higherIsBetter, isFalse);
  });

  test('Atinge rapid: throughput = ID / MT', () {
    final m = _one([for (var i = 0; i < 5; i++) _t('atinge-rapid', difficulty: 2, latency: 1000)]);
    expect(m.raw, closeTo(2, 1e-9));
    expect(m.value, '2,0 biți/s');
  });

  test('Stop!: SSRT = RT median − SSD medie; rata de oprire', () {
    final m = _one([
      for (final rt in [500, 600, 700, 650, 550]) _t('stop', stim: 'go', latency: rt),
      _t('stop', stim: 'stop', difficulty: 250),
      _t('stop', stim: 'stop', difficulty: 350, correct: false),
      _t('stop', stim: 'stop', difficulty: 300),
    ]);
    expect(m.raw, closeTo(300, 1e-9));
    expect(m.value, contains('67%'));
  });

  test('Paznicul farului: prima jumătate vs a doua', () {
    final m = _one([
      for (var i = 0; i < 5; i++) _t('paznicul-farului', target: 'atinge'),
      for (var i = 0; i < 5; i++) _t('paznicul-farului', target: 'atinge', correct: i < 3),
      _t('paznicul-farului', target: 'nu-atinge'),
    ]);
    expect(m.value, '100% → 60%');
    expect(m.raw, closeTo(-0.4, 1e-9));
  });

  test('Cât de tare?: pragul = diferența celui mai greu nivel stăpânit', () {
    final m = _one([
      for (var i = 0; i < 4; i++) _t('cat-de-tare', level: 3),
      for (var i = 0; i < 4; i++) _t('cat-de-tare', level: 5, correct: i == 0),
    ]);
    expect(m.raw, CatDeTareGame.gapFor(3));
  });

  test('Câte sunt?: subitizarea se oprește la prima cantitate greșită', () {
    final m = _one([
      for (final n in [1, 2, 3, 4]) ...[_t('cate-sunt', stim: 'n-$n'), _t('cate-sunt', stim: 'n-$n')],
      _t('cate-sunt', stim: 'n-5', correct: false),
      _t('cate-sunt', stim: 'n-5', correct: false),
    ]);
    expect(m.value, 'până la 4');
  });

  test('Acum sau mai mult?, Ce ai auzit?, Cine e prietenul?; jocurile fără metrică nu apar', () {
    final ms = standardMetrics([
      _t('acum-sau-mai-mult', difficulty: 12),
      _t('acum-sau-mai-mult', correct: false, difficulty: 15),
      for (var i = 0; i < 4; i++) _t('ce-ai-auzit', level: 4, correct: i > 0),
      for (var i = 0; i < 4; i++) _t('cine-e-prietenul', level: 6),
      _t('potriveste'),
    ]);
    expect(ms.map((m) => m.gameId), unorderedEquals(['acum-sau-mai-mult', 'ce-ai-auzit', 'cine-e-prietenul']));
    expect(ms.firstWhere((m) => m.gameId == 'acum-sau-mai-mult').value, 'a așteptat 50%, cel mult 12 s');
    expect(ms.firstWhere((m) => m.gameId == 'ce-ai-auzit').raw, 0.75);
    expect(ms.firstWhere((m) => m.gameId == 'cine-e-prietenul').value, 'nivelul 6');
  });

  test('prea puține încercări: nicio metrică', () {
    expect(standardMetrics([_t('linia-numerelor', stim: 'eroare-5')]), isEmpty);
  });
}
