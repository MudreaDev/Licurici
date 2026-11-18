import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/settings/settings.dart';
import 'package:licurici_core/licurici_core.dart';

void main() {
  test('două jocuri complete la același nivel, inclusiv după repornire', () async {
    var persisted = const AppSettings(levelRepeats: 2);
    ProviderContainer start() => ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(persisted, (s) => persisted = AppSettings.fromJson(s.toJson()))),
    ]);
    Future<void> complete(ProviderContainer c, int level) async {
      final session = c.read(sessionProvider.notifier);
      session.record((r) => r.add(Trial(stepId: 'COG4', gameId: 'turnul', correct: true, promptLevel: PromptLevel.p0, at: DateTime.now(), level: level)));
      await session.checkpoint();
    }
    var c = start();
    await complete(c, 1);
    expect(c.read(settingsProvider).levelOf('turnul'), 1);
    expect(persisted.repetitions['turnul'], 1);
    c.dispose();
    c = start();
    await complete(c, 1);
    expect(c.read(settingsProvider).levelOf('turnul'), 2);
    expect(persisted.repetitions['turnul'], 0);
    await c.read(sessionProvider.notifier).checkpoint();
    expect(c.read(settingsProvider).levelOf('turnul'), 2);
    c.dispose();
  });

  test('o schimbare a planului nu resetează nivelul deja atins', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = c.read(settingsProvider.notifier);
    s.applyPlan({}, {'turnul': 2}, DateTime.utc(2026, 1, 1));
    s.setGameLevel('turnul', 4);
    s.applyPlan({}, {'turnul': 2}, DateTime.utc(2026, 1, 2));
    expect(c.read(settingsProvider).levels['turnul'], 4);
    s.applyPlan({}, {'turnul': 3}, DateTime.utc(2026, 1, 3));
    expect(c.read(settingsProvider).levels['turnul'], 3);
  });

  test('o salvare parțială nu numără jocul ca terminat', () async {
    final store = MemorySessionStore();
    final c = ProviderContainer(overrides: [
      settingsProvider.overrideWith(() => SettingsNotifier(const AppSettings(levelRepeats: 1))),
      sessionStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(c.dispose);
    final session = c.read(sessionProvider.notifier);
    session.record((r) => r.add(Trial(stepId: 'COG4', gameId: 'turnul', correct: true, promptLevel: PromptLevel.p0, at: DateTime.now(), level: 1)));
    await session.checkpoint(countCompletion: false);
    expect(c.read(settingsProvider).levels['turnul'], isNull);
    expect((await store.all()).single.trials, hasLength(1));
    await session.checkpoint();
    expect(c.read(settingsProvider).levelOf('turnul'), 2);
  });
}
