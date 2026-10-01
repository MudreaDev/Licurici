import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:licurici_core/licurici_core.dart';

part 'local_db.g.dart';

/// Sesiunile jucate, pe dispozitiv (ADR-004). Conținutul e `SessionRecord.toJson()`;
/// `synced` = coada de trimis la server (outbox, ADR-011) — doar cu cont + consimțământ.
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get childId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  TextColumn get payload => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Valori simple ale dispozitivului (ex. id-ul pseudonim al copilului).
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Sessions, Meta])
class LocalDb extends _$LocalDb {
  LocalDb([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'licurici'));

  @override
  int get schemaVersion => 1;

  Future<void> saveSession(SessionRecord r) => into(sessions).insertOnConflictUpdate(
        SessionsCompanion.insert(
          id: r.id,
          childId: r.childId,
          startedAt: r.start,
          endedAt: r.end,
          payload: jsonEncode(r.toJson()),
        ),
      );

  /// Sesiunile copilului, cronologic.
  Future<List<SessionRecord>> sessionsOf(String childId) async {
    final rows = await (select(sessions)
          ..where((s) => s.childId.equals(childId))
          ..orderBy([(s) => OrderingTerm.asc(s.startedAt)]))
        .get();
    return [
      for (final r in rows)
        SessionRecord.fromJson((jsonDecode(r.payload) as Map).cast<String, Object?>()),
    ];
  }

  /// Sesiunile încă netrimise (pentru sincronizare).
  Future<List<String>> unsyncedIds() async =>
      [for (final r in await (select(sessions)..where((s) => s.synced.equals(false))).get()) r.id];

  Future<String?> readMeta(String key) async =>
      (await (select(meta)..where((m) => m.key.equals(key))).getSingleOrNull())?.value;

  Future<void> writeMeta(String key, String value) =>
      into(meta).insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));
}
