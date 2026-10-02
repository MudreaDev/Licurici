import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/theme.dart';
import '../../data/session.dart';
import '../../shared/illustration.dart';
import '../../shared/ui/candy.dart';
import '../session/mood_check.dart';

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
    final size = compact ? 52.0 : 72.0;
    final stops = <Widget>[];
    for (final (i, a) in plan.activities.indexed) {
      final entry = catalogEntry(a.gameId);
      if (entry == null) continue;
      final done = played.contains(a.gameId);
      if (stops.isNotEmpty) stops.add(_Dots(done: done));
      final color = domainColor(entry.domain);
      stops.add(
        Stack(
          clipBehavior: Clip.none,
          children: [
            CandyPressable(
              key: ValueKey('today-$i'),
              color: done ? Tokens.goodSoft : tint(color, 0.2),
              lipColor: shade(done ? Tokens.good : color, 0.04),
              radius: 999,
              lip: 5,
              width: size + 12,
              height: size + 12,
              padding: const EdgeInsets.all(6),
              semanticLabel: entry.name,
              onTap: () => openGame(context, ref, entry.route),
              child: Illustration(
                gameIllustration(entry.id),
                fallbackEmoji: entry.emoji,
                semanticLabel: entry.name,
              ),
            ),
            if (done)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Tokens.good,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wb_sunny_rounded, color: Color(0xFFF2C14E)),
            const SizedBox(width: 6),
            Text(
              'Drumul de azi',
              style: Theme.of(
                context,
              ).textTheme.titleLarge!.copyWith(color: const Color(0xFF3D5A80)),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
              color: done ? Tokens.good : const Color(0xFFE3D9C6),
              shape: BoxShape.circle,
            ),
          ),
      ],
    ),
  );
}
