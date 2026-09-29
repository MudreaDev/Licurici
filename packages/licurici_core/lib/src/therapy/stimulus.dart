/// Baza de stimuli cu atribute (plan §3.5 c, ADR-027): generatorul compune runde după reguli,
/// iar distractorii se aleg după cât de mult seamănă cu ținta (atribute comune).
library;

/// Atributele după care se compară doi stimuli.
enum Attr { category, color, shape }

class Stimulus {
  const Stimulus(
    this.emoji,
    this.concept,
    this.category, {
    this.color,
    this.shape,
    this.familiar = 1,
  });

  factory Stimulus.fromJson(Map<String, Object?> j) => Stimulus(
        j['emoji']! as String,
        j['concept']! as String,
        j['category']! as String,
        color: j['color'] as String?,
        shape: j['shape'] as String?,
        familiar: j['familiar'] as int? ?? 1,
      );

  /// Ilustrația (emoji → OpenMoji). Identifică stimulul.
  final String emoji;

  /// Ce ESTE (câine, măr): două desene diferite ale aceluiași concept = potrivire neidentică.
  final String concept;
  final String category;

  /// Culoarea dominantă (`null` = amestec, nu se folosește la potrivirea după culoare).
  final String? color;

  /// Forma, doar unde e evidentă (cerc, pătrat, stea…).
  final String? shape;

  /// 1 = foarte cunoscut … 3 = rar întâlnit.
  final int familiar;

  String get id => emoji;

  String? attr(Attr a) => switch (a) {
        Attr.category => category,
        Attr.color => color,
        Attr.shape => shape,
      };

  /// Câte atribute din [attrs] are în comun cu [other] (un atribut necunoscut nu e comun).
  int similarity(Stimulus other, Iterable<Attr> attrs) =>
      attrs.where((a) => attr(a) != null && attr(a) == other.attr(a)).length;

  Map<String, Object?> toJson() => {
        'emoji': emoji,
        'concept': concept,
        'category': category,
        if (color != null) 'color': color,
        if (shape != null) 'shape': shape,
        if (familiar != 1) 'familiar': familiar,
      };

  @override
  String toString() => 'Stimulus($emoji $concept)';
}

class StimulusBank {
  StimulusBank(Iterable<Stimulus> items) : items = List.unmodifiable(items) {
    final seen = <String>{};
    for (final s in this.items) {
      if (!seen.add(s.emoji)) throw ArgumentError('stimul duplicat: ${s.emoji}');
    }
  }

  final List<Stimulus> items;

  Iterable<Stimulus> where(bool Function(Stimulus) test) => items.where(test);

  /// Conceptele cu cel puțin două desene diferite (pentru potrivirea neidentică).
  Set<String> get multiDrawn {
    final count = <String, int>{};
    for (final s in items) {
      count[s.concept] = (count[s.concept] ?? 0) + 1;
    }
    return {
      for (final e in count.entries)
        if (e.value > 1) e.key,
    };
  }
}

/// Obiectele (ilustrații OpenMoji incluse în aplicație), adnotate cu atribute. Culorile sunt cele
/// dominante în desenul OpenMoji; unde desenul e amestecat, culoarea lipsește intenționat.
/// Următorul pas: mutare în JSON (`game_content`), cu atribute propuse de AI și verificate de om.
final objects = StimulusBank(const [
  // animale
  Stimulus('🐶', 'câine', 'animale', color: 'maro'),
  Stimulus('🐱', 'pisică', 'animale', color: 'portocaliu'),
  Stimulus('🐭', 'șoarece', 'animale', color: 'gri'),
  Stimulus('🐰', 'iepure', 'animale', color: 'alb'),
  Stimulus('🐇', 'iepure', 'animale', color: 'alb'),
  Stimulus('🐴', 'cal', 'animale', color: 'maro'),
  Stimulus('🐎', 'cal', 'animale', color: 'maro'),
  Stimulus('🐮', 'vacă', 'animale', color: 'alb'),
  Stimulus('🐄', 'vacă', 'animale', color: 'alb'),
  Stimulus('🐷', 'porc', 'animale', color: 'roz'),
  Stimulus('🐖', 'porc', 'animale', color: 'roz'),
  Stimulus('🐵', 'maimuță', 'animale', color: 'maro'),
  Stimulus('🐒', 'maimuță', 'animale', color: 'maro'),
  Stimulus('🐻', 'urs', 'animale', color: 'maro'),
  Stimulus('🐻‍❄️', 'urs', 'animale', color: 'alb', familiar: 2),
  Stimulus('🐣', 'pui', 'animale', color: 'galben'),
  Stimulus('🐥', 'pui', 'animale', color: 'galben'),
  Stimulus('🐔', 'găină', 'animale', color: 'alb'),
  Stimulus('🐓', 'găină', 'animale', color: 'alb', familiar: 2),
  Stimulus('🐟', 'pește', 'animale', color: 'albastru'),
  Stimulus('🐠', 'pește', 'animale', color: 'galben'),
  Stimulus('🐸', 'broască', 'animale', color: 'verde'),
  Stimulus('🐯', 'tigru', 'animale', color: 'portocaliu', familiar: 2),
  Stimulus('🦁', 'leu', 'animale', color: 'portocaliu'),
  Stimulus('🦊', 'vulpe', 'animale', color: 'portocaliu', familiar: 2),
  Stimulus('🐘', 'elefant', 'animale', color: 'gri'),
  Stimulus('🦒', 'girafă', 'animale', color: 'galben'),
  Stimulus('🐑', 'oaie', 'animale', color: 'alb'),
  Stimulus('🐬', 'delfin', 'animale', color: 'albastru', familiar: 2),
  Stimulus('🐳', 'balenă', 'animale', color: 'albastru', familiar: 2),
  Stimulus('🐢', 'țestoasă', 'animale', color: 'verde'),
  Stimulus('🐍', 'șarpe', 'animale', color: 'verde', familiar: 2),
  Stimulus('🐝', 'albină', 'animale', color: 'galben'),
  Stimulus('🐛', 'omidă', 'animale', color: 'verde', familiar: 2),
  Stimulus('🐧', 'pinguin', 'animale', color: 'negru', familiar: 2),
  Stimulus('🦉', 'bufniță', 'animale', color: 'maro', familiar: 2),
  Stimulus('🐿️', 'veveriță', 'animale', color: 'maro', familiar: 2),
  Stimulus('🦔', 'arici', 'animale', color: 'maro', familiar: 2),
  Stimulus('🐙', 'caracatiță', 'animale', familiar: 3),
  Stimulus('🦀', 'crab', 'animale', color: 'roșu', familiar: 3),
  // fructe
  Stimulus('🍎', 'măr', 'fructe', color: 'roșu', shape: 'rotund'),
  Stimulus('🍏', 'măr', 'fructe', color: 'verde', shape: 'rotund'),
  Stimulus('🍐', 'pară', 'fructe', color: 'verde'),
  Stimulus('🍊', 'portocală', 'fructe', color: 'portocaliu', shape: 'rotund'),
  Stimulus('🍌', 'banană', 'fructe', color: 'galben'),
  Stimulus('🍇', 'struguri', 'fructe', color: 'mov'),
  Stimulus('🍓', 'căpșună', 'fructe', color: 'roșu'),
  Stimulus('🍒', 'cireșe', 'fructe', color: 'roșu'),
  Stimulus('🍑', 'piersică', 'fructe', color: 'portocaliu', shape: 'rotund', familiar: 2),
  Stimulus('🥝', 'kiwi', 'fructe', color: 'verde', familiar: 2),
  // legume și mâncare
  Stimulus('🥕', 'morcov', 'mâncare', color: 'portocaliu'),
  Stimulus('🥬', 'salată', 'mâncare', color: 'verde', familiar: 2),
  Stimulus('🧀', 'brânză', 'mâncare', color: 'galben'),
  Stimulus('🥚', 'ou', 'mâncare', color: 'alb'),
  Stimulus('🍞', 'pâine', 'mâncare', color: 'maro'),
  Stimulus('🍔', 'hamburger', 'mâncare', color: 'maro', familiar: 2),
  Stimulus('🍕', 'pizza', 'mâncare'),
  Stimulus('🥛', 'lapte', 'mâncare', color: 'alb'),
  Stimulus('🍰', 'prăjitură', 'mâncare'),
  // plante
  Stimulus('🌲', 'copac', 'plante', color: 'verde'),
  Stimulus('🌳', 'copac', 'plante', color: 'verde'),
  Stimulus('🌴', 'copac', 'plante', color: 'verde', familiar: 2),
  Stimulus('🌵', 'cactus', 'plante', color: 'verde', familiar: 2),
  Stimulus('🌷', 'floare', 'plante', color: 'roșu'),
  Stimulus('🌸', 'floare', 'plante', color: 'roz'),
  Stimulus('🌻', 'floare', 'plante', color: 'galben'),
  Stimulus('🌼', 'floare', 'plante', color: 'galben'),
  Stimulus('🍂', 'frunză', 'plante', color: 'portocaliu', familiar: 2),
  Stimulus('🍄', 'ciupercă', 'plante', color: 'roșu', familiar: 2),
  // vehicule
  Stimulus('🚗', 'mașină', 'vehicule', color: 'roșu'),
  Stimulus('🚓', 'mașină', 'vehicule'),
  Stimulus('🚌', 'autobuz', 'vehicule'),
  Stimulus('🚂', 'tren', 'vehicule'),
  Stimulus('🚜', 'tractor', 'vehicule'),
  Stimulus('🚲', 'bicicletă', 'vehicule'),
  Stimulus('✈️', 'avion', 'vehicule'),
  Stimulus('🚀', 'rachetă', 'vehicule', familiar: 2),
  Stimulus('🚁', 'elicopter', 'vehicule', familiar: 2),
  Stimulus('⛵', 'barcă', 'vehicule', familiar: 2),
  // haine
  Stimulus('👕', 'tricou', 'haine'),
  Stimulus('👖', 'pantaloni', 'haine', color: 'albastru'),
  Stimulus('👗', 'rochie', 'haine'),
  Stimulus('🧦', 'șosete', 'haine', familiar: 2),
  Stimulus('🧤', 'mănuși', 'haine', familiar: 2),
  Stimulus('🧢', 'șapcă', 'haine', familiar: 2),
  Stimulus('👟', 'pantof', 'haine'),
  Stimulus('🥾', 'pantof', 'haine', color: 'maro'),
  // jucării și obiecte
  Stimulus('🎈', 'balon', 'jucării', color: 'roșu'),
  Stimulus('🧸', 'ursuleț', 'jucării', color: 'maro'),
  Stimulus('⚽', 'minge', 'jucării', color: 'alb', shape: 'rotund'),
  Stimulus('🪁', 'zmeu', 'jucării', familiar: 2),
  Stimulus('🎁', 'cadou', 'jucării'),
  Stimulus('🥁', 'tobă', 'jucării', familiar: 2),
  Stimulus('🎸', 'chitară', 'jucării', familiar: 2),
  Stimulus('📕', 'carte', 'obiecte', color: 'roșu'),
  Stimulus('📖', 'carte', 'obiecte'),
  Stimulus('✏️', 'creion', 'obiecte', color: 'galben'),
  Stimulus('💡', 'bec', 'obiecte', color: 'galben', familiar: 2),
  Stimulus('🪑', 'scaun', 'obiecte', color: 'maro'),
  Stimulus('⏰', 'ceas', 'obiecte', color: 'roșu', familiar: 2),
  Stimulus('☀️', 'soare', 'natură', color: 'galben', shape: 'rotund'),
  Stimulus('🌞', 'soare', 'natură', color: 'galben', shape: 'rotund'),
  Stimulus('🌙', 'lună', 'natură', color: 'galben'),
  Stimulus('☁️', 'nor', 'natură', color: 'alb'),
  Stimulus('❄️', 'fulg', 'natură', color: 'albastru', familiar: 2),
  // forme (în culori diferite)
  Stimulus('🔴', 'cerc roșu', 'forme', color: 'roșu', shape: 'cerc'),
  Stimulus('🔵', 'cerc albastru', 'forme', color: 'albastru', shape: 'cerc'),
  Stimulus('🟠', 'cerc portocaliu', 'forme', color: 'portocaliu', shape: 'cerc'),
  Stimulus('🟡', 'cerc galben', 'forme', color: 'galben', shape: 'cerc'),
  Stimulus('🟢', 'cerc verde', 'forme', color: 'verde', shape: 'cerc'),
  Stimulus('🟣', 'cerc mov', 'forme', color: 'mov', shape: 'cerc'),
  Stimulus('🟦', 'pătrat albastru', 'forme', color: 'albastru', shape: 'pătrat'),
  Stimulus('🟩', 'pătrat verde', 'forme', color: 'verde', shape: 'pătrat'),
  Stimulus('⬛', 'pătrat negru', 'forme', color: 'negru', shape: 'pătrat'),
  Stimulus('⬜', 'pătrat alb', 'forme', color: 'alb', shape: 'pătrat'),
  Stimulus('🔺', 'triunghi', 'forme', color: 'roșu', shape: 'triunghi'),
  Stimulus('🔷', 'romb', 'forme', color: 'albastru', shape: 'romb'),
  Stimulus('⭐', 'stea', 'forme', color: 'galben', shape: 'stea'),
  Stimulus('🌟', 'stea', 'forme', color: 'galben', shape: 'stea'),
  Stimulus('❤️', 'inimă roșie', 'forme', color: 'roșu', shape: 'inimă'),
  Stimulus('💙', 'inimă albastră', 'forme', color: 'albastru', shape: 'inimă'),
  Stimulus('💚', 'inimă verde', 'forme', color: 'verde', shape: 'inimă'),
  Stimulus('💛', 'inimă galbenă', 'forme', color: 'galben', shape: 'inimă'),
]);
