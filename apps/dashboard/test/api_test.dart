import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_dashboard/api.dart';
import 'package:licurici_dashboard/app.dart';
import 'package:licurici_dashboard/live.dart';

const childId = '0190a1b2-0000-7000-8000-000000000001';

/// Backend-ul simulat: aceleași rute și forme de răspuns ca `backend/src/api/controllers.ts`.
class FakeBackend {
  FakeBackend({this.consent = true});
  bool consent;
  int accessVersion = 1;
  final calls = <String>[];
  final consents = <String, bool>{
    'SYNC': true,
    'AI_SUMMARY': false,
    'THERAPIST_SHARING': false,
    'WEEKLY_REPORT': false,
    'PUSH_NOTIFICATIONS': false,
  };
  final shares = <Map<String, dynamic>>[];
  bool deleted = false;
  bool accountDeleted = false;
  bool totp = false;
  bool totpRequired = false;
  bool verified = false;
  String? registeredRole;
  final mails = <String>[];
  final questions = <Map<String, dynamic>>[];
  final sessions = demoChildren().first.sessions;
  Map<String, Object?> plan = {'hiddenGames': <String>[], 'updatedAt': null, 'updatedBy': null};

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
      if (b['password'] != 'parola-lunga-1') {
        return json({
          'statusCode': 401,
          'message': 'E-mail sau parolă greșită.',
        }, 401);
      }
      if (totpRequired && b['code'] != '123456') {
        return json({
          'statusCode': 401,
          'message': b['code'] == null
              ? 'Introdu codul din aplicația de autentificare.'
              : 'Codul nu e corect.',
          if (b['code'] == null) 'details': ['totp'],
        }, 401);
      }
      return json({
        'accessToken': 'a$accessVersion',
        'refreshToken': 'r$accessVersion',
        'expiresIn': 900,
      });
    }
    if (path == '/children/$childId/ask') {
      if (!consent) {
        return json({'statusCode': 403, 'message': 'Părintele nu și-a dat consimțământul pentru răspunsurile scrise de AI.'}, 403);
      }
      final b = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      questions.add(b);
      return json({'answer': 'Răspunsul ${questions.length}.', 'sessions': 4});
    }
    if (path == '/auth/register') {
      registeredRole = (jsonDecode(r.body) as Map)['role'] as String?;
      mails.add('verify');
      return json({'accessToken': 'a$accessVersion', 'refreshToken': 'r$accessVersion', 'expiresIn': 900}, 201);
    }
    if (path == '/auth/password/forgot') {
      mails.add('reset');
      return json({'ok': true}, 202);
    }
    if (path == '/auth/verify-email' || path == '/auth/password/reset') {
      if ((jsonDecode(r.body) as Map)['token'] != 'tok-bun-bun-bun-bun-bun') {
        return json({'statusCode': 400, 'message': 'Date invalide.', 'details': ['token: legătura a expirat']}, 400);
      }
      verified = true;
      return json(path == '/auth/verify-email' ? {'verified': true} : {'ok': true});
    }
    if (path == '/me' && r.method == 'GET') {
      return json({'email': 'ana@example.md', 'role': 'PARENT', 'emailVerified': verified});
    }
    if (path == '/me/verify-email') {
      mails.add('verify');
      return json({'sent': true}, 202);
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
      if (deleted) return json([]);
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
    if (path == '/consents') {
      if (r.method == 'POST') {
        final b = jsonDecode(r.body) as Map;
        consents[b['purpose'] as String] = b['granted'] as bool;
      }
      return json(consents);
    }
    if (path == '/children/$childId/plan') {
      if (r.method == 'PUT') {
        final b = jsonDecode(r.body) as Map;
        plan = {
          'hiddenGames': b['hiddenGames'],
          'levels': b['levels'],
          'maxLevels': b['maxLevels'],
          'rounds': b['rounds'],
          'updatedAt': '2026-10-09T09:00:00.000Z',
          'updatedBy': 'THERAPIST',
          'history': [
            {'at': '2026-10-09T09:00:00.000Z', 'by': 'THERAPIST', 'hidden': (b['hiddenGames'] as List).length},
          ],
        };
      }
      return json(plan);
    }
    if (path == '/children/$childId/share') {
      if (r.method == 'POST') {
        final b = jsonDecode(r.body) as Map;
        if (b['email'] != 'dr@clinica.md') {
          return json({
            'statusCode': 404,
            'message': 'Nu există un cont de specialist cu acest e-mail.',
          }, 404);
        }
        shares.add({
          'therapistId': 't1',
          'email': 'dr@clinica.md',
          'expiresAt': '2026-12-30T12:00:00.000Z',
        });
        return json(shares.last);
      }
      return json(shares);
    }
    if (path == '/children/$childId/share/t1' && r.method == 'DELETE') {
      shares.clear();
      return http.Response('', 204);
    }
    if (path == '/me/export') {
      return json({'format': 'licurici-export', 'version': 1, 'children': []});
    }
    if (path == '/me/2fa') return json({'enabled': totp});
    if (path == '/me/2fa/setup') {
      return json({
        'secret': 'JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
        'otpauthUrl': 'otpauth://totp/Licurici:ana?secret=JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP',
      });
    }
    if (path == '/me/2fa/enable') {
      if ((jsonDecode(r.body) as Map)['code'] != '123456') {
        return json({
          'statusCode': 400,
          'message': 'Date invalide.',
          'details': ['code: codul nu e corect'],
        }, 400);
      }
      totp = true;
      return json({'enabled': true});
    }
    if (path == '/me/2fa/disable') {
      totp = false;
      return json({'enabled': false});
    }
    if (path == '/me/delete' && r.method == 'POST') {
      if ((jsonDecode(r.body) as Map)['password'] != 'parola-lunga-1') {
        return json({'statusCode': 401, 'message': 'Parola nu e corectă.'}, 401);
      }
      accountDeleted = true;
      return json({'purgeAt': '2026-10-15T12:00:00.000Z'}, 202);
    }
    if (path == '/children/$childId' && r.method == 'DELETE') {
      deleted = true;
      return json({'purgeAt': '2026-10-08T12:00:00.000Z'}, 202);
    }
    return json({'statusCode': 404, 'message': 'Nu există.'}, 404);
  }
}

/// Canalul live simulat: ține abonamentul, testul trimite evenimentele.
class FakeLive implements LiveChannel {
  List<String> watched = const [];
  void Function(String type, Map<String, dynamic> data)? onEvent;
  bool closed = false;

  @override
  void open({
    required Future<String?> Function() token,
    required Iterable<String> childIds,
    required void Function(String type, Map<String, dynamic> data) onEvent,
  }) {
    watched = childIds.toList();
    this.onEvent = onEvent;
    closed = false;
  }

  @override
  void close() => closed = true;
}

final fakeLive = FakeLive();

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
        liveChannelProvider.overrideWithValue(fakeLive),
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

  testWidgets('contul meu: consimțăminte și partajarea cu specialistul', (
    tester,
  ) async {
    final backend = FakeBackend();
    await pumpDashboard(tester, backend);
    await signIn(tester, 'parola-lunga-1');
    await tester.tap(find.byKey(const ValueKey('account')));
    await tester.pumpAndSettle();

    // Consimțământul pentru rezumatele AI: dat din panou, salvat pe server.
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('consent-AI_SUMMARY')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('consent-AI_SUMMARY')));
    await tester.pumpAndSettle();
    expect(backend.consents['AI_SUMMARY'], isTrue);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('consent-AI_SUMMARY')),
          )
          .value,
      isTrue,
    );

    // Invitație cu e-mail necunoscut → mesajul serverului; apoi corect → apare; revocare → dispare.
    Future<void> invite(String email) async {
      await tester.tap(find.byKey(const ValueKey('share-$childId')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('share-email')), email);
      await tester.tap(find.byKey(const ValueKey('share-confirm')));
      await tester.pumpAndSettle();
    }

    await invite('altcineva@x.md');
    expect(
      find.text('Nu există un cont de specialist cu acest e-mail.'),
      findsOneWidget,
    );
    await invite('dr@clinica.md');
    expect(find.text('Acces până la 2026-12-30'), findsOneWidget);
    // Lista arată cine e specialistul, nu doar „Specialist”.
    expect(find.text('dr@clinica.md'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unshare-t1')));
    await tester.pumpAndSettle();
    expect(find.text('Acces până la 2026-12-30'), findsNothing);
    expect(backend.calls, contains('DELETE /children/$childId/share/t1'));
  });

  testWidgets(
    'datele mele: export copiat; ștergerea profilului cere confirmare',
    (tester) async {
      final backend = FakeBackend();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await pumpDashboard(tester, backend);
      await signIn(tester, 'parola-lunga-1');
      await tester.tap(find.byKey(const ValueKey('account')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('export-data')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('export-data')));
      await tester.pumpAndSettle();
      expect(copied, contains('licurici-export'));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('delete-$childId')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('delete-$childId')));
      await tester.pumpAndSettle();
      expect(backend.deleted, isFalse); // doar dialogul de confirmare
      await tester.tap(find.byKey(const ValueKey('delete-confirm')));
      await tester.pumpAndSettle();
      expect(backend.deleted, isTrue);
      expect(
        find.text('Profil șters. Ștergere definitivă la 2026-10-08.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('delete-$childId')), findsNothing);
    },
  );

  testWidgets('ștergerea contului cere parola; apoi panoul iese din cont', (
    tester,
  ) async {
    final backend = FakeBackend();
    await pumpDashboard(tester, backend);
    await signIn(tester, 'parola-lunga-1');
    await tester.tap(find.byKey(const ValueKey('account')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('delete-account')),
      200,
    );

    Future<void> deleteWith(String password) async {
      await tester.tap(find.byKey(const ValueKey('delete-account')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('delete-account-password')),
        password,
      );
      await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
      await tester.pumpAndSettle();
    }

    await deleteWith('gresita-123');
    expect(backend.accountDeleted, isFalse);
    expect(find.text('Parola nu e corectă.'), findsOneWidget);

    await deleteWith('parola-lunga-1');
    expect(backend.accountDeleted, isTrue);
    expect(
      find.text('Contul a fost șters. Ștergere definitivă la 2026-10-15.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('account')), findsNothing);
    expect(find.byKey(const ValueKey('sign-in')), findsOneWidget);
  });

  testWidgets('2FA: la intrare se cere codul; din cont se activează cu primul cod', (
    tester,
  ) async {
    final backend = FakeBackend()..totpRequired = true;
    await pumpDashboard(tester, backend);
    await signIn(tester, 'parola-lunga-1');
    // Parola e bună: apare câmpul pentru cod.
    expect(find.byKey(const ValueKey('login-code')), findsOneWidget);
    expect(find.text('Introdu codul din aplicația de autentificare.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('login-code')), '000000');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Codul nu e corect.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('login-code')), '123456');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account')), findsOneWidget);

    // Din „Contul meu”: cheia apare grupată; un cod greșit nu activează, cel bun da.
    await tester.tap(find.byKey(const ValueKey('account')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('totp-toggle')), 200);
    await tester.tap(find.byKey(const ValueKey('totp-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('JBSW Y3DP EHPK 3PXP JBSW Y3DP EHPK 3PXP'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('totp-code')), '999999');
    await tester.tap(find.byKey(const ValueKey('totp-confirm')));
    await tester.pumpAndSettle();
    expect(backend.totp, isFalse);
    await tester.enterText(find.byKey(const ValueKey('totp-code')), '123456');
    await tester.tap(find.byKey(const ValueKey('totp-confirm')));
    await tester.pumpAndSettle();
    expect(backend.totp, isTrue);
    expect(find.text('Opresc'), findsOneWidget);
  });

  testWidgets('specialistul scoate o arie din jocurile copilului și salvează pe server', (tester) async {
    final backend = FakeBackend();
    await pumpDashboard(tester, backend);
    await signIn(tester, 'parola-lunga-1');
    await tester.tap(find.text('Sunt specialist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ilinca').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jocuri'));
    await tester.pumpAndSettle();
    expect(find.text('Copilul vede toate jocurile.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-domain-FEX')));
    await tester.pumpAndSettle();
    // Pentru „Emoții”: pornește de la 3 și nu urcă peste 6 (câmpurile vin din schema parametrilor).
    await tester.tap(find.textContaining('EMO ·'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('plan-start-emotii')));
    await tester.tap(find.byKey(const ValueKey('plan-start-emotii')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pornește de la 3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-max-emotii')));
    await tester.pumpAndSettle();
    // Plafonul nu se poate pune sub pornire.
    expect(find.text('Nu urcă peste 2'), findsNothing);
    await tester.tap(find.text('Nu urcă peste 6').last);
    await tester.pumpAndSettle();
    // „Runde” apare doar la jocurile cu alegere (Emoții da, Semaforul nu).
    expect(find.byKey(const ValueKey('plan-rounds-semaforul')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('plan-rounds-emotii')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Runde, cel mult 4').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('plan-save')));
    await tester.tap(find.byKey(const ValueKey('plan-save')));
    await tester.pumpAndSettle();
    expect(backend.calls.last, 'PUT /children/$childId/plan');
    final hidden = (backend.plan['hiddenGames']! as List).cast<String>();
    expect(hidden, containsAll(['pescarul', 'simon', 'semaforul']));
    expect(hidden, isNot(contains('emotii')));
    expect(backend.plan['levels'], {'emotii': 3});
    expect(backend.plan['maxLevels'], {'emotii': 6});
    expect(backend.plan['rounds'], {'emotii': 4});
    expect(find.textContaining('Tableta preia lista'), findsOneWidget);
  });

  testWidgets('cont nou: rolul, acordul, apoi „Contul meu” cere confirmarea adresei', (tester) async {
    final backend = FakeBackend();
    await pumpDashboard(tester, backend);
    await tester.tap(find.byKey(const ValueKey('to-register')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('login-email')), 'dr@example.md');
    await tester.enterText(find.byKey(const ValueKey('login-password')), 'parola-lunga-1');
    // Fără acord, butonul nu merge.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('login-submit'))).onPressed, isNull);
    await tester.tap(find.text('Sunt specialist'));
    await tester.tap(find.byKey(const ValueKey('register-accept')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(backend.registeredRole, 'THERAPIST');
    expect(find.byKey(const ValueKey('verify-banner')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('verify-resend')));
    await tester.pumpAndSettle();
    expect(backend.mails, ['verify', 'verify']);
    expect(find.text('Am trimis din nou legătura.'), findsOneWidget);
  });

  testWidgets('am uitat parola → legătura din e-mail → parola nouă', (tester) async {
    final backend = FakeBackend();
    await pumpDashboard(tester, backend);
    await tester.tap(find.byKey(const ValueKey('to-forgot')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-password')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('login-email')), 'ana@example.md');
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();
    expect(backend.mails, ['reset']);
    expect(find.byKey(const ValueKey('login-info')), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/parola-noua?token=tok-vechi-vechi-vechi-vechi');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reset-password')), 'parola-noua-22');
    await tester.enterText(find.byKey(const ValueKey('reset-again')), 'parola-noua-2');
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Parolele nu sunt la fel.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('reset-again')), 'parola-noua-22');
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Legătura a expirat'), findsOneWidget);

    router.go('/parola-noua?token=tok-bun-bun-bun-bun-bun');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('reset-password')), 'parola-noua-22');
    await tester.enterText(find.byKey(const ValueKey('reset-again')), 'parola-noua-22');
    await tester.tap(find.byKey(const ValueKey('reset-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reset-ok')), findsOneWidget);

    router.go('/confirmare?token=tok-bun-bun-bun-bun-bun');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm-ok')), findsOneWidget);
    router.go('/confirmare?token=altul-altul-altul-altul');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm-error')), findsOneWidget);
  });

  testWidgets('întreabă despre progres: exemplu, apoi întrebarea proprie cu istoricul; fără acord, mesajul serverului', (tester) async {
    final backend = FakeBackend();
    await pumpDashboard(tester, backend);
    await signIn(tester, 'parola-lunga-1');
    await tester.tap(find.text('Sunt specialist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ilinca').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('ask-example-0')), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const ValueKey('ask-example-0')));
    await tester.pumpAndSettle();
    expect(find.text('Răspunsul 1.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('ask-question')), 'Și la emoții?');
    await tester.tap(find.byKey(const ValueKey('ask-send')));
    await tester.pumpAndSettle();
    expect(find.text('Răspunsul 2.'), findsOneWidget);
    expect(backend.questions.last['question'], 'Și la emoții?');
    expect(backend.questions.last['history'], hasLength(2));

    backend.consent = false;
    await tester.enterText(find.byKey(const ValueKey('ask-question')), 'Încă una?');
    await tester.tap(find.byKey(const ValueKey('ask-send')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ask-error')), findsOneWidget);
  });

  testWidgets('canalul live: panoul urmărește copiii și anunță sesiunea nouă', (tester) async {
    final backend = FakeBackend();
    await pumpDashboard(tester, backend);
    await signIn(tester, 'parola-lunga-1');
    expect(fakeLive.watched, [childId]);
    await tester.tap(find.text('Sunt specialist'));
    await tester.pumpAndSettle();
    fakeLive.onEvent!('presence', {'type': 'presence', 'childId': childId, 'playing': true});
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('playing-$childId')), findsWidgets);
    final before = backend.calls.where((c) => c == 'GET /children').length;
    fakeLive.onEvent!('session.synced', {'type': 'session.synced', 'childId': childId, 'count': 1});
    await tester.pumpAndSettle();
    expect(backend.calls.where((c) => c == 'GET /children').length, before + 1);
    expect(find.text('Sesiune nouă de la Ilinca.'), findsOneWidget);
    expect(find.byKey(const ValueKey('playing-$childId')), findsNothing);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ieși'));
    await tester.pumpAndSettle();
    expect(fakeLive.closed, isTrue);
  });
}
