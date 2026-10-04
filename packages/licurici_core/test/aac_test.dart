import 'dart:io';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

String _openMoji(String emoji) => emoji.runes
    .where((cp) => cp != 0xFE0F)
    .map((cp) => cp.toRadixString(16).toUpperCase().padLeft(4, '0'))
    .join('-');

void main() {
  test('propozițiile: început + cuvânt; răspunsurile scurte singure', () {
    final vreau = aacBoard.firstWhere((c) => c.id == 'vreau');
    expect(aacSentence(vreau, vreau.words.first), 'Vreau apă');
    final spun = aacBoard.firstWhere((c) => c.id == 'spun');
    expect(aacSentence(spun, spun.words.first), 'Da');
  });

  test('fără pictograme duble într-o filă; toate au SVG OpenMoji', () {
    for (final c in aacBoard) {
      expect(c.words.map((w) => w.emoji).toSet(), hasLength(c.words.length), reason: c.id);
      for (final e in [c.emoji, ...c.words.map((w) => w.emoji)]) {
        expect(File('../game_content/art/openmoji/${_openMoji(e)}.svg').existsSync(), isTrue, reason: e);
      }
    }
  });

  test('cererile apar în rezumatul pentru părinte', () {
    final rec = SessionRecorder(childId: 'c')
      ..event(SessionEventKind.request, gameId: 'vorbeste')
      ..event(SessionEventKind.request, gameId: 'vorbeste');
    final report = SessionReport.from(rec.close()!);
    expect(report.parentSummary, contains('de 2 ori'));
    expect(catalogEntry('vorbeste')!.domain, Domain.com);
  });
}
