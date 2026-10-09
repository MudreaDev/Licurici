import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/settings.dart';
import 'session.dart';
import 'sync.dart';
import 'token_vault.dart';

final syncClientProvider = Provider<SyncClient>((ref) => SyncClient());

/// Starea trimiterii automate, pentru „Pentru părinți”.
class AutoSyncState {
  const AutoSyncState({this.enabled = false, this.lastAt, this.lastSent = 0, this.problem});

  final bool enabled;
  final DateTime? lastAt;
  final int lastSent;

  /// Ce n-a mers la ultima încercare (null = totul bine). Fără rețea nu e o problemă:
  /// sesiunile așteaptă pe tabletă și pleacă data viitoare.
  final String? problem;
}

/// Trimiterea automată (ADR-011): după fiecare sesiune încheiată și la pornire, dacă părintele
/// a ales-o. Tăcută pentru copil: nicio eroare pe ecranul lui; sesiunile netrimise rămân în
/// outbox. Dacă serverul refuză sesiunea păstrată (parolă schimbată, cont șters), se oprește
/// singură, iar „Pentru părinți” cere reconectarea.
class AutoSync extends Notifier<AutoSyncState> {
  /// Apelurile către server merg pe rând: fiecare rotește refresh tokenul, iar două în paralel
  /// ar folosi același token (al doilea ar fi refuzat și trimiterea s-ar opri).
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() task) {
    final run = _tail.then((_) => task());
    _tail = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  @override
  AutoSyncState build() {
    Future.microtask(_load);
    return const AutoSyncState();
  }

  Future<void> _load() async {
    final token = await ref.read(tokenVaultProvider).read();
    if (token != null && !state.enabled) state = AutoSyncState(enabled: true, lastAt: state.lastAt);
  }

  /// Pornită din fereastra „Trimite pe server”, cu refresh tokenul primit la autentificare.
  Future<void> enable(String refreshToken) async {
    await ref.read(tokenVaultProvider).write(refreshToken);
    state = AutoSyncState(enabled: true, lastAt: DateTime.now());
  }

  Future<void> disable() async {
    await ref.read(tokenVaultProvider).write(null);
    state = const AutoSyncState();
  }

  /// „Se joacă acum” în panou, la începutul sesiunii. Fără rețea sau fără trimitere automată, nimic.
  Future<void> announcePlaying() => _serial(() async {
    final vault = ref.read(tokenVaultProvider);
    final token = await vault.read();
    if (token == null) return;
    try {
      await ref.read(syncClientProvider).announcePlaying(refreshToken: token, onRefreshToken: vault.write);
    } on SyncException catch (e) {
      if (e.signedOut) await _signedOut();
    }
  });

  Future<void> _signedOut() async {
    await ref.read(tokenVaultProvider).write(null);
    state = const AutoSyncState(problem: 'Conectarea a expirat (sau parola s-a schimbat). Trimite din nou manual.');
  }

  /// Încearcă acum (fără să aștepte nimeni rezultatul). Întoarce câte sesiuni au plecat.
  Future<int> trigger() => _serial(_trigger);

  Future<int> _trigger() async {
    final vault = ref.read(tokenVaultProvider);
    final token = await vault.read();
    if (token == null) return 0;
    try {
      final settings = ref.read(settingsProvider);
      final n = await ref.read(syncClientProvider).run(
        store: ref.read(sessionStoreProvider),
        refreshToken: token,
        onRefreshToken: vault.write,
        consent: true,
        plan: (hidden: settings.hiddenGames, at: settings.hiddenGamesAt),
        onPlan: ref.read(settingsProvider.notifier).applyPlan,
      );
      state = AutoSyncState(enabled: true, lastAt: DateTime.now(), lastSent: n);
      return n;
    } on SyncException catch (e) {
      if (e.signedOut) {
        await _signedOut();
      } else {
        state = AutoSyncState(
          enabled: true,
          lastAt: state.lastAt,
          lastSent: state.lastSent,
          // Fără rețea: încercăm la următoarea sesiune; altfel arătăm mesajul serverului.
          problem: e.status == null ? null : e.message,
        );
      }
      return 0;
    }
  }
}

final autoSyncProvider = NotifierProvider<AutoSync, AutoSyncState>(AutoSync.new);
