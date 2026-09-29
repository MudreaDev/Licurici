/// „Potrivește” (catalog #9, traseul POT): primul joc pe modelul nou (ADR-026, ADR-027).
/// Potrivire după model (match-to-sample): identic → neidentic → culoare → formă → categorie.
/// Nivelurile se generează din axe + seed; înglobează vechile „Culori” și „Forme” ca moduri.
library;

import 'dart:math';

import '../game.dart';
import '../grades.dart';
import '../therapy/axes.dart';
import '../therapy/exposure.dart';
import '../therapy/stimulus.dart';

/// Regula de potrivire.
enum MatchMode {
  /// Același desen (POT1–2).
  identic('Găsește obiectul la fel.', 'Uită-te bine la model.'),

  /// Același lucru, alt desen: alt câine, alt măr (POT4).
  neidentic('Găsește încă un obiect de același fel.', 'Uită-te bine la model.'),

  /// Aceeași culoare, alt obiect (POT5).
  culoare('Găsește ce are aceeași culoare.', 'Uită-te la culoare.'),

  /// Aceeași formă, altă culoare (POT5).
  forma('Găsește ce are aceeași formă.', 'Uită-te la formă.'),

  /// Același fel de lucru: animal, fruct, vehicul (POT6).
  categorie('Găsește ce face parte din aceeași grupă.', 'Gândește-te ce fel de lucru este.');

  const MatchMode(this.prompt, this.hint);

  final String prompt;

  /// Indiciul neutru (P1): spune la ce să se uite, nu care e răspunsul.
  final String hint;
}

/// Categoriile clare pentru potrivirea după categorie (fără „obiecte” sau „natură”, care sunt amestecate).
const _clearCategories = {'animale', 'fructe', 'mâncare', 'plante', 'vehicule', 'haine', 'jucării'};

class PotrivesteGenerator {
  PotrivesteGenerator([StimulusBank? bank]) : bank = bank ?? objects;

  static const id = 'potriveste';

  /// Crește la orice schimbare care modifică rundele generate din același seed.
  static const version = 1;

  /// Axele de dificultate (plan §3.5 a). Greutățile sunt estimări inițiale; se calibrează din date (S2).
  static const axes = DifficultyAxes([
    AxisSpec('variante', [2, 3, 4, 5], weight: 300, label: 'nr. variante'),
    AxisSpec('asemanare', [0, 1, 2, 3], weight: 450, label: 'asemănarea distractorilor'),
    AxisSpec('neidentic', [0, 1], weight: 250, label: 'identic / neidentic'),
  ]);

  /// Axa calitativă fixată de mod: doar potrivirea identică are același desen.
  static AxisPoint fixedFor(MatchMode mode) => {'neidentic': mode == MatchMode.identic ? 0 : 1};

  /// Treapta din traseul POT servită de o rundă.
  static String stepFor(MatchMode mode, AxisPoint point) => switch (mode) {
        MatchMode.identic => point['variante'] == 2 ? 'POT1' : 'POT2',
        MatchMode.neidentic => 'POT4',
        MatchMode.culoare || MatchMode.forma => 'POT5',
        MatchMode.categorie => 'POT6',
      };

  final StimulusBank bank;

  /// Atributele după care distractorii „seamănă” cu modelul (fără atributul regulii).
  static List<Attr> similarityAttrs(MatchMode mode) => switch (mode) {
        MatchMode.identic || MatchMode.neidentic => const [Attr.category, Attr.color, Attr.shape],
        MatchMode.culoare => const [Attr.category, Attr.shape],
        MatchMode.forma => const [Attr.color],
        MatchMode.categorie => const [Attr.color, Attr.shape],
      };

  /// Ce poate fi model (și are sigur o pereche) în [mode].
  List<Stimulus> samples(MatchMode mode) => bank.items.where((s) => _pair(mode, s).isNotEmpty).toList();

  /// Perechile corecte posibile pentru modelul [s].
  List<Stimulus> _pair(MatchMode mode, Stimulus s) => switch (mode) {
        MatchMode.identic => [s],
        MatchMode.neidentic => bank.where((o) => o.concept == s.concept && o.emoji != s.emoji).toList(),
        MatchMode.culoare => s.color == null
            ? const []
            : bank.where((o) => o.color == s.color && o.concept != s.concept).toList(),
        MatchMode.forma => s.category != 'forme'
            ? const []
            : bank
                .where((o) => o.category == 'forme' && o.shape == s.shape && o.color != s.color)
                .toList(),
        MatchMode.categorie => !_clearCategories.contains(s.category)
            ? const []
            : bank.where((o) => o.category == s.category && o.concept != s.concept).toList(),
      };

  /// Poate [d] fi distractor pentru modelul [s] (NU respectă regula)?
  bool _isDistractor(MatchMode mode, Stimulus s, Stimulus d) =>
      d.concept != s.concept &&
      switch (mode) {
        MatchMode.identic || MatchMode.neidentic => true,
        MatchMode.culoare => d.color != null && d.color != s.color,
        MatchMode.forma => d.category == 'forme' && d.shape != s.shape,
        MatchMode.categorie => _clearCategories.contains(d.category) && d.category != s.category,
      };

  /// O rundă, complet determinată de ([mode], [point], [seed]).
  ChoiceRound round(MatchMode mode, AxisPoint point, int seed) {
    final rnd = Random(seed);
    final n = point['variante']!.toInt();
    final level = point['asemanare']!.toInt();

    final pool = samples(mode);
    final sample = pool[rnd.nextInt(pool.length)];
    final pairs = _pair(mode, sample);
    final correct = pairs[rnd.nextInt(pairs.length)];

    // distractorii: cei a căror asemănare cu modelul e cât mai aproape de nivelul cerut
    final attrs = similarityAttrs(mode);
    final desired = (level * attrs.length / 3).round();
    final candidates = bank.items
        .where((d) => _isDistractor(mode, sample, d) && d.concept != correct.concept)
        .toList()
      ..shuffle(rnd);
    candidates.sort((a, b) => (a.similarity(sample, attrs) - desired)
        .abs()
        .compareTo((b.similarity(sample, attrs) - desired).abs()));
    final distractors = <Stimulus>[];
    final concepts = <String>{};
    for (final d in candidates) {
      if (distractors.length == n - 1) break;
      if (concepts.add(d.concept)) distractors.add(d);
    }

    final options = [correct, ...distractors]..shuffle(rnd);
    return ChoiceRound(
      prompt: mode.prompt,
      visuals: [EmojiVisual(sample.emoji)],
      choices: [for (final o in options) Choice(art: o.emoji, correct: identical(o, correct))],
      hint: mode.hint,
      fixedChoices: true,
      tag: RoundTag(
        generator: id,
        version: version,
        seed: seed,
        stepId: stepFor(mode, point),
        config: {'mod': mode.name},
        axes: Map.unmodifiable(point),
        difficulty: axes.difficultyOf(point),
        stimulusId: sample.id,
        stimulusSet: sample.category,
      ),
    );
  }

  /// Runda următoare dintr-o sesiune: evită combinațiile deja văzute ([history]) și ca răspunsul
  /// corect să stea a treia oară la rând pe aceeași poziție ([positions] = pozițiile anterioare).
  /// Seed-ul folosit rămâne în `tag`, deci runda se poate reproduce exact și fără istoric.
  ChoiceRound next(
    MatchMode mode,
    AxisPoint point,
    Random random, {
    ExposureHistory? history,
    List<int> positions = const [],
  }) {
    ChoiceRound? fallback;
    for (var attempt = 0; attempt < 16; attempt++) {
      final r = round(mode, point, random.nextInt(1 << 31));
      fallback ??= r;
      final pos = r.choices.indexWhere((c) => c.correct);
      final samePos = positions.length >= 2 &&
          positions[positions.length - 1] == pos &&
          positions[positions.length - 2] == pos;
      final key = keyOf(r);
      if (samePos || (history?.seen(key) ?? false)) continue;
      history?.add(key, stimuli: [for (final c in r.choices) c.art!]);
      return r;
    }
    history?.add(keyOf(fallback!), stimuli: [for (final c in fallback.choices) c.art!]);
    return fallback!;
  }

  static String keyOf(ChoiceRound r) {
    final sample = (r.visuals.single as EmojiVisual).emoji;
    return '${r.tag?.config['mod']}:${ExposureHistory.keyOf(
      sample,
      [for (final c in r.choices) if (!c.correct) c.art!],
      [for (final c in r.choices) c.art!],
    )}';
  }
}

/// Jocul în registrul actual (ecranul principal pe clase, până la paleta pe arii): tier-ul
/// vechi → mod + dificultate țintă. Pe modelul nou, rating-ul și treapta aleg nivelul.
class PotrivesteGame extends ChoiceGame {
  const PotrivesteGame()
      : super(
          id: PotrivesteGenerator.id,
          name: 'Potrivește',
          emoji: '🧩',
          description: 'Găsește perechea',
          subject: Subject.forme,
          gradeCodes: 'G1',
        );

  /// Modurile deblocate de tier (de la simplu la complex).
  static List<MatchMode> modesFor(int tier) => [
        MatchMode.identic,
        if (tier >= 2) MatchMode.neidentic,
        if (tier >= 3) MatchMode.culoare,
        if (tier >= 4) MatchMode.forma,
        if (tier >= 5) MatchMode.categorie,
      ];

  @override
  Lesson generate(GameContext ctx) {
    final gen = PotrivesteGenerator();
    final tier = ctx.difficulty.tier;
    final modes = modesFor(tier);
    const axes = PotrivesteGenerator.axes;
    final target = axes.base + 110 * (tier - 1);
    final history = ExposureHistory();
    final positions = <int>[];
    final rounds = <ChoiceRound>[];
    for (var i = 0; i < 8; i++) {
      final mode = modes[(i + ctx.random.nextInt(modes.length)) % modes.length];
      final point = axes.pointFor(target, ctx.random, fixed: PotrivesteGenerator.fixedFor(mode));
      final r = gen.next(mode, point, ctx.random, history: history, positions: positions);
      positions.add(r.choices.indexWhere((c) => c.correct));
      rounds.add(r);
    }
    return Lesson(title: name, instruction: 'Potrivește ce e la fel.', rounds: rounds);
  }
}
