/// Clasele (grădiniță + 1–4) și materiile — aliniere la curriculumul primar MD/RO.
/// Port din `legacy/electron/src/grades.js`.
library;

enum Grade {
  gradinita('Grădiniță', 'G'),
  clasa1('Clasa 1', '1'),
  clasa2('Clasa 2', '2'),
  clasa3('Clasa 3', '3'),
  clasa4('Clasa 4', '4');

  const Grade(this.label, this.code);

  final String label;

  /// Codul compact folosit în catalog: `G1234`.
  final String code;

  /// Tier-ul implicit de dificultate: grădiniță → 1 … clasa 4 → 5.
  int get baseTier => index + 1;

  static Grade fromCode(String code) =>
      Grade.values.firstWhere((g) => g.code == code,
          orElse: () => throw ArgumentError.value(code, 'code', 'clasă necunoscută'));

  /// `'G12'` → {gradinita, clasa1, clasa2}.
  static Set<Grade> parseCodes(String codes) =>
      {for (final c in codes.split('')) fromCode(c)};
}

enum Subject {
  romana('Limba română', 0xFFE79B86),
  matematica('Matematică', 0xFF5B9BB5),
  timpBani('Timp & bani', 0xFF6FB0C8),
  stiinte('Științe & mediu', 0xFF6BBF8A),
  istorie('Istorie', 0xFFC9A06A),
  forme('Forme & logică', 0xFFA9A3D1),
  emotii('Emoții & viață', 0xFFF0A9C0),
  engleza('Engleză', 0xFFF2CF6B);

  const Subject(this.label, this.color);

  final String label;

  /// Culoarea materiei, ARGB (se convertește în `Color` în stratul UI).
  final int color;
}
