/// Jocurile cu fețe desenate din cod (`face.dart`) și metrici standard (plan §4, jocurile
/// măsurabile din README §0.1): pragul de recunoaștere a intensității unei emoții și
/// recunoașterea aceleiași persoane când i se schimbă expresia.
library;

import '../face.dart';
import '../game.dart';
import '../grades.dart';

/// Emoțiile care se pot compara ca „mai tare / mai încet” (și cum se întreabă).
const _strength = {
  FaceEmotion.bucuros: 'Cine e cel mai bucuros?',
  FaceEmotion.trist: 'Cine e cel mai trist?',
  FaceEmotion.suparat: 'Cine e cel mai supărat?',
  FaceEmotion.surprins: 'Cine e cel mai surprins?',
  FaceEmotion.speriat: 'Cine e cel mai speriat?',
};

/// Cât de tare? (EMO2): aceeași persoană, aceeași emoție, la intensități diferite; copilul alege
/// expresia cea mai puternică. Diferența dintre intensități scade cu tier-ul (de la 0,4 la
/// 0,1) — ca într-o procedură „în scară”, nivelul la care copilul nu mai reușește dă **pragul**
/// lui de recunoaștere a emoției (aceeași idee ca în studiile cu fețe „morfate”). Bucuros și
/// trist la început; supărat, surprins și speriat de la tier 3.
class CatDeTareGame extends ChoiceGame {
  const CatDeTareGame()
      : super(
          id: 'cat-de-tare',
          name: 'Cât de tare?',
          emoji: '😄',
          description: 'Alege fața cu emoția cea mai puternică',
          subject: Subject.emotii,
          gradeCodes: 'G1234',
        );

  /// Diferența de intensitate dintre variante la [tier] (1 → 0,4; 7 → 0,1).
  static double gapFor(int tier) => (0.45 - 0.05 * tier).clamp(0.1, 0.4);

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    final emotions = [
      FaceEmotion.bucuros,
      FaceEmotion.trist,
      if (tier >= 3) ...[FaceEmotion.suparat, FaceEmotion.surprins, FaceEmotion.speriat],
    ];
    final gap = gapFor(tier);
    return Lesson(
      title: name,
      instruction: 'Uită-te bine la fețe.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, ctx.pick(emotions), gap)],
    );
  }

  ChoiceRound _round(GameContext ctx, FaceEmotion e, double gap) {
    final look = FaceLook.random(ctx.random);
    // Cea mai puternică are 0,9–1; celelalte câte un „pas” mai jos (cel puțin 0,15: încă se vede).
    final top = 0.9 + 0.1 * ctx.random.nextDouble();
    final n = ctx.difficulty.optionCount;
    final faces = [
      for (var k = 0; k < n; k++) FaceSpec(look, e, (top - gap * k).clamp(0.15, 1.0)),
    ];
    final question = _strength[e]!;
    return ChoiceRound(
      prompt: question,
      hint: 'Uită-te la gură și la sprâncene.',
      // Variantele sunt deja câte trebuie; ordinea pe ecran e amestecată.
      fixedChoices: true,
      choices: [
        for (final (k, f) in faces.indexed)
          Choice(art: f.art, id: 'nivel-$k', correct: k == 0),
      ]..shuffle(ctx.random),
    );
  }
}

/// Cine e prietenul? (EMO2, recunoașterea feței): Licurici arată un copil („Acesta e Matei.”);
/// copilul îl găsește printre alți copii, **cu altă expresie** decât în poză — ca în testele de
/// potrivire a fețelor (aceeași persoană, altă expresie). Axe: câte variante (motorul) și cât de
/// mult seamănă ceilalți copii cu el (la tier mic diferă prin multe trăsături — păr, ten,
/// coafură; la tier mare doar prin una sau două).
class CineEPrietenulGame extends ChoiceGame {
  const CineEPrietenulGame()
      : super(
          id: 'cine-e-prietenul',
          name: 'Cine e prietenul?',
          emoji: '🧒',
          description: 'Găsește același copil, chiar dacă are altă expresie',
          subject: Subject.emotii,
          gradeCodes: 'G1234',
        );

  static const question = 'Unde e prietenul nostru?';

  /// Câte trăsături diferă cel puțin între prieten și ceilalți, la [tier] (4 → 1).
  static int minDifferencesFor(int tier) => (5 - (tier + 1) ~/ 2).clamp(1, 4);

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    return Lesson(
      title: name,
      instruction: 'Ține minte fața prietenului.',
      rounds: [for (var i = 0; i < 8; i++) _round(ctx, tier)],
    );
  }

  ChoiceRound _round(GameContext ctx, int tier) {
    final friend = FaceLook.random(ctx.random);
    final minDiff = minDifferencesFor(tier);
    final maxDiff = tier <= 2 ? 5 : (tier <= 4 ? 3 : 2);
    final others = <FaceLook>[];
    var guard = 0;
    while (others.length < 4 && guard++ < 4000) {
      final o = FaceLook.random(ctx.random);
      final d = o.differences(friend);
      if (d < minDiff || d > maxDiff) continue;
      if (others.any((x) => x == o)) continue;
      others.add(o);
    }
    // Poza prietenului: calm sau bucuros; în variante, toți au aceeași altă expresie (doar fața
    // contează, nu expresia).
    final shown = ctx.pick([FaceEmotion.neutru, FaceEmotion.bucuros]);
    final asked = ctx.pick([
      for (final e in [FaceEmotion.bucuros, FaceEmotion.surprins, FaceEmotion.trist, FaceEmotion.neutru])
        if (e != shown) e,
    ]);
    final intensity = tier >= 5 ? 0.8 : 1.0;
    return ChoiceRound(
      prompt: question,
      speak: ['Acesta e prietenul nostru.', question],
      visuals: [EmojiVisual(FaceSpec(friend, shown).art)],
      hint: 'Uită-te la păr și la ochi.',
      choices: [
        Choice(art: FaceSpec(friend, asked, intensity).art, id: 'prietenul', correct: true),
        for (final (k, o) in others.indexed) Choice(art: FaceSpec(o, asked, intensity).art, id: 'altul-d${o.differences(friend)}-$k'),
      ],
    );
  }
}
