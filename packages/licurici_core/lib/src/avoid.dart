/// Stimuli de evitat (ADR-025, alegerea stimulilor): imagini care sperie sau tulbură copilul
/// (câinii, insectele, fețele furioase, focul…). Adultul le alege din panou sau de pe tabletă;
/// jocurile sar peste rundele care le-ar arăta. Lista e de id-uri de categorie, nu date libere.
library;

import 'game.dart';
import 'games/vocabular.dart';

class AvoidItem {
  const AvoidItem(this.id, this.label, this.emojis);

  final String id;
  final String label;

  /// Imaginile (emoji OpenMoji) care țin de categorie.
  final Set<String> emojis;
}

const avoidItems = [
  AvoidItem('caini', 'Câini', {'🐶', '🐕', '🐩', '🐺'}),
  AvoidItem('pisici', 'Pisici', {'🐱', '🐈'}),
  AvoidItem('insecte', 'Insecte și păianjeni', {'🐝', '🐛', '🐜', '🕷', '🦟', '🪰', '🐞'}),
  AvoidItem('serpi', 'Șerpi și reptile', {'🐍', '🐊', '🦎', '🦖'}),
  AvoidItem('soareci', 'Șoareci', {'🐭', '🐁', '🐀'}),
  AvoidItem('animale-mari', 'Animale mari (leu, tigru, rechin)', {'🦁', '🐯', '🦈', '🐻'}),
  AvoidItem('fete-furioase', 'Fețe furioase', {'😠', '😡', '👿', 'face:suparat'}),
  AvoidItem('fete-triste', 'Fețe triste sau care plâng', {'😢', '😭', '😞'}),
  AvoidItem('foc', 'Foc', {'🔥', '🧨'}),
  AvoidItem('apa', 'Apă multă, valuri, ploaie', {'🌊', '🌧', '⛈'}),
  AvoidItem('baloane', 'Baloane (zgomotul spargerii)', {'🎈'}),
  AvoidItem('tobe', 'Tobe și zgomote', {'🥁', '🔔', '🚨'}),
  AvoidItem('medical', 'Doctor, dinți, seringă', {'🦷', '💉', '🩺', '🏥'}),
  AvoidItem('baie', 'Baie, duș', {'🛁', '🚿'}),
];

/// Fără selectorul de variantă (U+FE0F): „🕷️” și „🕷” sunt aceeași imagine.
String _bare(String s) => s.replaceAll('️', '');

/// Toate imaginile de evitat, din id-urile alese (necunoscutele se ignoră).
Set<String> avoidedEmojis(Iterable<String> ids) {
  final chosen = ids.toSet();
  return {
    for (final item in avoidItems)
      if (chosen.contains(item.id))
        for (final e in item.emojis) _bare(e),
  };
}

bool _hits(String? text, Set<String> avoid) {
  if (text == null || avoid.isEmpty) return false;
  final t = _bare(text);
  return avoid.any(t.contains);
}

/// Imaginea (sau textul cu imagini) [art] e printre cele de evitat?
bool isAvoided(String? art, Set<String> avoid) => _hits(art, avoid);

/// Obiectele din vocabular pe care copilul le poate vedea (pentru jocurile care aleg din toate).
List<ObjectWord> safeWords(Set<String> avoid) =>
    avoid.isEmpty ? objectWords : [for (final o in objectWords) if (!_hits(o.emoji, avoid)) o];

/// Generează un nivel fără imagini de evitat, pentru mecanicile care nu sunt `choice`: încearcă
/// alte seed-uri (deterministe, dacă [seed] e dat) până când [art] nu mai arată nimic de evitat.
/// `null` dacă nu se poate — ecranul arată atunci „Hai la alt joc!”, niciodată stimulul.
L? generateAvoiding<L>(
  L Function(int? seed) generate,
  Set<String> Function(L level) art,
  Set<String> avoid, {
  int? seed,
  int tries = 40,
}) {
  for (var i = 0; i < (avoid.isEmpty ? 1 : tries); i++) {
    final level = generate(seed == null ? null : seed + i * 7919);
    if (!art(level).any((a) => _hits(a, avoid))) return level;
  }
  return null;
}

Iterable<String?> _visualTexts(Visual v) sync* {
  switch (v) {
    case EmojiVisual(:final emoji):
      yield emoji;
    case ObjectsVisual(:final groups):
      yield* groups.map((g) => g.emoji);
    case SilhouetteVisual(:final emoji):
      yield emoji;
    default:
      break;
  }
}

/// Runda ar arăta ceva de evitat (în stimul sau în variante)?
bool showsAvoided(ChoiceRound r, Set<String> avoid) {
  if (avoid.isEmpty) return false;
  return r.visuals.expand(_visualTexts).any((t) => _hits(t, avoid)) ||
      r.choices.any((c) => _hits(c.art, avoid) || _hits(c.objects?.emoji, avoid) || _hits(c.label, avoid));
}

/// Lecția fără rundele care ar arăta stimuli de evitat. Dacă nu rămâne nicio rundă, lecția e
/// goală — ecranul alege atunci altceva (nu arătăm niciodată un stimul de evitat ca „rezervă”).
Lesson withoutAvoided(Lesson lesson, Set<String> avoid) {
  if (avoid.isEmpty) return lesson;
  return Lesson(
    title: lesson.title,
    instruction: lesson.instruction,
    rounds: [for (final r in lesson.rounds) if (!showsAvoided(r, avoid)) r],
  );
}

/// Construiește lecția fără stimulii de evitat: dacă filtrul lasă prea puține runde, mai
/// generează (de cel mult [tries] ori) și completează până la numărul obișnuit de runde.
Lesson buildAvoiding(Lesson Function() build, Set<String> avoid, {int tries = 8}) {
  final first = build();
  if (avoid.isEmpty) return first;
  final want = first.rounds.length;
  final rounds = [...withoutAvoided(first, avoid).rounds];
  final seen = {for (final r in rounds) r.prompt + r.choices.map((c) => c.art ?? c.label).join()};
  for (var i = 0; i < tries && rounds.length < want; i++) {
    for (final r in withoutAvoided(build(), avoid).rounds) {
      if (rounds.length >= want) break;
      if (seen.add(r.prompt + r.choices.map((c) => c.art ?? c.label).join())) rounds.add(r);
    }
  }
  return Lesson(title: first.title, instruction: first.instruction, rounds: rounds);
}

