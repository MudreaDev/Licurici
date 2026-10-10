/// Ascultă și fă (LRC5, catalog pe arii #16, partea „instrucțiuni compuse”): Licurici spune ce
/// să atingă — „Atinge mărul, apoi mingea.” — și copilul atinge obiectele **în ordinea spusă**.
/// Exersează înțelegerea instrucțiunilor în mai mulți pași și memoria auditivă.
///
/// Nivelurile sunt generate din seed (ADR-027). Axe: câți pași (1 → 3), câte obiecte pe masă
/// (3 → 7), obiecte cunoscute → oricare, ordinea spusă invers („Înainte de minge, atinge
/// mărul.”), instrucțiunea spusă **înainte** să apară obiectele (de ținut minte).
/// O încercare = o instrucțiune; corectă = toți pașii în ordine, din prima. Ajutor: la prima
/// greșeală Licurici repetă (P2), la a doua arată pozele în ordine (P3).
/// KPI: acuratețea pe numărul de pași, erorile de ordine vs. obiectul greșit.
library;

import 'dart:math';

import 'avoid.dart' show safeWords;
import 'games/vocabular.dart' show ObjectWord;
import 'grades.dart';
import 'reaction.dart' show ramp;
import 'trial.dart' show PromptLevel;

class InstructionAxes {
  const InstructionAxes({
    required this.rounds,
    required this.steps,
    required this.objects,
    required this.familiarOnly,
    required this.reversed,
    required this.hidden,
  });

  final int rounds;

  /// Câți pași are o instrucțiune.
  final int steps;

  /// Câte obiecte sunt pe masă.
  final int objects;

  /// Doar obiecte foarte cunoscute (primele cuvinte).
  final bool familiarOnly;

  /// Uneori ordinea e spusă invers („Înainte de …”).
  final bool reversed;

  /// Obiectele apar abia după instrucțiune (trebuie ținută minte).
  final bool hidden;

  Map<String, Object> toJson() => {
    'rounds': rounds,
    'steps': steps,
    'objects': objects,
    'familiarOnly': familiarOnly,
    'reversed': reversed,
    'hidden': hidden,
  };
}

class InstructionRound {
  const InstructionRound({
    required this.index,
    required this.table,
    required this.order,
    required this.says,
    required this.speak,
    required this.reversedWording,
  });

  final int index;

  /// Obiectele de pe masă (în ordinea așezării).
  final List<ObjectWord> table;

  /// Indicii (în [table]) în ordinea în care trebuie atinse.
  final List<int> order;

  /// Ce spune Licurici (textul întreg).
  final String says;

  /// Cum se rostește: pe bucăți, cu o mică pauză între pași („Atinge mărul” · „apoi mingea”).
  final List<String> speak;

  /// Instrucțiunea pomenește întâi ce se face al doilea („Înainte de …”).
  final bool reversedWording;
}

class InstructionLevel {
  const InstructionLevel({required this.gameId, required this.level, required this.seed, required this.axes, required this.rounds});

  final String gameId;
  final int level;
  final int seed;
  final InstructionAxes axes;
  final List<InstructionRound> rounds;

  Set<String> get art => {for (final r in rounds) ...r.table.map((o) => o.emoji)};

  /// Cât stă instrucțiunea „în aer” înainte să apară obiectele (când [InstructionAxes.hidden]).
  static const holdMs = 2500;
}

class InstructionAttempt {
  const InstructionAttempt(this.round, {required this.taps, required this.prompt, this.ms});

  final InstructionRound round;

  /// Ce a atins, în ordine (inclusiv greșelile).
  final List<int> taps;
  final PromptLevel prompt;
  final int? ms;

  /// Toți pașii în ordine, fără nicio atingere greșită și fără ajutor.
  bool get clean => prompt == PromptLevel.p0 && taps.length == round.order.length && _sameOrder;

  bool get _sameOrder {
    for (var i = 0; i < round.order.length; i++) {
      if (i >= taps.length || taps[i] != round.order[i]) return false;
    }
    return true;
  }

  /// A atins un obiect cerut, dar la momentul greșit (eroare de ordine), nu un obiect străin.
  bool get orderError => taps.any((t) => round.order.contains(t)) && !_sameOrder && taps.every(round.order.contains);
}

class InstructionResult {
  InstructionResult(this.level, List<InstructionAttempt> attempts) : attempts = List.unmodifiable(attempts);

  final InstructionLevel level;
  final List<InstructionAttempt> attempts;

  double get accuracy => attempts.isEmpty ? 0 : attempts.where((a) => a.clean).length / attempts.length;
  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy >= 0.85) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

/// Lista cuvintelor legată cu „apoi”: „mărul, apoi mingea, apoi ursulețul”.
String _then(List<String> words) => words.join(', apoi ');

class InstructionGame {
  const InstructionGame();

  String get id => 'asculta-si-fa';
  String get name => 'Ascultă și fă';
  String get emoji => '👂';
  String get description => 'Atinge în ordinea spusă';
  Set<Grade> get grades => Grade.parseCodes('G1');
  List<String> get steps => const ['LRC5'];

  InstructionAxes axesFor(int level) => InstructionAxes(
    rounds: 6,
    steps: level <= 2 ? 1 : (level <= 6 ? 2 : 3),
    objects: ramp(level, 3, 7, 10).round(),
    familiarOnly: level <= 4,
    reversed: level >= 9,
    hidden: level >= 11,
  );

  /// Ce spune Licurici pentru [targets] (în ordinea atingerii).
  static String phrase(List<ObjectWord> targets, {bool reversed = false}) {
    if (targets.length == 2 && reversed) {
      // „Înainte de minge, atinge mărul.” — se aude întâi al doilea.
      return 'Înainte de ${_bare(targets[1].word)}, atinge ${targets[0].word}.';
    }
    return 'Atinge ${_then([for (final t in targets) t.word])}.';
  }

  /// Bucățile rostite pentru [targets] (fiecare are clipul ei).
  static List<String> pieces(List<ObjectWord> targets, {bool reversed = false}) {
    if (targets.length == 2 && reversed) return ['Înainte de ${_bare(targets[1].word)}', 'atinge ${targets[0].word}'];
    return ['Atinge ${targets.first.word}', for (final t in targets.skip(1)) 'apoi ${t.word}'];
  }

  /// „mingea” → „minge” după „de” (forma nearticulată).
  static String _bare(String w) {
    const bare = {
      'mărul': 'măr', 'banana': 'banană', 'căpșuna': 'căpșună', 'cireșele': 'cireșe', 'pepenele': 'pepene',
      'morcovul': 'morcov', 'pâinea': 'pâine', 'oul': 'ou', 'laptele': 'lapte', 'acadeaua': 'acadea',
      'floarea': 'floare', 'copacul': 'copac', 'frunza': 'frunză', 'soarele': 'soare', 'luna': 'lună',
      'norul': 'nor', 'curcubeul': 'curcubeu', 'steaua': 'stea', 'fulgul de nea': 'fulg de nea', 'mingea': 'minge',
      'balonul': 'balon', 'ursulețul': 'ursuleț', 'toba': 'tobă', 'cadoul': 'cadou', 'mașina': 'mașină',
      'casa': 'casă', 'cartea': 'carte', 'săpunul': 'săpun', 'șosetele': 'șosete', 'câinele': 'câine',
      'pisica': 'pisică', 'vaca': 'vacă', 'calul': 'cal', 'oaia': 'oaie', 'porcul': 'porc', 'puiul': 'pui',
      'rața': 'rață', 'cocoșul': 'cocoș', 'iepurașul': 'iepuraș', 'ursul': 'urs', 'vulpea': 'vulpe',
      'veverița': 'veveriță', 'bufnița': 'bufniță', 'girafa': 'girafă', 'zebra': 'zebră', 'elefantul': 'elefant',
      'broasca țestoasă': 'broască țestoasă', 'delfinul': 'delfin', 'fluturele': 'fluture', 'albina': 'albină',
      'omida': 'omidă',
    };
    return bare[w] ?? w;
  }

  /// [avoid]: imaginile pe care copilul nu trebuie să le vadă (`avoidedEmojis`) nu apar deloc.
  InstructionLevel generate(int level, {int? seed, Set<String> avoid = const {}}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final pool = [for (final o in safeWords(avoid)) if (!axes.familiarOnly || o.familiar) o];
    final rounds = <InstructionRound>[];
    for (var i = 0; i < axes.rounds; i++) {
      final table = ([...pool]..shuffle(random)).take(min(axes.objects, pool.length)).toList();
      // La nivelurile cu ordine inversă, o rundă din două are doi pași spuși pe dos.
      final reversed = axes.reversed && i.isEven;
      final n = reversed ? 2 : axes.steps;
      final order = ([for (var k = 0; k < table.length; k++) k]..shuffle(random)).take(n).toList();
      rounds.add(InstructionRound(
        index: i,
        table: table,
        order: order,
        says: phrase([for (final k in order) table[k]], reversed: reversed),
        speak: pieces([for (final k in order) table[k]], reversed: reversed),
        reversedWording: reversed,
      ));
    }
    return InstructionLevel(gameId: id, level: level, seed: s, axes: axes, rounds: rounds);
  }
}
