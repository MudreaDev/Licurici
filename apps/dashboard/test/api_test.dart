import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_dashboard/api.dart';
import 'package:licurici_dashboard/app.dart';

const childId = '0190a1b2-0000-7000-8000-000000000001';

/// Backend-ul simulat: aceleași rute și forme de răspuns ca `backend/src/api/controllers.ts`.
class FakeBackend {
  FakeBackend({this.consent = true});
  bool consent;
  int accessVersion = 1;
  final calls = <String>[];
  final sessions = demoChildren().first.sessions;

  http.Response json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst('/api/v1', '');
    calls.add('${r.method} $path');
    if (path == '/auth/login') {
      final b = jsonDecode(r.body) as Map;
      if (b['password'] != 'parola-lunga-1')
        return json({
          'statusCode': 401,
          'message': 'E-mail sau parolă greșită.',
        }, 401);
      return json({
        'accessToken': 'a$accessVersion',
        'refreshToken': 'r$accessVersion',
        'expiresIn': 900,
      });
    }
    if (path == '/auth/refresh') {
      accessVersion++;
      return json({
        'accessToken': 'a$accessVersion',
        'refreshToken': 'r$accessVersion',
        'expiresIn': 900,
      });
    }
    if (r.headers['authorization'] != 'Bearer a$accessVersion') {
      return json({'statusCode': 401, 'message': 'Neautentificat.'}, 401);
    }
    if (path == '/children') {
      return json([
        {
          'id': childId,
          'nickname': 'Ilinca',
          'avatar': '🐞',
          'birthYear': 2020,
        },
      ]);
    }
    if (path == '/children/$childId/sessions') {
      return json([
        for (final s in sessions)
          {'id': s.id, 'record': s.toJson(), 'hasSummary': false},
      ]);
    }
    if (path.endsWith('/summary')) {
      if (!consent) {
        return json({
          'statusCode': 403,
          'message':
              'Părintele nu și-a dat consimțământul pentru rezumatele scrise de AI.',
        }, 403);
      }
      return json({
        'summary': {
          'parent': 'Ilinca a lucrat foarte bine la emoții.',
          'homeIdea': 'Jucați „ghicește emoția”.',
          'specialist': ['EMO3: independență 75%.'],
          'planSuggestions': ['De confirmat EMO3.'],
        },
        'cached': false,
      });
    }
    return json({'statusCode': 404, 'message': 'Nu există.'}, 404);
  }
}

Future<void> pumpDashboard(WidgetTester tester, FakeBackend backend) async {
  tester.view.physicalSize = const Size(1440, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = createRouter(initialLocation: '/autentificare');
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(
            client: MockClient(backend.handle),
            baseUrl: 'http://api/api/v1',
          ),
        ),
      ],
      child: DashboardApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, String password) async {
  await tester.enterText(
    find.byKey(const ValueKey('login-email')),
    'ana@example.md',
  );
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    password,
  );
  await tester.tap(find.byKey(const ValueKey('login-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'autentificare → copilul real în panoul specialistului → rezumat AI',
    (tester) async {
      final backend = FakeBackend();
      await pumpDashboard(tester, backend);

      await signIn(tester, 'gresita-gresita');
      expect(find.text('E-mail sau parolă greșită.'), findsOneWidget);

      await signIn(tester, 'parola-lunga-1');
      expect(find.text('Ieși'), findsOneWidget);
      await tester.tap(find.text('Sunt specialist'));
      await tester.pumpAndSettle();
      expect(find.text('Ilinca'), findsWidgets);
      expect(
        find.text('Tudor'),
        findsNothing,
      ); // după autentificare, fără copii demo

      await tester.tap(find.text('Ilinca').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-summary')));
      await tester.pumpAndSettle();
      expect(
        find.text('Ilinca a lucrat foarte bine la emoții.'),
        findsOneWidget,
      );
      expect(
        backend.calls.last,
        'POST /children/$childId/sessions/${backend.sessions.last.id}/summary',
      );
    },
  );

  testWidgets(
    'fără consimțământ: mesajul serverului, rezumatul din reguli rămâne',
    (tester) async {
      final backend = FakeBackend(consent: false);
      await pumpDashboard(tester, backend);
      await signIn(tester, 'parola-lunga-1');
      await tester.tap(find.text('Sunt specialist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ilinca').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-summary')));
      await tester.pumpAndSettle();
      expect(find.text('Rezumatul AI nu e disponibil'), findsOneWidget);
      expect(find.textContaining('consimțământul'), findsOneWidget);
    },
  );

  test('tokenul expirat se reîmprospătează o dată, transparent', () async {
    final backend = FakeBackend();
    final api = ApiClient(
      client: MockClient(backend.handle),
      baseUrl: 'http://api/api/v1',
    );
    await api.login('ana@example.md', 'parola-lunga-1');
    backend.accessVersion = 5; // serverul a „expirat” tokenul curent
    final kids = await api.children();
    expect(kids.single.child.nickname, 'Ilinca');
    expect(kids.single.sessions, hasLength(backend.sessions.length));
    expect(backend.calls, contains('POST /auth/refresh'));
  });
}
