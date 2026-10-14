import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/nav_memory.dart';
import '../../shared/fx/scene_background.dart';
import '../../shared/motion.dart';
import '../../shared/top_bar.dart';
import '../settings/settings.dart';
import '../home/catalog_cards.dart';
import '../home/home_screen.dart';

/// Jocurile unei arii de dezvoltare (`/arie/:code`). Lista își păstrează poziția: copilul
/// care iese dintr-un joc se întoarce aici, la jocul de unde a plecat.
class DomainScreen extends ConsumerStatefulWidget {
  const DomainScreen({super.key, required this.domain});

  final Domain domain;

  @override
  ConsumerState<DomainScreen> createState() => _DomainScreenState();
}

class _DomainScreenState extends ConsumerState<DomainScreen> {
  late final String _route = '/arie/${widget.domain.code.toLowerCase()}';
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final memory = ref.read(navMemoryProvider)..enterMenu(_route);
    _scroll = memory.controllerFor(_route);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final domain = widget.domain;
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final games = catalogByDomain(only: ref.watch(settingsProvider.select((s) => s.visibleGames)))[domain] ?? const <CatalogEntry>[];
    final gap = layout.compact ? 14.0 : 22.0;
    final cards = [
      for (final (i, g) in games.indexed)
        enterCard(GameCard(entry: g, index: i), motion, i),
    ];
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.generate(daySeed() ^ domain.index * 7919),
        child: SafeArea(
          child: Column(
            children: [
              TopBar(title: childLabel(domain)),
              Expanded(
                child: layout.twoPane
                    ? Row(
                        children: [
                          SizedBox(
                            width: layout.compact ? 140 : 210,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                12,
                                0,
                                0,
                                layout.compact ? 8 : 20,
                              ),
                              child: const MascotCorner(
                                message: 'Alege un joc!',
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              controller: _scroll,
                              scrollDirection: Axis.horizontal,
                              padding: EdgeInsets.fromLTRB(
                                gap,
                                8,
                                gap,
                                layout.compact ? 10 : 24,
                              ),
                              children: [
                                for (final (i, card) in cards.indexed) ...[
                                  if (i > 0) SizedBox(width: gap),
                                  FittedBox(fit: BoxFit.scaleDown, child: card),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(20),
                        children: [
                          Wrap(spacing: 16, runSpacing: 16, children: cards),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
