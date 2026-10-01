// Generează corpul unei cereri de sincronizare, exact cum îl trimite tableta, pentru testul
// de contract din backend (Dart ↔ TypeScript nu au voie să se desincronizeze):
//
//   dart run tool/sync_fixture.dart > ../../backend/src/sync/sync-fixture.json
import 'dart:convert';
import 'dart:io';

import 'package:licurici_core/licurici_core.dart';

void main() {
  final history = demoChildren().first;
  final out = [
    for (final s in history.sessions.take(3))
      {
        'record': SessionRecord.fromJson({...s.toJson(), 'id': _uuid(s.id), 'childId': 'local'}).toJson(),
        'facts': SessionReport.from(s).toAiJson(),
      },
  ];
  stdout.write(const JsonEncoder.withIndent('  ').convert({'sessions': out}));
}

/// Id-urile demo nu sunt UUID; le transformăm determinist (tableta folosește UUID v4).
String _uuid(String seed) {
  final h = seed.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0x7fffffff).toRadixString(16).padLeft(8, '0');
  return '$h-0000-4000-8000-${h.padLeft(12, '0')}';
}
