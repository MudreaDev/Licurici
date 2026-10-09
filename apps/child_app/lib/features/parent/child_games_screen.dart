import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/theme.dart';
import '../../shared/illustration.dart';
import '../../shared/top_bar.dart';
import '../settings/settings.dart';
import 'first_steps_screen.dart';

/// „Jocurile copilului” (plan §5.1, varianta fără specialist): adultul alege, pe arii, ce
/// jocuri vede copilul. Ce e scos nu apare pe ecranul principal și nici în „Drumul de azi”;
/// datele jocurilor jucate rămân. Alegerea stă doar pe tabletă.
class ChildGamesScreen extends ConsumerWidget {
  const ChildGamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(settingsProvider.select((s) => s.hiddenGames));
    final notifier = ref.read(settingsProvider.notifier);
    final domains = catalogByDomain();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  BarButton(
                    key: const ValueKey('child-games-back'),
                    icon: Icons.arrow_back_rounded,
                    color: Tokens.primary,
                    label: 'Înapoi',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Jocurile copilului', style: text.titleLarge!.copyWith(color: Tokens.ink))),
                  OutlinedButton.icon(
                    key: const ValueKey('first-steps'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FirstStepsScreen())),
                    icon: const Icon(Icons.flag_rounded),
                    label: const Text('Primii pași'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Copilul vede doar jocurile bifate. Scoate jocurile care nu îi folosesc acum sau care îl agită; '
                'ce a jucat deja rămâne în rapoarte. Jocurile noi apar bifate.',
                style: text.bodyMedium!.copyWith(color: Tokens.inkSoft),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  const _AvoidCard(),
                  for (final MapEntry(key: domain, value: games) in domains.entries)
                    Card(
                      key: ValueKey('domain-${domain.code}'),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            SwitchListTile(
                              key: ValueKey('domain-switch-${domain.code}'),
                              title: Text(childLabel(domain), style: text.titleMedium),
                              subtitle: Text('${domain.label} · ${games.where((g) => !hidden.contains(g.id)).length} din ${games.length} jocuri'),
                              value: games.any((g) => !hidden.contains(g.id)),
                              onChanged: (v) => notifier.setGamesVisible(games.map((g) => g.id), v),
                            ),
                            const Divider(height: 1),
                            for (final g in games)
                              CheckboxListTile(
                                key: ValueKey('game-${g.id}'),
                                dense: true,
                                secondary: SizedBox.square(dimension: 40, child: Illustration(gameIllustration(g.id), fallbackEmoji: g.emoji)),
                                title: Text(g.name),
                                subtitle: Text(g.description),
                                value: !hidden.contains(g.id),
                                onChanged: (v) => notifier.setGamesVisible([g.id], v ?? true),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Imaginile pe care copilul nu trebuie să le vadă (frici, lucruri care îl tulbură): jocurile sar
/// peste rundele care le-ar arăta. Se sincronizează cu panoul (planul de jocuri).
class _AvoidCard extends ConsumerWidget {
  const _AvoidCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avoid = ref.watch(settingsProvider.select((s) => s.avoid));
    final text = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('avoid-card'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Imagini de evitat', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Bifează ce îl sperie sau îl tulbură pe copil: jocurile nu le mai arată.',
              style: text.bodyMedium!.copyWith(color: Tokens.inkSoft),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in avoidItems)
                  FilterChip(
                    key: ValueKey('avoid-${item.id}'),
                    avatar: Text(item.emojis.first),
                    label: Text(item.label),
                    selected: avoid.contains(item.id),
                    onSelected: (on) => ref.read(settingsProvider.notifier).setAvoid(item.id, on),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

