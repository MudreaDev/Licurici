import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings.dart';

import '../../data/auto_sync.dart';
import '../../data/session.dart';
import '../../data/sync.dart';

/// „Trimite pe server”: contul părintelui + acord explicit (nebifat implicit), apoi doar
/// sesiunile netrimise. Fără acord, nimic nu pleacă de pe tabletă.
Future<void> showSyncDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SyncDialog());

class _SyncDialog extends ConsumerStatefulWidget {
  const _SyncDialog();

  @override
  ConsumerState<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends ConsumerState<_SyncDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _consent = false;

  /// Contul are autentificarea în doi pași: după parola corectă se cere codul.
  bool _askCode = false;

  /// „Trimite automat de acum”: tableta păstrează doar refresh tokenul (nu parola).
  bool _auto = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? refresh;
    try {
      final n = await ref
          .read(syncClientProvider)
          .run(
            store: ref.read(sessionStoreProvider),
            email: _email.text,
            password: _password.text,
            code: _askCode ? _code.text.trim() : null,
            consent: _consent,
            plan: (
              hidden: ref.read(settingsProvider).hiddenGames,
              avoid: ref.read(settingsProvider).avoid,
              at: ref.read(settingsProvider).hiddenGamesAt,
            ),
            onPlan: ref.read(settingsProvider.notifier).applyPlan,
            onRefreshToken: _auto ? (t) => refresh = t : null,
          );
      if (refresh != null) await ref.read(autoSyncProvider.notifier).enable(refresh!);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'Totul era deja trimis.'
                : n == 1
                    ? 'O sesiune trimisă. O vezi în panoul web.'
                    : '$n sesiuni trimise. Le vezi în panoul web.',
          ),
        ),
      );
    } on SyncException catch (e) {
      setState(() {
        _error = e.message;
        _askCode |= e.needsTotp;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Trimite sesiunile pe server'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('sync-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mailul părintelui',
              ),
            ),
            TextField(
              key: const ValueKey('sync-password'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Parola'),
            ),
            if (_askCode)
              TextField(
                key: const ValueKey('sync-code'),
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Codul din aplicația de autentificare'),
              ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey('sync-consent'),
              contentPadding: EdgeInsets.zero,
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              title: const Text(
                'Sunt de acord ca sesiunile copilului (rezultate, timpi, dispoziția aleasă; fără nume) '
                'să fie trimise pe server, ca să le văd în panou. Pot retrage acordul oricând.',
              ),
            ),
            CheckboxListTile(
              key: const ValueKey('sync-auto'),
              contentPadding: EdgeInsets.zero,
              value: _auto,
              onChanged: (v) => setState(() => _auto = v ?? false),
              title: const Text(
                'Trimite automat de acum înainte, la finalul fiecărei sesiuni. Tableta rămâne conectată '
                '(fără să păstreze parola); opresc oricând din „Pentru părinți”.',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Renunță'),
      ),
      FilledButton(
        key: const ValueKey('sync-run'),
        onPressed: _busy ? null : _run,
        child: Text(_busy ? 'Se trimite…' : 'Trimite'),
      ),
    ],
  );
}
