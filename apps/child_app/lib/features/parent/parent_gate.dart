import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../shared/ui/candy.dart';

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
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        constraints: const BoxConstraints(maxWidth: 520),
        child: CandyPanel(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Color(0xFF8A9BB0)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Pentru adulți', style: text.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Închide',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Cât fac ${words[a - 6]} ori ${words[b - 6]}?',
                style: text.bodyLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  for (final o in shuffled)
                    CandyPressable(
                      key: ValueKey('gate-$o'),
                      color: const Color(0xFFF3F6F8),
                      lipColor: const Color(0xFFD5DDE4),
                      radius: 18,
                      lip: 5,
                      width: 88,
                      height: 64,
                      semanticLabel: '$o',
                      onTap: () => Navigator.of(context).pop(o == answer),
                      child: Center(
                        child: Text(
                          '$o',
                          style: text.titleLarge!.copyWith(color: Tokens.ink),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return ok ?? false;
}
