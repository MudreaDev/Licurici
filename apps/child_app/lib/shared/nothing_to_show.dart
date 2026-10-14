import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../app/theme.dart';
import '../features/settings/settings.dart';
import 'mascot.dart';
import 'ui/candy.dart';
import '../app/nav_memory.dart';

/// Imaginile pe care copilul nu trebuie să le vadă (alese de adult, `avoidItems`).
Set<String> avoidedOf(WidgetRef ref) => avoidedEmojis(ref.read(settingsProvider).avoid);

/// Jocul n-are runde fără imaginile pe care copilul nu trebuie să le vadă: un ecran liniștit,
/// cu drumul înapoi (adultul poate schimba alegerea din „Pentru părinți”).
class NothingToShow extends ConsumerWidget {
  const NothingToShow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(size: 140, mood: MascotMood.encourage),
            const SizedBox(height: 16),
            Text('Hai la alt joc!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            CandyIconButton(
              key: const ValueKey('nothing-back'),
              icon: Icons.grid_view_rounded,
              label: 'Alte jocuri',
              color: Tokens.primary,
              onTap: () => goBackToMenu(context, ref),
            ),
          ],
        ),
      ),
    ),
  );
}
