import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'api.dart';
import 'download.dart';

/// Ce înseamnă fiecare consimțământ, spus simplu (README §13). Ordinea = ordinea pe ecran.
const consentTexts = {
  'SYNC': (
    'Sincronizarea sesiunilor',
    'Sesiunile de pe tabletă (rezultate, timpi, dispoziția aleasă; fără nume) sunt păstrate pe server, ca să le vezi aici.',
  ),
  'AI_SUMMARY': (
    'Rezumate scrise de AI',
    'Cifrele agregate ale unei sesiuni (fără nume) sunt trimise la Claude, care scrie rezumatul. Se generează doar la cerere.',
  ),
  'THERAPIST_SHARING': (
    'Partajarea cu specialistul',
    'Specialistul invitat de tine vede sesiunile copilului, doar citire, pe timp limitat.',
  ),
  'WEEKLY_REPORT': (
    'Raport săptămânal',
    'Primești pe e-mail un rezumat al săptămânii.',
  ),
  'PUSH_NOTIFICATIONS': ('Notificări', 'Primești notificări pe telefon.'),
};

/// „Contul meu”: consimțăminte (date / retrase oricând, fiecare decizie e păstrată ca dovadă) și
/// partajarea fiecărui copil cu specialistul.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  Map<String, bool>? _consents;
  List<Map<String, dynamic>> _children = const [];
  final _shares = <String, List<Map<String, dynamic>>>{};
  String? _error;

  ApiClient get _api => ref.read(apiClientProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _load() => _guard(() async {
    final consents = await _api.consents();
    final children = await _api.ownChildren();
    for (final c in children) {
      _shares[c['id'] as String] = await _api.shares(c['id'] as String);
    }
    setState(() {
      _consents = consents;
      _children = children;
    });
  });

  Future<void> _invite(String childId) async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (email == null || email.isEmpty) return;
    await _guard(() async {
      await _api.share(childId, email);
      _shares[childId] = await _api.shares(childId);
    });
  }

  /// Exportul complet: pe web se descarcă un fișier JSON; altfel se copiază în clipboard.
  Future<void> _export() => _guard(() async {
    final json = await _api.exportData();
    final day = DateTime.now().toIso8601String().substring(0, 10);
    final file = 'licurici-datele-mele-$day.json';
    final downloaded = await downloadText(file, json);
    if (!downloaded) await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'Toate datele tale au fost descărcate în fișierul $file.'
                : 'Toate datele tale au fost copiate (JSON). Le poți salva într-un fișier.',
          ),
        ),
      );
  });

  Future<void> _delete(Map<String, dynamic> child) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ștergi profilul „${child['nickname']}”?'),
        content: const Text(
          'Accesul (inclusiv al specialiștilor) se oprește imediat. Datele se șterg definitiv după 7 zile; '
          'până atunci poți scrie la suport ca să anulezi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            key: const ValueKey('delete-confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(() async {
      final purgeAt = await _api.deleteChild(child['id'] as String);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Profil șters. Ștergere definitivă la ${purgeAt.substring(0, 10)}.',
            ),
          ),
        );
    });
  }

  /// Ștergerea contului: explicație clară, parola din nou, apoi ieșirea din cont.
  Future<void> _deleteAccount() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || password.isEmpty) return;
    await _guard(() async {
      final purgeAt = await _api.deleteAccount(password);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      await ref.read(serverChildrenProvider.notifier).signOut();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Contul a fost șters. Ștergere definitivă la ${purgeAt.substring(0, 10)}.',
            ),
          ),
        );
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    final consents = _consents;
    return Scaffold(
      appBar: AppBar(title: const Text('Contul meu')),
      body: consents == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Text(
                  'Acordurile mele',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Le poți da sau retrage oricând. Fiecare decizie e păstrată, cu data ei.',
                ),
                for (final e in consentTexts.entries)
                  SwitchListTile(
                    key: ValueKey('consent-${e.key}'),
                    title: Text(e.value.$1),
                    subtitle: Text(e.value.$2),
                    value: consents[e.key] ?? false,
                    onChanged: (v) => _guard(() async {
                      final next = await _api.setConsent(e.key, v);
                      setState(() => _consents = next);
                    }),
                  ),
                const Divider(height: 40),
                Text(
                  'Datele mele',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tot ce păstrăm despre tine și copiii tăi, într-un format pe care îl poți salva sau muta.',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('export-data'),
                    onPressed: _export,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Descarcă toate datele mele'),
                  ),
                ),
                const Divider(height: 40),
                Text(
                  'Specialiști cu acces',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final c in _children)
                  Card(
                    margin: const EdgeInsets.only(top: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c['nickname'] as String,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          for (final s
                              in _shares[c['id']] ??
                                  const <Map<String, dynamic>>[])
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                s['email'] as String? ?? 'Specialist',
                              ),
                              subtitle: Text(
                                'Acces până la ${(s['expiresAt'] as String).substring(0, 10)}',
                              ),
                              trailing: TextButton(
                                key: ValueKey('unshare-${s['therapistId']}'),
                                onPressed: () => _guard(() async {
                                  await _api.unshare(
                                    c['id'] as String,
                                    s['therapistId'] as String,
                                  );
                                  _shares[c['id'] as String] = await _api
                                      .shares(c['id'] as String);
                                  setState(() {});
                                }),
                                child: const Text('Revocă'),
                              ),
                            ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                key: ValueKey('share-${c['id']}'),
                                onPressed: () => _invite(c['id'] as String),
                                icon: const Icon(Icons.person_add_alt),
                                label: const Text('Invită un specialist'),
                              ),
                              TextButton.icon(
                                key: ValueKey('delete-${c['id']}'),
                                onPressed: () => _delete(c),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Șterge profilul'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 40),
                Text('Contul', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Ștergerea contului ia cu ea profilurile copiilor, sesiunile și partajările. '
                  'Datele de pe tabletă rămân pe tabletă.',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('delete-account'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.no_accounts_outlined),
                    label: const Text('Șterg contul'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Confirmarea ștergerii contului: ce se întâmplă, apoi parola (ca o sesiune lăsată deschisă
/// să nu poată șterge contul).
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ștergi contul?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accesul se oprește imediat, pentru tine și pentru specialiștii cu care ai partajat. '
          'Datele se șterg definitiv după 7 zile; până atunci poți scrie la suport ca să anulezi. '
          'Dacă vrei să le păstrezi, copiază-le întâi („Datele mele”).',
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('delete-account-password'),
          controller: _password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Parola contului'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Renunță'),
      ),
      FilledButton(
        key: const ValueKey('delete-account-confirm'),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.pop(context, _password.text),
        child: const Text('Șterg contul'),
      ),
    ],
  );
}

/// Dialogul de invitație își ține singur câmpul de text (eliberat abia după animația de închidere).
class _InviteDialog extends StatefulWidget {
  const _InviteDialog();

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invită un specialist'),
    content: TextField(
      key: const ValueKey('share-email'),
      controller: _email,
      decoration: const InputDecoration(
        labelText: 'E-mailul contului de specialist',
        helperText:
            'Acces doar pentru citire, 90 de zile. Îl poți revoca oricând.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Renunță'),
      ),
      FilledButton(
        key: const ValueKey('share-confirm'),
        onPressed: () => Navigator.pop(context, _email.text.trim()),
        child: const Text('Invită'),
      ),
    ],
  );
}
