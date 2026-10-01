import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/data/local_db.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici_core/licurici_core.dart';

void main() {
  test('Drift: sesiunea se salvează, se suprascrie la checkpoint și se citește înapoi', () async {
    final db = LocalDb(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftSessionStore(db);
    final history = demoChildren().first;
    final record = history.sessions.first;
    final local = SessionRecord.fromJson({...record.toJson(), 'childId': localChildId});

    await store.save(local);
    await store.save(local); // același id → upsert, nu duplicat
    final back = await store.all();
    expect(back, hasLength(1));
    expect(back.single.trials, hasLength(local.trials.length));
    expect(back.single.moodAfter, local.moodAfter);
    expect(SessionReport.from(back.single).toAiJson(), SessionReport.from(local).toAiJson());
    expect(await db.unsyncedIds(), [local.id]);

    await db.writeMeta('k', 'v');
    expect(await db.readMeta('k'), 'v');
  });
}
