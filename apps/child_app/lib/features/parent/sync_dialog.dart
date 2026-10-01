import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/session.dart';
import '../../data/sync.dart';

final syncClientProvider = Provider<SyncClient>((ref) => SyncClient());

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
  bool _consent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final n = await ref
          .read(syncClientProvider)
          .run(
            store: ref.read(sessionStoreProvider),
            email: _email.text,
            password: _password.text,
            consent: _consent,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'Totul era deja trimis.'
                : '$n sesiuni trimise. Le vezi în panoul web.',
          ),
        ),
      );
    } on SyncException catch (e) {
      setState(() => _error = e.message);
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
