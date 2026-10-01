import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/theme.dart';
import '../../data/session.dart';
import '../../shared/emoji_art.dart';
import '../../shared/pressable.dart';
import '../session/mood_check.dart';

/// Jocurile care există în aplicație, cu ruta și ilustrația lor.
({String route, String emoji, String name})? gameEntry(String id) {
  final e = catalogEntry(id);
  return e == null ? null : (route: e.route, emoji: e.emoji, name: e.name);
}

/// „Drumul de azi” (plan §3.4): încălzire → obiective → menținere → final pe succes, din
/// progresul salvat. Aceeași zi → același drum (seed pe dată), ca orarul să fie previzibil.
final todayPlanProvider = FutureProvider.autoDispose<SessionPlan>((ref) async {
  final records = await ref.watch(sessionStoreProvider).all();
  // Toate jocurile (pe arii, nu pe clase — ADR-026); alocarea pe copil vine din plan §5.1.
  final games = {for (final e in catalog) e.id};
  final now = DateTime.now();
  return const SessionPlanner(config: SessionConfig(targetBlocks: 2)).plan(
    progress: defaultObjectives(progressFromSessions(records), games),
    allowedGames: games,
    now: now,
    random: Random(now.year * 10000 + now.month * 100 + now.day),
  );
});

/// Orarul vizual: iconițele activităților pe o cărare; cele jucate azi primesc o bifă.
class TodayPath extends ConsumerWidget {
  const TodayPath({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(todayPlanProvider).value;
    final session = ref.watch(sessionProvider);
    if (plan == null || plan.isEmpty) return const SizedBox.shrink();
    final played = {
      for (final t in session?.trials ?? const <Trial>[]) t.gameId,
    };
    final size = compact ? 48.0 : 64.0;
    final stops = <Widget>[];
    for (final (i, a) in plan.activities.indexed) {
      final entry = gameEntry(a.gameId);
      if (entry == null) continue;
      if (stops.isNotEmpty) stops.add(_Dots(done: played.contains(a.gameId)));
      final done = played.contains(a.gameId);
      stops.add(
        Pressable(
          key: ValueKey('today-$i'),
          semanticLabel: entry.name,
          onTap: () => openGame(context, ref, entry.route),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size + 16,
                height: size + 16,
                decoration: BoxDecoration(
                  color: done ? Tokens.goodSoft : Tokens.surface,
                  shape: BoxShape.circle,
                  boxShadow: Tokens.shadow,
                ),
                alignment: Alignment.center,
                child: EmojiArt(
                  entry.emoji,
                  size: size,
                  semanticLabel: entry.name,
                ),
              ),
              if (done)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: EmojiArt('✅', size: 26),
                ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Drumul de azi', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(mainAxisSize: MainAxisSize.min, children: stops),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: done ? Tokens.good : Tokens.surface,
              shape: BoxShape.circle,
            ),
          ),
      ],
    ),
  );
}
