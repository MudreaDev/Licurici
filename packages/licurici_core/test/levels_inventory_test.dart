import 'dart:io';

import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('evidența nivelurilor conține fiecare joc exact o dată, în secțiunea sa', () {
    final lines = File('../../docs/progres-niveluri-jocuri.md').readAsLinesSync();
    Domain? current;
    final found = <String>{};
    for (final line in lines) {
      if (line.startsWith('## ')) {
        current = Domain.values.where((domain) => line.contains('(${domain.code})')).firstOrNull;
      }
      final match = RegExp(r'^- \[[ x]\] .*\(`([^`]+)`,').firstMatch(line);
      if (match == null) continue;
      final id = match.group(1)!;
      final entry = catalogEntry(id);
      expect(entry, isNotNull, reason: id);
      expect(found.add(id), isTrue, reason: 'joc duplicat: $id');
      expect(entry!.domain, current, reason: 'secțiune greșită: $id');
    }
    expect(found, catalog.map((entry) => entry.id).toSet());
  });
}
