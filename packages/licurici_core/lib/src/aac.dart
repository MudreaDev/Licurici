/// Vorbește (COM3, catalog #19 `vreau`): tabla de comunicare cu pictograme (AAC / PECS).
/// Copilul alege un început („Vreau”, „Mă simt”) și o pictogramă; aplicația rostește
/// propoziția. Nu există răspuns greșit; se notează doar cererile (KPI: cereri spontane pe
/// sesiune și varietatea lor). Port din `comunicare.js`, cu vocabularul reorganizat pe fraze.
library;

import 'grades.dart';

class AacWord {
  const AacWord(this.emoji, this.word);

  final String emoji;

  /// Cuvântul rostit după început („apă” → „Vreau apă”).
  final String word;
}

class AacCategory {
  const AacCategory(this.id, this.starter, this.emoji, this.words);

  final String id;

  /// Începutul propoziției, rostit și scris pe filă („Vreau”).
  final String starter;
  final String emoji;
  final List<AacWord> words;
}

const aacBoard = [
  AacCategory('vreau', 'Vreau', '🙋', [
    AacWord('💧', 'apă'),
    AacWord('🍎', 'mâncare'),
    AacWord('🥛', 'lapte'),
    AacWord('🍞', 'pâine'),
    AacWord('🧸', 'jucăria'),
    AacWord('📖', 'o carte'),
    AacWord('⚽', 'mingea'),
    AacWord('🎈', 'balonul'),
    AacWord('🤗', 'o îmbrățișare'),
    AacWord('🛌', 'să mă odihnesc'),
    AacWord('🚽', 'la baie'),
    AacWord('🎵', 'muzică'),
  ]),
  AacCategory('simt', 'Mă simt', '❤️', [
    AacWord('😊', 'bine'),
    AacWord('😢', 'trist'),
    AacWord('😠', 'supărat'),
    AacWord('😨', 'speriat'),
    AacWord('😴', 'obosit'),
    AacWord('🤕', 'rău, mă doare'),
  ]),
  AacCategory('merg', 'Vreau să merg', '🚶', [
    AacWord('🏠', 'acasă'),
    AacWord('🌳', 'în parc'),
    AacWord('🏫', 'la școală'),
    AacWord('🛒', 'la magazin'),
    AacWord('🚗', 'cu mașina'),
  ]),
  AacCategory('oameni', 'Vreau la', '👪', [
    AacWord('👩', 'mama'),
    AacWord('👨', 'tata'),
    AacWord('👵', 'bunica'),
    AacWord('👴', 'bunicul'),
    AacWord('🧒', 'prietenul meu'),
  ]),
  AacCategory('spun', 'Spun', '💬', [
    AacWord('✅', 'da'),
    AacWord('❌', 'nu'),
    AacWord('🆘', 'ajutor'),
    AacWord('⏸️', 'pauză'),
    AacWord('🔁', 'încă o dată'),
    AacWord('🏁', 'gata'),
    AacWord('🙏', 'mulțumesc'),
    AacWord('👋', 'bună'),
  ]),
];

/// Propoziția rostită: „Vreau apă”. Răspunsurile scurte („Spun”) se rostesc singure („Da”).
String aacSentence(AacCategory c, AacWord w) =>
    c.id == 'spun' ? _cap(w.word) : '${c.starter} ${w.word}';

String _cap(String s) => s[0].toUpperCase() + s.substring(1);

class AacGame {
  const AacGame();

  String get id => 'vorbeste';
  String get name => 'Vorbește';
  String get emoji => '💬';
  String get description => 'Spune ce vrei cu pozele';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['COM3'];

  /// Câte pictograme pe filă: la început puține și mari, apoi toate (plan: 2 → 20).
  int wordsFor(int level) => level <= 1 ? 4 : (level == 2 ? 6 : 12);
}
