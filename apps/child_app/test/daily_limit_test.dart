import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici/features/settings/daily_limit.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici/shared/voice.dart';

void main() {
  testWidgets('limita păstrată după repornire duce la pauză, cu poarta părintelui', (tester) async {
    final now = DateTime.now();
    final day = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final saved = AppSettings.fromJson(const AppSettings(dailyMinutes: 1, usageMs: 60000).copyWith(usageDay: day).toJson());
    final container = ProviderContainer(overrides: [settingsProvider.overrideWith(() => SettingsNotifier(saved)), voiceProvider.overrideWithValue(const SilentSpeaker())]);
    addTearDown(container.dispose);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Jocuri'))),
      GoRoute(path: '/timp-expirat', builder: (_, _) => const DailyLimitScreen()),
      GoRoute(path: '/parinte', builder: (_, _) => const Scaffold(body: Text('Admin'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router, builder: (_, child) => DailyLimit(router: router, child: child!)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gata pe azi! Ne jucăm din nou mâine.'), findsOneWidget);
    await tester.tap(find.text('Pentru părinți'));
    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('timpul se păstrează pe zi și se resetează în ziua următoare', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final settings = c.read(settingsProvider.notifier);
    settings.addUsage('2026-11-18', 40000);
    settings.addUsage('2026-11-18', 20000);
    expect(c.read(settingsProvider).usageMs, 60000);
    settings.addUsage('2026-11-19', 1000);
    expect(c.read(settingsProvider).usageMs, 1000);
  });

  testWidgets('timpul în fundal nu se adună', (tester) async {
    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(const AppSettings(dailyMinutes: 1))),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('Jocuri')))]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router, builder: (_, child) => DailyLimit(router: router, child: child!)),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(settingsProvider).usageMs, greaterThanOrEqualTo(1000));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = container.read(settingsProvider).usageMs;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(settingsProvider).usageMs, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });
}
