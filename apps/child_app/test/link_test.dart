import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:licurici/app/theme.dart';
import 'package:licurici/data/auto_sync.dart';
import 'package:licurici/data/sync.dart';
import 'package:licurici/data/token_vault.dart';
import 'package:licurici/features/link/link_screen.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/main.dart';
import 'package:licurici/shared/voice.dart';

import 'layout_test.dart' show loadFonts, settle;

void main() {
  setUpAll(loadFonts);
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  test('codul se recunoaște scris sau din legătură; serverul vine din legătură', () {
    expect(codeFromInput('abcd-2345'), 'ABCD-2345');
    expect(codeFromInput(' ABCD 2345 '), 'ABCD-2345');
    expect(codeFromInput('https://panou.exemplu.md/c/ABCD-2345'), 'ABCD-2345');
    expect(codeFromInput('123'), isNull);
    expect(serverForInput('https://panou.exemplu.md/c/ABCD-2345'), 'https://panou.exemplu.md/api/v1');
    expect(serverForInput('ABCD-2345'), '$linkServer/api/v1');
  });

  test('legarea se păstrează în setări (serverul și porecla)', () {
    final s = const AppSettings().copyWith(serverUrl: 'https://x/api/v1', linkedNickname: 'Ilinca');
    final back = AppSettings.fromJson(s.toJson());
    expect(back.serverUrl, 'https://x/api/v1');
    expect(back.linkedNickname, 'Ilinca');
    expect(back.copyWith(unlink: true).serverUrl, isNull);
    expect(AppSettings.fromJson(const {}).welcomeSeen, isTrue, reason: 'setările vechi nu mai văd „Bun venit”');
  });

  testWidgets('ecranul de legare: fără acord nu pleacă nimic; cu cod bun, tableta e legată', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <String>[];
    final client = MockClient((r) async {
      requests.add('${r.method} ${r.url}');
      if (r.url.path.endsWith('/device/link')) {
        final b = jsonDecode(r.body) as Map;
        expect(b['code'], 'ABCD-2345');
        expect(b['consent'], isTrue);
        return http.Response(jsonEncode({'accessToken': 'a', 'refreshToken': 'r1', 'child': {'id': 'c1', 'nickname': 'Ilinca'}}), 200);
      }
      return http.Response(jsonEncode({'statusCode': 503, 'message': 'x'}), 503);
    });
    final vault = MemoryTokenVault();
    final container = ProviderContainer(
      overrides: [
        voiceProvider.overrideWithValue(const SilentSpeaker()),
        tokenVaultProvider.overrideWithValue(vault),
        linkClientProvider.overrideWithValue((base) => SyncClient(client: client, baseUrl: base)),
        syncClientProvider.overrideWithValue(SyncClient(client: client, baseUrl: 'https://panou.exemplu.md/api/v1')),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/legare',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Acasă'))),
        GoRoute(path: '/legare', builder: (_, _) => const LinkScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: MaterialApp.router(theme: buildTheme(calm: false), routerConfig: router)),
    );
    await settle(tester, 2);
    await tester.enterText(find.byKey(const ValueKey('link-input')), 'https://panou.exemplu.md/c/abcd-2345');
    await tester.pump();
    // Fără bifa părintelui, butonul nu merge.
    expect(tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('link-submit'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('link-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('link-submit')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await settle(tester, 3);
    expect(requests.first, 'POST https://panou.exemplu.md/api/v1/device/link');
    expect(find.text('Gata! Tableta e legată de Ilinca.'), findsOneWidget);
    expect(await tester.runAsync(vault.read), isNotNull);
    final s = container.read(settingsProvider);
    expect(s.serverUrl, 'https://panou.exemplu.md/api/v1');
    expect(s.linkedNickname, 'Ilinca');
    expect(container.read(autoSyncProvider).enabled, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('prima pornire: „Bun venit”, apoi „Începem să ne jucăm” duce acasă', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        voiceProvider.overrideWithValue(const SilentSpeaker()),
        settingsProvider.overrideWith(() => SettingsNotifier(const AppSettings(welcomeSeen: false))),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const LicuriciApp()));
    for (var i = 0; i < 40 && find.byKey(const ValueKey('welcome-play')).evaluate().isEmpty; i++) {
      await settle(tester, 1);
    }
    expect(find.byKey(const ValueKey('welcome-code')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-play')));
    for (var i = 0; i < 40 && find.byKey(const ValueKey('domain-ATN')).evaluate().isEmpty; i++) {
      await settle(tester, 1);
    }
    expect(find.byKey(const ValueKey('domain-ATN')), findsOneWidget);
    expect(container.read(settingsProvider).welcomeSeen, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
