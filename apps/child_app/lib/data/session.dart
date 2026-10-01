import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import 'local_db.dart';

/// Unde se păstrează sesiunile. În aplicație: Drift (ADR-004), setat în `main()`;
/// implicit (teste, previzualizări): în memorie.
abstract interface class SessionStore {
  Future<void> save(SessionRecord record);
  Future<List<SessionRecord>> all();
}

class MemorySessionStore implements SessionStore {
  final _records = <String, SessionRecord>{};

  @override
  Future<void> save(SessionRecord record) async => _records[record.id] = record;

  @override
  Future<List<SessionRecord>> all() async =>
      _records.values.toList()..sort((a, b) => a.start.compareTo(b.start));
}

class DriftSessionStore implements SessionStore {
  DriftSessionStore(this.db);
  final LocalDb db;

  @override
  Future<void> save(SessionRecord record) => db.saveSession(record);

  @override
  Future<List<SessionRecord>> all() => db.sessionsOf(localChildId);
}

/// Pe dispozitiv există un singur profil de copil, fără cont; id-ul real (pseudonim, UUID)
/// îl primește la sincronizare, când părintele își face cont (ADR-012).
const localChildId = 'local';

final sessionStoreProvider = Provider<SessionStore>((ref) => MemorySessionStore());

/// Sesiunea în curs (null = nicio sesiune deschisă). O sesiune începe la primul joc și se
/// încheie când copilul apasă „Gata pe azi” (sau, implicit, la următoarea pornire).
class SessionController extends Notifier<SessionRecorder?> {
  @override
  SessionRecorder? build() => null;

  /// Trebuie întrebat „Cum te simți?” înainte de primul joc din sesiune.
  bool get needsMoodBefore => state == null;

  bool get hasPlayed => state != null && !state!.isEmpty;

  SessionRecorder _open() => state ??= SessionRecorder(childId: localChildId);

  void start({Mood? moodBefore}) {
    final r = _open();
    r.moodBefore ??= moodBefore;
    state = r;
  }

  /// Înregistrează ceva în sesiunea curentă (o deschide dacă e nevoie).
  void record(void Function(SessionRecorder r) write) {
    write(_open());
    // Obiectul e același; anunțăm explicit, ca ecranul principal să arate „Gata pe azi”.
    ref.notifyListeners();
  }

  /// Salvează sesiunea parțială (după fiecare joc), ca să nu se piardă nimic dacă aplicația
  /// e închisă brusc. Același id → se suprascrie.
  Future<void> checkpoint() async {
    final r = state;
    if (r == null || r.isEmpty) return;
    await ref.read(sessionStoreProvider).save(_snapshot(r));
  }

  /// Încheie sesiunea cu dispoziția de final și o salvează. Întoarce raportul (sau null).
  Future<SessionRecord?> finish({Mood? moodAfter}) async {
    final r = state;
    if (r == null) return null;
    r.moodAfter = moodAfter;
    final record = r.close();
    state = null;
    if (record != null) await ref.read(sessionStoreProvider).save(record);
    return record;
  }

  SessionRecord _snapshot(SessionRecorder r) => SessionRecord(
        id: r.id,
        childId: r.childId,
        start: r.start,
        end: DateTime.now(),
        trials: r.trials,
        events: r.events,
        moodBefore: r.moodBefore,
        moodAfter: r.moodAfter,
      );
}

final sessionProvider = NotifierProvider<SessionController, SessionRecorder?>(SessionController.new);
