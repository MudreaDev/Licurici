import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/data/local_db.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici_core/licurici_core.dart';

void main() {
  test(
    'Drift: sesiunea se salvează, se suprascrie la checkpoint și se citește înapoi',
    () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSessionStore(db);
      final history = demoChildren().first;
      final record = history.sessions.first;
      final local = SessionRecord.fromJson({
        ...record.toJson(),
        'childId': localChildId,
      });

      await store.save(local);
      await store.save(local); // același id → upsert, nu duplicat
      final back = await store.all();
      expect(back, hasLength(1));
      expect(back.single.trials, hasLength(local.trials.length));
      expect(back.single.moodAfter, local.moodAfter);
      expect(
        SessionReport.from(back.single).toAiJson(),
        SessionReport.from(local).toAiJson(),
      );
      expect(await db.unsyncedIds(), [local.id]);

      await db.writeMeta('k', 'v');
      expect(await db.readMeta('k'), 'v');

      // Părintele șterge datele de pe tabletă: sesiunile și setările dispar.
      await store.clear();
      expect(await store.all(), isEmpty);
      expect(await db.readMeta('k'), isNull);
    },
  );

  test(
    'setările copilului: dus-întors prin Drift; valorile necunoscute revin la implicit',
    () async {
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      const s = AppSettings(grade: Grade.clasa3, calm: true, voice: false);
      await db.writeMeta('settings', jsonEncode(s.toJson()));
      final back = AppSettings.fromJson(
        (jsonDecode((await db.readMeta('settings'))!) as Map)
            .cast<String, Object?>(),
      );
      expect(back.toJson(), s.toJson());
      expect(
        AppSettings.fromJson({'grade': 'clasa9', 'calm': 'da'}).toJson(),
        const AppSettings().toJson(),
      );
    },
  );
}
