import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import 'api.dart';

/// Sesiunile importate din aplicația copilului (export din „Pentru părinți”), până există
/// sincronizarea cu cont (ADR-011). Trăiesc doar în memoria paginii.
class ImportedSessions extends Notifier<List<SessionRecord>> {
  @override
  List<SessionRecord> build() => const [];

  /// Întoarce câte sesiuni au fost importate; aruncă [TransferFormatException] la text greșit.
  int importText(String text) {
    final sessions = importSessions(text);
    state = sessions;
    return sessions.length;
  }
}

final importedSessionsProvider =
    NotifierProvider<ImportedSessions, List<SessionRecord>>(
      ImportedSessions.new,
    );

/// Boundary for the future authorized API data source: copilul importat (dacă există) primul,
/// apoi copiii demo.
final childrenProvider = Provider<List<ChildHistory>>((ref) {
  final server = ref.watch(serverChildrenProvider);
  final imported = ref.watch(importedSessionsProvider);
  // După autentificare: doar copiii reali (fără demo, ca să nu se amestece datele) — și când
  // terapeutul încă n-a adăugat niciun copil.
  if (server.isNotEmpty || ref.watch(signedInProvider)) {
    return [...server, if (imported.isNotEmpty) importedChild(imported)];
  }
  return [if (imported.isNotEmpty) importedChild(imported), ...demoChildren()];
});

String dateLabel(DateTime date) {
  final d = date.toLocal();
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String percent(double value) => '${(value * 100).round()}%';
