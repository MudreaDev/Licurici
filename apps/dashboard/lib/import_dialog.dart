import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import 'data.dart';

/// „Importă sesiuni”: lipește textul copiat din aplicația copilului („Pentru părinți” → 📋).
class ImportButton extends ConsumerWidget {
  const ImportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
    key: const ValueKey('import-sessions'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => const _ImportDialog(),
    ),
    icon: const Icon(Icons.upload_file_outlined),
    label: const Text('Importă sesiuni'),
  );
}

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _import() {
    try {
      final n = ref
          .read(importedSessionsProvider.notifier)
          .importText(_text.text);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n sesiuni importate: apar ca „Copilul meu”.')),
      );
    } on TransferFormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Importă sesiuni'),
    content: SizedBox(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'În aplicația copilului: „Pentru părinți” → butonul de copiere. Apoi lipește aici. '
            'Datele rămân doar în această pagină.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('import-text'),
            controller: _text,
            maxLines: 6,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: '{"format":"licurici-sesiuni", …}',
              errorText: _error,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Renunță'),
      ),
      FilledButton(
        key: const ValueKey('import-confirm'),
        onPressed: _import,
        child: const Text('Importă'),
      ),
    ],
  );
}
