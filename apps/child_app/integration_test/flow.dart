/// Fluxul cap-coadă (README §0.1, punctul 6): copilul alege un joc, îl joacă până la final,
/// închide ziua cu „Gata pe azi” → sesiunea se salvează în Drift (SQLite adevărat) → părintele
/// trece de poartă și o trimite pe server. Serverul e unul HTTP local (aceleași rute și răspunsuri
/// ca `backend/src/api/controllers.ts`), deci cererile trec prin rețea, nu printr-un client simulat.
///
/// Același flux rulează pe dispozitiv (`flow_test.dart` de aici, timp real) și în `flutter test`
/// (`test/flow_test.dart`, timp simulat): așteptările merg în ambele.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:licurici/data/auto_sync.dart';
import 'package:licurici/data/local_db.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/data/sync.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/voice.dart';

const _email = 'parinte@licurici.test';
const _password = 'parola-de-test-1';
const _childId = '0190a1b2-0000-7000-8000-000000000001';

/// Serverul API, cât îi trebuie tabletei la sincronizare.
class _LocalServer {
  late final HttpServer _server;
  final sessions = <Map<String, dynamic>>[];
  final consents = <String>[];
  bool hasChild = false;

  String get baseUrl => 'http://${_server.address.host}:${_server.port}/api/v1';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path.replaceFirst('/api/v1', '');
    final raw = await utf8.decodeStream(req);
    final body = raw.isEmpty ? null : jsonDecode(raw);
    final authorized = req.headers.value('authorization') == 'Bearer acces';
    Object? reply;
    var status = 200;
    switch ((req.method, path)) {
      case ('POST', '/auth/login'):
        if ((body as Map)['email'] == _email && body['password'] == _password) {
          reply = {'accessToken': 'acces', 'refreshToken': 'r' * 30, 'expiresIn': 900};
        } else {
          (status, reply) = (401, {'statusCode': 401, 'message': 'E-mail sau parolă greșită.'});
        }
      case _ when !authorized:
        (status, reply) = (401, {'statusCode': 401, 'message': 'Neautentificat.'});
      case ('POST', '/consents'):
        consents.add((body as Map)['purpose'] as String);
        reply = {'ok': true};
      case ('GET', '/children'):
        reply = [
          if (hasChild) {'id': _childId, 'nickname': 'Copilul meu'},
        ];
      case ('POST', '/children'):
        hasChild = true;
        reply = {'id': _childId, 'nickname': (body as Map)['nickname']};
      case ('POST', '/children/$_childId/sessions'):
        final batch = ((body as Map)['sessions'] as List).cast<Map<String, dynamic>>();
        sessions.addAll(batch);
        reply = {'accepted': batch.length};
      case ('GET', '/children/$_childId/plan'):
        reply = {'hiddenGames': <String>[], 'updatedAt': null, 'updatedBy': null};
      case ('PUT', '/children/$_childId/plan'):
        reply = body;
      default:
        (status, reply) = (404, {'statusCode': 404, 'message': 'Nu există.'});
    }
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(reply));
    await req.response.close();
  }
}

/// Lasă I/O-ul real (socket, SQLite) să meargă, apoi avansează ceasul cu [ms]: pe dispozitiv
/// `pump` așteaptă cu adevărat, în `flutter test` mută timpul simulat.
Future<void> wait(WidgetTester tester, int ms) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  await tester.pump(Duration(milliseconds: ms));
}

/// Așteaptă până apare [finder] (cel mult ~[seconds] s).
Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 20}) async {
  for (var i = 0; finder.evaluate().isEmpty; i++) {
    if (i > seconds * 10) fail('nu a apărut în $seconds s: $finder');
    await wait(tester, 100);
  }
}

Future<T> io<T>(WidgetTester tester, Future<T> Function() f) async => (await tester.runAsync(f)) as T;

/// [overrides] în plus: în `flutter test` fără voce reală și fără manifestul ei.
Future<void> childToServerFlow(WidgetTester tester, {List<Override> overrides = const []}) async {
  final server = _LocalServer();
  await io(tester, server.start);
  // SQLite adevărat (în memorie, ca testul să nu lase urme pe tabletă).
  final db = LocalDb(NativeDatabase.memory());
  final client = http.Client();
  final store = DriftSessionStore(db);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        voiceProvider.overrideWithValue(const SilentSpeaker()),
        sessionStoreProvider.overrideWithValue(store),
        syncClientProvider.overrideWithValue(SyncClient(client: client, baseUrl: server.baseUrl)),
        ...overrides,
      ],
      child: const LicuriciApp(),
    ),
  );

  // Ecranul de pornire pre-încarcă resursele, apoi ecranul principal.
  await waitFor(tester, find.text('Atenție'), seconds: 60);
  await wait(tester, 800);

  // Copilul deschide aria „Potrivește” și primul joc.
  final domain = find.byKey(const ValueKey('domain-POT'));
  await tester.scrollUntilVisible(
    domain,
    200,
    scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
  );
  await wait(tester, 300);
  await tester.tap(domain);
  await waitFor(tester, find.byKey(const ValueKey('game-potriveste')));
  await wait(tester, 500);
  await tester.tap(find.byKey(const ValueKey('game-potriveste')));
  await waitFor(tester, find.byKey(const ValueKey('mood-skip')));
  await tester.tap(find.byKey(const ValueKey('mood-skip')));
  await waitFor(tester, find.byKey(const ValueKey('choice-0')));

  // Joacă toate rundele: atinge variantele pe rând (greșelile nu blochează).
  for (var round = 0; round < 12 && find.text('Încă o dată').evaluate().isEmpty; round++) {
    for (var i = 0; i < 5 && find.text('Bravo!').evaluate().isEmpty; i++) {
      final option = find.byKey(ValueKey('choice-$i'));
      if (option.evaluate().isEmpty) break;
      await tester.tap(option, warnIfMissed: false);
      await wait(tester, 400);
    }
    expect(find.text('Bravo!'), findsWidgets, reason: 'runda $round nu s-a rezolvat');
    // Trecerea la runda următoare (sau la final): runda veche iese animat, cât stă lângă cea nouă.
    for (
      var t = 0;
      t < 60 &&
          (find.text('Bravo!').evaluate().isNotEmpty || find.byKey(const ValueKey('choice-0')).evaluate().length > 1) &&
          find.text('Încă o dată').evaluate().isEmpty;
      t++
    ) {
      await wait(tester, 100);
    }
  }
  await waitFor(tester, find.text('Încă o dată'));
  await tester.tap(find.text('Acasă').last);
  await waitFor(tester, find.text('Atenție'));
  await wait(tester, 500);

  // „Gata pe azi” → dispoziția de final → sesiunea se scrie în SQLite.
  await tester.tap(find.byKey(const ValueKey('finish-session')));
  await waitFor(tester, find.byKey(const ValueKey('mood-linistit')));
  await tester.tap(find.byKey(const ValueKey('mood-linistit')));
  await wait(tester, 800);
  final saved = await io(tester, store.all);
  expect(saved, hasLength(1));
  expect(saved.single.trials, isNotEmpty);
  expect(await io(tester, store.unsyncedIds), [saved.single.id]);

  // „La revedere”: Licurici adoarme, copilul apasă „Pe mâine!”.
  await waitFor(tester, find.byKey(const ValueKey('goodbye')));
  await tester.tap(find.byKey(const ValueKey('goodbye')));
  await waitFor(tester, find.text('Atenție'));
  await wait(tester, 500);

  // Părintele: poarta pentru adulți (înmulțirea), apoi „Trimite pe server”.
  await tester.tap(find.byKey(const ValueKey('parent-corner')));
  await waitFor(tester, find.textContaining('Cât fac'));
  const words = {'șase': 6, 'șapte': 7, 'opt': 8, 'nouă': 9};
  final q = tester.widget<Text>(find.textContaining('Cât fac')).data!.replaceAll('?', '').split(' ');
  await tester.tap(find.byKey(ValueKey('gate-${words[q[2]]! * words[q[4]]!}')));
  await waitFor(tester, find.byKey(const ValueKey('sync-sessions')));
  await tester.ensureVisible(find.byKey(const ValueKey('sync-sessions')));
  await tester.tap(find.byKey(const ValueKey('sync-sessions')));
  await waitFor(tester, find.byKey(const ValueKey('sync-email')));

  // Fără acord nu pleacă nimic.
  await tester.enterText(find.byKey(const ValueKey('sync-email')), _email);
  await tester.enterText(find.byKey(const ValueKey('sync-password')), _password);
  await tester.tap(find.byKey(const ValueKey('sync-run')));
  await wait(tester, 500);
  expect(server.sessions, isEmpty);

  await tester.tap(find.byKey(const ValueKey('sync-consent')));
  await wait(tester, 200);
  await tester.tap(find.byKey(const ValueKey('sync-run')));
  await waitFor(tester, find.text('O sesiune trimisă. O vezi în panoul web.'));

  // Pe server: sesiunea întreagă, cu faptele calculate pe tabletă; consimțământul înaintea ei.
  expect(server.consents, ['SYNC']);
  expect(server.sessions, hasLength(1));
  final record = server.sessions.single['record'] as Map;
  expect(record['id'], saved.single.id);
  expect((record['trials'] as List), hasLength(saved.single.trials.length));
  expect(server.sessions.single['facts'], isA<Map>());
  // Pe tabletă: marcată trimisă (o nouă sincronizare n-ar mai trimite nimic).
  expect(await io(tester, store.unsyncedIds), isEmpty);

  // Conexiunile păstrate deschise (keep-alive) se închid acum, nu peste 15 s.
  client.close();
  await tester.pumpWidget(const SizedBox());
  await wait(tester, 10000);
  await io(tester, db.close);
  await io(tester, server.stop);
}
