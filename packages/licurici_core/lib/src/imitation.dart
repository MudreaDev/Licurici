/// Fă ca Licurici (IMI1–3, catalog #6): Licurici face ceva pe ecran (atinge un obiect, care
/// sare; sau îl duce în coș), apoi copilul repetă. Imitația motorie cu model — una dintre
/// primele abilități lucrate în terapie. Nivelurile sunt generate din seed (ADR-027):
/// numărul de obiecte (2 → 5), numărul de acțiuni (1 → 3), tipul (atingere → tragere).
library;

import 'dart:math';

import 'grades.dart';

enum ImitationKind {
  /// Atinge obiectul (sare).
  tap,

  /// Trage obiectul în coș.
  drag,
}

class ImitationAction {
  const ImitationAction(this.kind, this.target);

  final ImitationKind kind;

  /// Indexul obiectului din scenă.
  final int target;

  String get id => '${kind.name}-$target';

  @override
  bool operator ==(Object other) =>
      other is ImitationAction && other.kind == kind && other.target == target;

  @override
  int get hashCode => Object.hash(kind, target);
}

class ImitationAxes {
  const ImitationAxes({required this.objects, required this.actions, required this.drag});

  final int objects;
  final int actions;

  /// Apar și tragerile în coș.
  final bool drag;

  Map<String, Object> toJson() => {'objects': objects, 'actions': actions, 'drag': drag};
}

class ImitationRound {
  const ImitationRound({required this.objects, required this.actions});

  /// Obiectele din scenă, de la stânga la dreapta.
  final List<String> objects;

  /// Ce face Licurici (și ce trebuie repetat), în ordine.
  final List<ImitationAction> actions;
}

class ImitationLevel {
  const ImitationLevel({
    required this.gameId,
    required this.level,
    required this.seed,
    required this.axes,
    required this.rounds,
  });

  final String gameId;
  final int level;
  final int seed;
  final ImitationAxes axes;
  final List<ImitationRound> rounds;

  bool get hasBasket => rounds.any((r) => r.actions.any((a) => a.kind == ImitationKind.drag));

  Set<String> get art => {
        for (final r in rounds) ...r.objects,
        if (hasBasket) imitationBasket,
      };
}

const imitationBasket = '🧺';

/// Obiecte prietenoase, ușor de deosebit (cu ilustrații pictate).
const imitationObjects = ['🐶', '🐱', '🐇', '🐻', '🐥', '⚽', '🎈', '🧸', '🍎', '🌸', '⭐', '🚗'];

/// Cum a repetat copilul o rundă.
class ImitationAttempt {
  const ImitationAttempt(this.round, {this.wrong = 0, this.firstWrong, this.modelRepeated = false, this.startMs});

  final ImitationRound round;

  /// Acțiuni greșite (alt obiect sau altă acțiune).
  final int wrong;

  /// Prima acțiune greșită (ex. `tap-2`) — ce a făcut în loc.
  final String? firstWrong;

  /// Licurici a arătat din nou (model repetat → ajutor P4).
  final bool modelRepeated;

  /// Latența de pornire: de la „Rândul tău” până la prima acțiune.
  final int? startMs;

  bool get clean => wrong == 0;
}

class ImitationResult {
  ImitationResult(this.level, List<ImitationAttempt> attempts)
      : attempts = List.unmodifiable(attempts);

  final ImitationLevel level;
  final List<ImitationAttempt> attempts;

  double get accuracy =>
      attempts.isEmpty ? 0 : attempts.where((a) => a.clean).length / attempts.length;

  int get stars => accuracy >= 0.85 ? 3 : (accuracy >= 0.6 ? 2 : 1);

  int suggestedNextLevel(int current) {
    if (accuracy == 1) return current + 1;
    if (accuracy < 0.5) return max(1, current - 1);
    return current;
  }
}

/// Repetarea în curs a unei runde: verifică fiecare acțiune a copilului față de model.
class ImitationCheck {
  ImitationCheck(this.round);

  final ImitationRound round;
  int _next = 0;
  int wrong = 0;
  int _wrongHere = 0;
  String? firstWrong;

  int get done => _next;
  bool get complete => _next >= round.actions.length;
  ImitationAction? get expected => complete ? null : round.actions[_next];

  /// Greșeli consecutive la pasul curent (după două, Licurici arată din nou).
  int get wrongHere => _wrongHere;

  /// Copilul a făcut [action]. Întoarce true dacă era cea așteptată.
  bool perform(ImitationAction action) {
    if (complete) return false;
    if (action == round.actions[_next]) {
      _next++;
      _wrongHere = 0;
      return true;
    }
    wrong++;
    _wrongHere++;
    firstWrong ??= action.id;
    return false;
  }
}

class ImitationGame {
  const ImitationGame();

  String get id => 'fa-ca-licuriciul';
  String get name => 'Fă ca Licurici';
  String get emoji => '🙌';
  String get description => 'Privește și fă la fel';
  Set<Grade> get grades => Grade.parseCodes('G1');
  List<String> get steps => const ['IMI1', 'IMI2', 'IMI3'];

  ImitationAxes axesFor(int level) => ImitationAxes(
        objects: min(5, 2 + (level - 1) ~/ 2),
        actions: level <= 3 ? 1 : (level <= 7 ? 2 : 3),
        drag: level >= 3,
      );

  ImitationLevel generate(int level, {int? seed}) {
    if (level < 1) throw ArgumentError.value(level, 'level', 'începe de la 1');
    final s = seed ?? Random().nextInt(1 << 31);
    final random = Random(s);
    final axes = axesFor(level);
    final rounds = <ImitationRound>[];
    for (var r = 0; r < 4; r++) {
      final objects = ([...imitationObjects]..shuffle(random)).take(axes.objects).toList();
      final actions = <ImitationAction>[];
      final dragged = <int>{};
      for (var a = 0; a < axes.actions; a++) {
        // Nu de două ori la rând același obiect; un obiect dus în coș nu mai e în scenă.
        final free = [
          for (var i = 0; i < objects.length; i++)
            if (!dragged.contains(i) && (actions.isEmpty || actions.last.target != i)) i,
        ];
        final target = free[random.nextInt(free.length)];
        // Cu tragere: cam o acțiune din trei e o tragere (prima rundă a nivelului 3: tragere).
        final drag = axes.drag && (level == 3 && r == 0 && a == 0 || random.nextInt(3) == 0);
        if (drag) dragged.add(target);
        actions.add(ImitationAction(drag ? ImitationKind.drag : ImitationKind.tap, target));
      }
      rounds.add(ImitationRound(objects: objects, actions: actions));
    }
    return ImitationLevel(gameId: id, level: level, seed: s, axes: axes, rounds: rounds);
  }
}
