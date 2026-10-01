import 'dart:math';

import 'package:flutter/material.dart';

/// Poarta pentru adulți (fără cont): o înmulțire cu numere scrise în cuvinte, cu 4 variante.
/// Un copil mic nu o poate rezolva din întâmplare; adultul trece în câteva secunde.
Future<bool> askParentGate(BuildContext context, {Random? random}) async {
  final r = random ?? Random();
  const words = ['șase', 'șapte', 'opt', 'nouă'];
  final a = 6 + r.nextInt(4), b = 6 + r.nextInt(4);
  final answer = a * b;
  final options = <int>{answer};
  while (options.length < 4) {
    options.add(answer + (r.nextBool() ? 1 : -1) * (1 + r.nextInt(9)));
  }
  final shuffled = options.toList()..shuffle(r);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pentru adulți'),
      content: Text('Cât fac ${words[a - 6]} ori ${words[b - 6]}?'),
      actions: [
        for (final o in shuffled)
          TextButton(
            key: ValueKey('gate-$o'),
            style: TextButton.styleFrom(minimumSize: const Size(72, 64)),
            onPressed: () => Navigator.of(context).pop(o == answer),
            child: Text('$o', style: const TextStyle(fontSize: 22)),
          ),
      ],
    ),
  );
  return ok ?? false;
}
