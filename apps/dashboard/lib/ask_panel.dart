import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import 'api.dart';
import 'shared.dart';

/// „Întreabă despre progres” (README §21): adultul întreabă în cuvintele lui, Claude răspunde
/// doar din datele agregate ale ultimelor sesiuni. Conversația stă doar în pagină (nu se
/// salvează nicăieri); cere acordul părintelui pentru AI. Doar pentru copiii de pe server.
class AskPanel extends ConsumerStatefulWidget {
  const AskPanel({super.key, required this.history});

  final ChildHistory history;

  @override
  ConsumerState<AskPanel> createState() => _AskPanelState();
}

class _AskPanelState extends ConsumerState<AskPanel> {
  final _question = TextEditingController();
  final _turns = <({String role, String text})>[];
  bool _busy = false;
  String? _error;

  static const _examples = [
    'Cum a mers în ultimele două săptămâni?',
    'La ce are nevoie de cel mai mult ajutor?',
    'Ce aș putea exersa acasă?',
  ];

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask([String? preset]) async {
    final q = (preset ?? _question.text).trim();
    if (q.length < 3 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final answer = await ref
          .read(apiClientProvider)
          .ask(widget.history.child.id, q, history: _turns.length > 6 ? _turns.sublist(_turns.length - 6) : _turns);
      if (!mounted) return;
      setState(() {
        _turns
          ..add((role: 'user', text: q))
          ..add((role: 'assistant', text: answer));
        _question.clear();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) setState(() => _error = 'Serverul nu răspunde. Încearcă mai târziu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromServer = ref.watch(serverChildrenProvider).any((h) => h.child.id == widget.history.child.id);
    if (!fromServer) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Section(
      'Întreabă despre progres',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Răspunsurile sunt scrise de AI doar din datele ultimelor sesiuni (fără nume) și nu se păstrează. '
            'Nu sunt diagnostice; pentru decizii, vorbește cu specialistul.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final t in _turns)
            Align(
              alignment: t.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: t.role == 'user' ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(t.text),
              ),
            ),
          if (_turns.isEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, e) in _examples.indexed)
                  ActionChip(key: ValueKey('ask-example-$i'), label: Text(e), onPressed: _busy ? null : () => _ask(e)),
              ],
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, key: const ValueKey('ask-error'), style: TextStyle(color: scheme.error)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('ask-question'),
                  controller: _question,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Întrebarea ta…', counterText: ''),
                  onSubmitted: (_) => _ask(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const ValueKey('ask-send'),
                onPressed: _busy ? null : _ask,
                icon: _busy
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: const Text('Întreabă'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
