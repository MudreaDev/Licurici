import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/auto_sync.dart';
import '../../data/sync.dart';
import '../../shared/mascot.dart';
import '../../shared/ui/candy.dart';
import '../settings/settings.dart';

/// Clientul pentru legare, după serverul din ce a scris părintele (în teste: unul simulat).
final linkClientProvider = Provider<SyncClient Function(String baseUrl)>((ref) => (baseUrl) => SyncClient(baseUrl: baseUrl));

/// „Bun venit” (prima pornire): adultul alege dacă leagă tableta de copilul creat de terapeut
/// (cu codul sau legătura primită) sau dacă începe direct jocul (fără server, totul rămâne
/// pe tabletă). Se poate lega oricând mai târziu din „Pentru părinți”.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Mascot(size: 180, mood: MascotMood.wave),
                const SizedBox(width: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedTitle('Bun venit la Licurici!', style: text.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Pentru adult: dacă terapeutul copilului v-a dat un cod, legați tableta acum — '
                        'jocurile alese de el apar singure, iar el vede cum progresează copilul.',
                        style: text.titleMedium!.copyWith(color: Tokens.inkSoft),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          CandyButton(
                            key: const ValueKey('welcome-code'),
                            label: 'Am un cod de la terapeut',
                            icon: Icons.key_rounded,
                            color: Tokens.primary,
                            minWidth: 260,
                            onTap: () => context.go('/legare'),
                          ),
                          CandyButton(
                            key: const ValueKey('welcome-play'),
                            label: 'Începem să ne jucăm',
                            icon: Icons.play_arrow_rounded,
                            color: Tokens.good,
                            minWidth: 220,
                            onTap: () {
                              ref.read(settingsProvider.notifier).markWelcomeSeen();
                              context.go('/');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legarea tabletei: codul (sau legătura) de la terapeut + acordul părintelui.
class LinkScreen extends ConsumerStatefulWidget {
  const LinkScreen({super.key});

  @override
  ConsumerState<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends ConsumerState<LinkScreen> {
  final _code = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final input = _code.text;
    final code = codeFromInput(input);
    if (code == null) {
      setState(() => _error = 'Codul are 8 caractere (de exemplu ABCD-2345). Verifică-l și încearcă din nou.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final server = serverForInput(input);
    try {
      final r = await ref.read(linkClientProvider)(server).linkDevice(code);
      await ref.read(autoSyncProvider.notifier).enable(r.refreshToken);
      ref.read(settingsProvider.notifier).setLinked(server, r.nickname);
      // Planul terapeutului (jocuri, niveluri, muzică) vine acum, nu abia după prima sesiune.
      unawaited(ref.read(autoSyncProvider.notifier).trigger());
      if (mounted) setState(() => _done = r.nickname);
    } on SyncException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = _done;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: CandyPanel(
                padding: const EdgeInsets.all(24),
                child: done != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Mascot(size: 140, mood: MascotMood.celebrate),
                          const SizedBox(height: 12),
                          Text('Gata! Tableta e legată de $done.', style: text.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(
                            'Sesiunile pleacă singure la terapeut după „Gata pe azi”. Jocurile alese de el apar pe ecranul principal.',
                            style: text.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          CandyButton(
                            key: const ValueKey('link-done'),
                            label: 'Începem să ne jucăm',
                            icon: Icons.play_arrow_rounded,
                            color: Tokens.good,
                            onTap: () => context.go('/'),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Codul de la terapeut', style: text.headlineSmall),
                          const SizedBox(height: 8),
                          Text('Scrie codul (de exemplu ABCD-2345) sau lipește legătura primită.', style: text.bodyLarge),
                          const SizedBox(height: 16),
                          TextField(
                            key: const ValueKey('link-input'),
                            controller: _code,
                            autofocus: true,
                            textCapitalization: TextCapitalization.characters,
                            style: text.headlineSmall,
                            decoration: const InputDecoration(labelText: 'Cod sau legătură', border: OutlineInputBorder()),
                            onSubmitted: (_) => _consent && !_busy ? _link() : null,
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            key: const ValueKey('link-consent'),
                            value: _consent,
                            onChanged: (v) => setState(() => _consent = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Sunt părintele (sau tutorele) copilului și sunt de acord ca rezultatele jocurilor '
                              '(fără nume real, fără poze) să fie trimise terapeutului care mi-a dat codul. '
                              'Pot opri oricând din „Pentru părinți”.',
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () {
                                        ref.read(settingsProvider.notifier).markWelcomeSeen();
                                        context.go('/');
                                      },
                                child: const Text('Mai târziu'),
                              ),
                              FilledButton.icon(
                                key: const ValueKey('link-submit'),
                                onPressed: _consent && !_busy ? _link : null,
                                icon: _busy
                                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.link_rounded),
                                label: const Text('Leagă tableta'),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
