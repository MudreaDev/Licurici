import 'dart:convert';

import 'package:licurici_dashboard/api.dart';
import 'package:licurici_dashboard/child_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:licurici_core/licurici_core.dart';

/// Versiunea de test pe Vercel: terapeutul adaugă copilul, vede codul de legare, face cod nou și
/// salvează fișa.
class _Server {
  final calls = <String>[];
  var code = 'ABCD-2345';
  var linked = false;
  Map<String, dynamic> child = {'id': 'c1', 'nickname': 'Ilinca', 'birthYear': 2020, 'notes': '', 'goals': '', 'linked': false};

  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst('/api/v1', '');
    calls.add('${r.method} $path');
    if (r.method == 'GET' && path == '/children') return json([child]);
    if (r.method == 'POST' && path == '/children') {
      final b = jsonDecode(r.body) as Map;
      child = {...child, 'nickname': b['nickname'], 'birthYear': b['birthYear'], 'goals': b['goals']};
      return json({...child, 'code': code, 'url': 'https://panou.test/c/$code'}, 201);
    }
    if (r.method == 'PATCH' && path == '/children/c1') {
      child = {...child, ...(jsonDecode(r.body) as Map).cast<String, dynamic>()};
      return json(child);
    }
    if (path == '/children/c1/link') {
      if (r.method == 'POST') {
        code = 'WXYZ-6789';
        if ((jsonDecode(r.body) as Map)['unlink'] == true) linked = false;
      }
      return json({'code': code, 'url': 'https://panou.test/c/$code', 'linked': linked});
    }
    return json({'statusCode': 404, 'message': 'Nu există.'}, 404);
  }
}

Widget _app(_Server server, Widget home, {GoRouter? router}) => ProviderScope(
  overrides: [apiClientProvider.overrideWithValue(ApiClient(client: MockClient(server.handle), baseUrl: 'http://api/api/v1'))],
  child: router == null ? MaterialApp(home: Scaffold(body: SingleChildScrollView(child: home))) : MaterialApp.router(routerConfig: router),
);

void main() {
  testWidgets('fișa copilului: codul de legare, cod nou, salvarea fișei', (tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = _Server();
    final history = demoChildren().first;
    final kid = ChildHistory(
      ChildProfile(id: 'c1', nickname: 'Ilinca', ageYears: 6, activeSteps: history.child.activeSteps, masteredSteps: const []),
      const [],
    );
    await tester.pumpWidget(_app(server, ChildCardPanel(history: kid)));
    await tester.pumpAndSettle();
    expect(find.text('ABCD-2345'), findsOneWidget);
    expect(find.text('Nicio tabletă legată încă.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-code')));
    await tester.pumpAndSettle();
    expect(find.text('WXYZ-6789'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Ce lucrăm acum (obiective)'), 'Așteptarea rândului');
    await tester.tap(find.byKey(const ValueKey('card-save')));
    await tester.pumpAndSettle();
    expect(server.calls, contains('PATCH /children/c1'));
    expect(server.child['goals'], 'Așteptarea rândului');
  });

  testWidgets('„Adaugă copil”: formularul trimite fișa și duce la copil', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = _Server();
    final router = GoRouter(
      initialLocation: '/specialist',
      routes: [
        GoRoute(path: '/specialist', builder: (_, _) => const Scaffold(body: Center(child: AddChildButton()))),
        GoRoute(path: '/specialist/copil/:id', builder: (_, s) => Scaffold(body: Text('copil ${s.pathParameters['id']}'))),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(server, const SizedBox(), router: router));
    await tester.tap(find.byKey(const ValueKey('add-child')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('child-nickname')), 'Matei');
    await tester.enterText(find.byKey(const ValueKey('child-year')), '2019');
    await tester.enterText(find.byKey(const ValueKey('child-goals')), 'Atenția comună');
    await tester.tap(find.byKey(const ValueKey('child-save')));
    await tester.pumpAndSettle();
    expect(server.calls, contains('POST /children'));
    expect(server.child['nickname'], 'Matei');
    expect(server.child['birthYear'], 2019);
    expect(find.text('copil c1'), findsOneWidget);
  });
}
