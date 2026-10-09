import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici/data/auto_sync.dart';
import 'package:licurici/data/local_db.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/data/sync.dart';
import 'package:licurici/data/token_vault.dart';
import 'package:licurici_core/licurici_core.dart';

const serverChild = '0190a1b2-0000-7000-8000-000000000001';

/// Serverul simulat: aceleași rute și răspunsuri ca `backend/src/api/controllers.ts`.
class FakeServer {
  final received = <Map<String, dynamic>>[];
  final consents = <String>[];
  bool hasChild = false;
  bool totp = false;
  bool down = false;
  Map<String, Object?> plan = {'hiddenGames': <String>[], 'updatedAt': null, 'updatedBy': null};
  final planPuts = <List<String>>[];

  /// Refresh tokenul valabil acum (rotit la fiecare folosire, ca pe server).
  String validRefresh = 'r' * 30;
  int rotations = 0;
  int presence = 0;
  Object? lastPutLevels;

  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status);

  Future<http.Response> handle(http.Request r) async {
    if (down) throw const SocketLikeException();
    final path = r.url.path.replaceFirst('/api/v1', '');
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (path == '/auth/login' && totp && (body as Map)['code'] != '123456') {
      return json({
        'statusCode': 401,
        'message': body['code'] == null ? 'Introdu codul din aplicația de autentificare.' : 'Codul nu e corect.',
        if (body['code'] == null) 'details': ['totp'],
      }, 401);
    }
    if (path == '/auth/login') {
      return (body as Map)['password'] == 'parola-lunga-1'
          ? json({
              'accessToken': 'tok',
              'refreshToken': 'r' * 30,
              'expiresIn': 900,
            })
          : json({
              'statusCode': 401,
              'message': 'E-mail sau parolă greșită.',
            }, 401);
    }
    if (path == '/auth/refresh') {
      if ((body as Map)['refreshToken'] != validRefresh) {
        return json({'statusCode': 401, 'message': 'Sesiune expirată. Autentifică-te din nou.'}, 401);
      }
      validRefresh = 'n${++rotations}'.padRight(30, 'x');
      return json({'accessToken': 'tok', 'refreshToken': validRefresh, 'expiresIn': 900});
    }
    expect(r.headers['authorization'], 'Bearer tok');
    if (path == '/consents') {
      consents.add('${(body as Map)['purpose']}=${body['granted']}');
      return json({'SYNC': true});
    }
    if (path == '/children' && r.method == 'GET') {
      return json(
        hasChild
            ? [
                {'id': serverChild, 'nickname': 'Ilinca'},
              ]
            : [],
      );
    }
    if (path == '/children' && r.method == 'POST') {
      hasChild = true;
      return json({'id': serverChild, 'nickname': (body as Map)['nickname']});
    }
    if (path == '/children/$serverChild/sessions') {
      final sessions = ((body as Map)['sessions'] as List)
          .cast<Map<String, dynamic>>();
      received.addAll(sessions);
      return json({'accepted': sessions.length});
    }
    if (path == '/children/$serverChild/presence') {
      presence++;
      return http.Response('', 204);
    }
    if (path == '/children/$serverChild/plan' && r.method == 'GET') return json(plan);
    if (path == '/children/$serverChild/plan' && r.method == 'PUT') {
      final hidden = ((body as Map)['hiddenGames'] as List).cast<String>();
      planPuts.add(hidden);
      lastPutLevels = body['levels'];
      plan = {'hiddenGames': hidden, 'updatedAt': '2026-10-09T10:00:00.000Z', 'updatedBy': 'PARENT'};
      return json(plan);
    }
    return json({'statusCode': 404, 'message': 'Nu există.'}, 404);
  }
}

class SocketLikeException implements Exception {
  const SocketLikeException();
}

void main() {
  final demo = demoChildren().first.sessions.take(4).toList();
  List<SessionRecord> local() => [
    for (final s in demo)
      SessionRecord.fromJson({...s.toJson(), 'childId': localChildId}),
  ];

  Future<int> run(
    FakeServer server,
    SessionStore store, {
    String password = 'parola-lunga-1',
    bool consent = true,
  }) =>
      SyncClient(
        client: MockClient(server.handle),
        baseUrl: 'http://api/api/v1',
      ).run(
        store: store,
        email: 'ana@example.md',
        password: password,
        consent: consent,
      );

  test(
    'fără bifa de acord nu pleacă nimic (nici măcar autentificarea)',
    () async {
      final server = FakeServer();
      final store = MemorySessionStore();
      for (final s in local()) {
        await store.save(s);
      }
      await expectLater(
        run(server, store, consent: false),
        throwsA(isA<SyncException>()),
      );
      expect(server.received, isEmpty);
      expect(server.consents, isEmpty);
    },
  );

  test(
    'trimite doar sesiunile netrimise, cu faptele calculate pe tabletă; a doua oară nimic',
    () async {
      final server = FakeServer();
      final db = LocalDb(NativeDatabase.memory());
      addTearDown(db.close);
      final store = DriftSessionStore(db);
      for (final s in local()) {
        await store.save(s);
      }

      expect(await run(server, store), demo.length);
      expect(server.consents, ['SYNC=true']);
      expect(
        server.hasChild,
        isTrue,
      ); // profilul s-a creat la prima sincronizare
      final first = server.received.first;
      expect(
        (first['record'] as Map)['childId'],
        localChildId,
      ); // serverul pune id-ul real
      expect(first['facts'], SessionReport.from(demo.first).toAiJson());
      // Faptele includ comparația cu sesiunea anterioară (calculată în ordine).
      expect(
        server.received[1]['facts'],
        SessionReport.from(
          demo[1],
          previous: SessionReport.from(demo[0]),
        ).toAiJson(),
      );

      expect(await run(server, store), 0);
      expect(server.received, hasLength(demo.length));

      // O sesiune nouă (sau modificată) se trimite la următoarea sincronizare.
      final extra = demoChildren()[1].sessions.first;
      await store.save(
        SessionRecord.fromJson({...extra.toJson(), 'childId': localChildId}),
      );
      expect(await run(server, store), 1);
    },
  );

  test(
    'parolă greșită sau server căzut: mesaj clar, sesiunile rămân de trimis',
    () async {
      final server = FakeServer();
      final store = MemorySessionStore();
      for (final s in local()) {
        await store.save(s);
      }
      await expectLater(
        run(server, store, password: 'gresita-gresita'),
        throwsA(
          isA<SyncException>().having(
            (e) => e.message,
            'message',
            'E-mail sau parolă greșită.',
          ),
        ),
      );
      server.down = true;
      await expectLater(run(server, store), throwsA(isA<SyncException>()));
      expect(await store.unsyncedIds(), hasLength(demo.length));
    },
  );

  test('planul de jocuri: cel de pe server, mai nou, vine pe tabletă; cel de pe tabletă, mai nou, pleacă', () async {
    final server = FakeServer()..hasChild = true;
    final store = MemorySessionStore();
    SyncClient client() => SyncClient(client: MockClient(server.handle), baseUrl: 'http://api/api/v1');
    // 1. Specialistul a ales în panou; tableta nu a schimbat nimic.
    server.plan = {
      'hiddenGames': ['pescarul', 'simon'],
      'levels': {'emotii': 3},
      'updatedAt': '2026-10-09T08:00:00.000Z',
      'updatedBy': 'THERAPIST',
    };
    Set<String>? applied;
    Map<String, int>? levels;
    await client().run(
      store: store,
      email: 'ana@example.md',
      password: 'parola-lunga-1',
      consent: true,
      plan: (hidden: <String>{}, at: null),
      onPlan: (h, l, at) {
        applied = h;
        levels = l;
      },
    );
    expect(applied, {'pescarul', 'simon'});
    expect(levels, {'emotii': 3});
    expect(server.planPuts, isEmpty);
    // 2. Părintele a schimbat pe tabletă, după: lista de pe tabletă urcă pe server.
    applied = null;
    await client().run(
      store: store,
      email: 'ana@example.md',
      password: 'parola-lunga-1',
      consent: true,
      plan: (hidden: {'cauta'}, at: DateTime.utc(2026, 10, 9, 9)),
      onPlan: (h, l, at) => applied = h,
    );
    expect(applied, isNull);
    expect(server.planPuts.single, ['cauta']);
    // Nivelurile alese de specialist nu se pierd când urcă lista de pe tabletă.
    expect(server.lastPutLevels, {'emotii': 3});
  });

  test('trimiterea automată: cu refresh tokenul păstrat, după fiecare sesiune; se oprește singură dacă e refuzată', () async {
    final server = FakeServer()..hasChild = true;
    final store = MemorySessionStore();
    final vault = MemoryTokenVault();
    final container = ProviderContainer(
      overrides: [
        syncClientProvider.overrideWithValue(SyncClient(client: MockClient(server.handle), baseUrl: 'http://api/api/v1')),
        sessionStoreProvider.overrideWithValue(store),
        tokenVaultProvider.overrideWithValue(vault),
      ],
    );
    addTearDown(container.dispose);
    final auto = container.read(autoSyncProvider.notifier);
    // Oprită: nu pleacă nimic.
    await store.save(local().first);
    expect(await auto.trigger(), 0);
    expect(server.received, isEmpty);

    // Părintele o pornește din fereastra „Trimite pe server” (refresh tokenul de la autentificare).
    await auto.enable(server.validRefresh);
    expect(await auto.trigger(), 1);
    expect(server.received, hasLength(1));
    expect(server.consents, isEmpty); // acordul s-a dat o dată, explicit
    expect(await vault.read(), server.validRefresh); // tokenul rotit e cel păstrat
    expect(container.read(autoSyncProvider).lastSent, 1);

    await store.save(local()[1]);
    expect(await auto.trigger(), 1);
    expect(server.rotations, 2);

    // Fără rețea: rămâne pornită, sesiunea așteaptă.
    await store.save(local()[2]);
    server.down = true;
    expect(await auto.trigger(), 0);
    expect(container.read(autoSyncProvider).enabled, isTrue);
    expect(container.read(autoSyncProvider).problem, isNull);
    expect(await store.unsyncedIds(), hasLength(1));

    // Parola s-a schimbat pe server: tokenul nu mai merge → oprită, părintele e rugat să reconecteze.
    server
      ..down = false
      ..validRefresh = 'altul'.padRight(30, 'y');
    expect(await auto.trigger(), 0);
    expect(await vault.read(), isNull);
    expect(container.read(autoSyncProvider).enabled, isFalse);
    expect(container.read(autoSyncProvider).problem, contains('Trimite din nou manual'));
  });

  test('fereastra „Trimite pe server” cu „trimite automat” dă refresh tokenul, fără parolă', () async {
    final server = FakeServer()..hasChild = true;
    String? kept;
    await SyncClient(client: MockClient(server.handle), baseUrl: 'http://api/api/v1').run(
      store: MemorySessionStore(),
      email: 'ana@example.md',
      password: 'parola-lunga-1',
      consent: true,
      onRefreshToken: (t) => kept = t,
    );
    expect(kept, 'r' * 30);
    expect(server.consents, ['SYNC=true']);
  });

  test('contul cu autentificare în doi pași: întâi se cere codul, apoi trimiterea merge', () async {
    final server = FakeServer()
      ..hasChild = true
      ..totp = true;
    final store = MemorySessionStore();
    await store.save(local().first);
    final client = SyncClient(client: MockClient(server.handle), baseUrl: 'http://api/api/v1');
    Future<int> go({String? code}) =>
        client.run(store: store, email: 'ana@example.md', password: 'parola-lunga-1', code: code, consent: true);
    await expectLater(go(), throwsA(isA<SyncException>().having((e) => e.needsTotp, 'needsTotp', isTrue)));
    await expectLater(go(code: '000000'), throwsA(isA<SyncException>().having((e) => e.needsTotp, 'needsTotp', isFalse)));
    expect(await go(code: '123456'), 1);
  });

  test('„se joacă acum” și trimiterea, pornite deodată, merg pe rând (același token nu se folosește de două ori)', () async {
    final server = FakeServer()..hasChild = true;
    final store = MemorySessionStore();
    final vault = MemoryTokenVault();
    final container = ProviderContainer(
      overrides: [
        syncClientProvider.overrideWithValue(SyncClient(client: MockClient(server.handle), baseUrl: 'http://api/api/v1')),
        sessionStoreProvider.overrideWithValue(store),
        tokenVaultProvider.overrideWithValue(vault),
      ],
    );
    addTearDown(container.dispose);
    final auto = container.read(autoSyncProvider.notifier);
    await auto.enable(server.validRefresh);
    await store.save(local().first);
    final a = auto.announcePlaying();
    final sent = auto.trigger();
    final b = auto.announcePlaying();
    await Future.wait([a, b]);
    expect(await sent, 1);
    expect(server.presence, 2);
    expect(server.rotations, 3);
    expect(container.read(autoSyncProvider).enabled, isTrue);
    expect(await vault.read(), server.validRefresh);
  });
}
