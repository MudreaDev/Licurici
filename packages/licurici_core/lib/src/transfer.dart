/// Transferul sesiunilor fără server: aplicația copilului le exportă (text JSON), panoul web
/// le importă. Puntea până la sincronizarea cu cont (ADR-011); și primul pas pentru
/// portabilitatea datelor (GDPR art. 20). Conține doar ce e în `SessionRecord`: fără nume,
/// fără text liber, fără audio/imagini.
library;

import 'dart:convert';

import 'demo.dart';
import 'progress.dart';
import 'report.dart';

const transferFormat = 'licurici-sesiuni';
const transferVersion = 1;

String exportSessions(List<SessionRecord> sessions) => jsonEncode({
      'format': transferFormat,
      'version': transferVersion,
      'sessions': [for (final s in sessions) s.toJson()],
    });

class TransferFormatException implements Exception {
  const TransferFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

List<SessionRecord> importSessions(String text) {
  final Object? data;
  try {
    data = jsonDecode(text.trim());
  } on FormatException {
    throw const TransferFormatException('Textul nu este un export Licurici.');
  }
  if (data is! Map || data['format'] != transferFormat) {
    throw const TransferFormatException('Textul nu este un export Licurici.');
  }
  if (data['version'] != transferVersion) {
    throw const TransferFormatException('Versiune de export necunoscută.');
  }
  try {
    final list = [
      for (final s in data['sessions'] as List)
        SessionRecord.fromJson((s as Map).cast<String, Object?>()),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return list;
  } on Object {
    throw const TransferFormatException('Exportul e incomplet sau deteriorat.');
  }
}

/// Copilul din sesiunile importate: obiectivele și treptele stăpânite se deduc din progres.
ChildHistory importedChild(List<SessionRecord> sessions, {String nickname = 'Copilul meu'}) {
  final progress = progressFromSessions(sessions);
  return ChildHistory(
    ChildProfile(
      id: sessions.isEmpty ? 'importat' : sessions.first.childId,
      nickname: nickname,
      ageYears: 0,
      activeSteps: [for (final p in progress) if (!p.mastered) p.stepId],
      masteredSteps: [for (final p in progress) if (p.mastered) p.stepId],
    ),
    sessions,
  );
}
