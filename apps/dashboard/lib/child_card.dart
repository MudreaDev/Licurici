import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import 'api.dart';
import 'data.dart';
import 'shared.dart';

/// „Adaugă copil” (versiunea de test pe Vercel): terapeutul completează fișa; serverul dă un cod
/// de unică folosință cu care părintele leagă tableta copilului.
class AddChildButton extends ConsumerWidget {
  const AddChildButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton.icon(
    key: const ValueKey('add-child'),
    onPressed: () => _add(context, ref),
    icon: const Icon(Icons.person_add_alt_1),
    label: const Text('Adaugă copil'),
  );

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<({ChildCard card, ChildLink link})>(
      context: context,
      builder: (_) => const _ChildForm(),
    );
    if (created == null || !context.mounted) return;
    await ref.read(serverChildrenProvider.notifier).refresh();
    // Fișa copilului (primul tab) arată codul de legare.
    if (context.mounted) context.go('/specialist/copil/${created.card.id}');
  }
}

/// Formularul fișei: porecla (nu numele real), anul nașterii, observații, obiective.
class _ChildForm extends ConsumerStatefulWidget {
  const _ChildForm();

  @override
  ConsumerState<_ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends ConsumerState<_ChildForm> {
  final _nickname = TextEditingController();
  final _year = TextEditingController();
  final _notes = TextEditingController();
  final _goals = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_nickname, _year, _notes, _goals]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref
          .read(apiClientProvider)
          .createChild(
            nickname: _nickname.text.trim(),
            birthYear: int.tryParse(_year.text.trim()),
            notes: _notes.text.trim(),
            goals: _goals.text.trim(),
          );
      if (mounted) Navigator.pop(context, r);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Copil nou'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Folosește o poreclă, nu numele real al copilului (protecția datelor). '
              'Fără diagnostic sau alte date medicale.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('child-nickname'),
              controller: _nickname,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Porecla copilului'),
            ),
            TextField(
              key: const ValueKey('child-year'),
              controller: _year,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              decoration: const InputDecoration(labelText: 'Anul nașterii (opțional)'),
            ),
            TextField(
              key: const ValueKey('child-goals'),
              controller: _goals,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Ce lucrăm acum (obiective)'),
            ),
            TextField(
              key: const ValueKey('child-notes'),
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observații (doar pentru tine)'),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Renunță')),
      FilledButton(
        key: const ValueKey('child-save'),
        onPressed: _busy ? null : _save,
        child: const Text('Salvează și dă-mi codul'),
      ),
    ],
  );
}

/// Codul de legare, mare, cu legătura de trimis părintelui și butoane de copiere.
class LinkCodeBox extends StatelessWidget {
  const LinkCodeBox({super.key, required this.link});

  final ChildLink link;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final code = link.code;
    if (code == null) {
      return Text(
        link.linked
            ? 'Tableta e legată${link.linkedAt == null ? '' : ' din ${dateLabel(link.linkedAt!)}'}. Codul a fost folosit; poți genera unul nou pentru altă tabletă.'
            : 'Nu există un cod activ. Generează unul nou.',
      );
    }
    final message =
        'Bună! Pentru aplicația Licurici: la prima pornire alege „Am un cod de la terapeut” și scrie codul $code'
        '${link.url == null ? '' : ' (sau deschide ${link.url})'}. Codul merge o singură dată.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Dă-i părintelui acest cod (merge o singură dată). Pe tabletă: „Am un cod de la terapeut”.'),
        const SizedBox(height: 12),
        SelectableText(
          code,
          key: const ValueKey('link-code'),
          style: text.displaySmall!.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4),
        ),
        if (link.url != null) SelectableText(link.url!, style: text.bodyMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _copy(context, code, 'Codul a fost copiat.'),
              icon: const Icon(Icons.copy),
              label: const Text('Copiază codul'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('copy-message'),
              onPressed: () => _copy(context, message, 'Mesajul pentru părinte a fost copiat.'),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Copiază mesajul pentru părinte'),
            ),
          ],
        ),
      ],
    );
  }

  static Future<void> _copy(BuildContext context, String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
  }
}

/// Tabul „Fișa copilului”: datele completate de terapeut (editabile) și legarea tabletei.
class ChildCardPanel extends ConsumerStatefulWidget {
  const ChildCardPanel({super.key, required this.history});

  final ChildHistory history;

  @override
  ConsumerState<ChildCardPanel> createState() => _ChildCardPanelState();
}

class _ChildCardPanelState extends ConsumerState<ChildCardPanel> {
  ChildCard? _card;
  ChildLink? _link;
  String? _error;
  bool _busy = false;
  final _nickname = TextEditingController();
  final _year = TextEditingController();
  final _notes = TextEditingController();
  final _goals = TextEditingController();

  String get _id => widget.history.child.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_nickname, _year, _notes, _goals]) {
      c.dispose();
    }
    super.dispose();
  }

  /// O sesiune nouă (sincronizarea) poate însemna și o tabletă abia legată: reîncărcăm starea.
  @override
  void didUpdateWidget(ChildCardPanel old) {
    super.didUpdateWidget(old);
    if (old.history.sessions.length != widget.history.sessions.length) _reloadStatus();
  }

  Future<void> _reloadStatus() async {
    try {
      final api = ref.read(apiClientProvider);
      final card = await api.childCard(_id);
      final link = await api.childLink(_id);
      if (mounted) {
        setState(() {
          _card = card ?? _card;
          _link = link;
        });
      }
    } on ApiException {
      // Rămâne ce era; la următoarea schimbare încercăm iar.
    }
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final card = await api.childCard(_id);
      final link = await api.childLink(_id);
      if (!mounted) return;
      setState(() {
        _card = card;
        _link = link;
        _nickname.text = card?.nickname ?? '';
        _year.text = card?.birthYear?.toString() ?? '';
        _notes.text = card?.notes ?? '';
        _goals.text = card?.goals ?? '';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _run(Future<void> Function() f, String done) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    final card = await ref
        .read(apiClientProvider)
        .updateChild(
          _id,
          nickname: _nickname.text.trim(),
          birthYear: int.tryParse(_year.text.trim()),
          notes: _notes.text,
          goals: _goals.text,
        );
    setState(() => _card = card);
    await ref.read(serverChildrenProvider.notifier).refresh();
  }, 'Fișa a fost salvată.');

  Future<void> _newCode({required bool unlink}) async {
    if (unlink) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Deconectezi tableta?'),
          content: const Text(
            'Tableta legată acum nu va mai trimite sesiuni și nu va mai primi planul. '
            'Sesiunile deja trimise rămân. Primești un cod nou pentru o altă tabletă.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Renunță')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Deconectează')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(() async {
      final link = await ref.read(apiClientProvider).newChildLink(_id, unlink: unlink);
      setState(() => _link = link);
    }, unlink ? 'Tableta a fost deconectată; codul nou e mai jos.' : 'Cod nou generat.');
  }

  @override
  Widget build(BuildContext context) {
    final card = _card, link = _link;
    if (card == null) {
      return Section(
        'Fișa copilului',
        child: _error == null ? const LinearProgressIndicator() : Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Section(
          'Tableta copilului',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(card.linked ? Icons.tablet_android : Icons.link_off, color: card.linked ? Colors.green.shade700 : null),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      card.linked
                          ? 'Legată${card.linkedAt == null ? '' : ' din ${dateLabel(card.linkedAt!)}'}'
                                '${card.lastSyncAt == null ? ' · încă nicio sesiune trimisă' : ' · ultima sincronizare ${dateLabel(card.lastSyncAt!)}'}'
                          : 'Nicio tabletă legată încă.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (link != null) LinkCodeBox(link: link),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('new-code'),
                    onPressed: _busy ? null : () => _newCode(unlink: false),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Cod nou'),
                  ),
                  if (card.linked)
                    OutlinedButton.icon(
                      key: const ValueKey('unlink'),
                      onPressed: _busy ? null : () => _newCode(unlink: true),
                      icon: const Icon(Icons.link_off),
                      label: const Text('Deconectează tableta'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Section(
          'Fișa copilului',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(controller: _nickname, maxLength: 40, decoration: const InputDecoration(labelText: 'Porecla')),
              TextField(
                controller: _year,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: const InputDecoration(labelText: 'Anul nașterii'),
              ),
              TextField(controller: _goals, maxLines: 4, decoration: const InputDecoration(labelText: 'Ce lucrăm acum (obiective)')),
              TextField(controller: _notes, maxLines: 4, decoration: const InputDecoration(labelText: 'Observații (doar pentru tine)')),
              if (_error != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('card-save'),
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvează fișa'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
