import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../shared/fx/scene_background.dart';
import '../../shared/motion.dart';
import '../../shared/top_bar.dart';
import '../../shared/ui/candy.dart';
import '../../data/session.dart';
import '../parent/parent_gate.dart';
import '../settings/settings.dart';
import '../session/mood_check.dart';
import 'catalog_cards.dart';
import 'today_path.dart';

/// Seed-ul zilei: aceeași scenă toată ziua (previzibil), alta mâine.
int daySeed([DateTime? now]) {
  final d = now ?? DateTime.now();
  return d.year * 10000 + d.month * 100 + d.day;
}

/// Ecranul principal: jocurile grupate pe arii de dezvoltare (ADR-026), nu pe clase.
/// Licurici în stânga, apoi „Drumul de azi” și câte un card ilustrat pe arie, pe un rând
/// care se derulează orizontal peste o pajiște generată (shader + paralaxă).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _parallax = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final max = _scroll.position.maxScrollExtent;
      _parallax.value = max <= 0 ? 0 : (_scroll.offset / max).clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _parallax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final domains = catalogByDomain();
    final scene = SceneSpec.generate(daySeed());
    final gap = layout.compact ? 16.0 : 24.0;

    final cards = [
      for (final (i, e) in domains.entries.indexed)
        enterCard(
          DomainCard(domain: e.key, games: e.value, index: i),
          motion,
          i + 1,
        ),
    ];

    Widget body;
    if (layout.twoPane) {
      body = Row(
        children: [
          SizedBox(
            width: layout.compact ? 150 : 230,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 0, layout.compact ? 8 : 20),
              child: const MascotCorner(message: 'Ce explorăm azi?'),
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
                Center(child: enterCard(const _TodayPanel(), motion, 0)),
                for (final card in cards) ...[
                  SizedBox(width: gap),
                  // Pe telefoanele mici cardul se micșorează proporțional ca să încapă pe înălțime.
                  FittedBox(fit: BoxFit.scaleDown, child: card),
                ],
              ],
            ),
          ),
        ],
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SizedBox(
            height: 220,
            child: MascotCorner(message: 'Bună! Ce explorăm azi?'),
          ),
          const SizedBox(height: 12),
          const _TodayPanel(),
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 16, children: cards),
        ],
      );
    }

    return Scaffold(
      body: SceneBackground(
        spec: scene,
        parallax: _parallax,
        child: SafeArea(
          child: Column(
            children: [
              const _HomeBar(),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// „Drumul de azi” pe un panou translucid, ca să se citească peste scenă.
class _TodayPanel extends StatelessWidget {
  const _TodayPanel();

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return CandyPanel(
      padding: EdgeInsets.all(compact ? 12 : 18),
      child: TodayPath(compact: compact),
    );
  }
}

/// Bara de sus a ecranului principal: după ce copilul a jucat, apare „Gata pe azi”
/// (dispoziția de final + salvarea sesiunii).
class _HomeBar extends ConsumerWidget {
  const _HomeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionProvider);
    final played = ref.read(sessionProvider.notifier).hasPlayed;
    return TopBar(
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (played) ...[
            BarButton(
              key: const ValueKey('finish-session'),
              icon: Icons.waving_hand_rounded,
              color: Tokens.peach,
              label: 'Gata pe azi',
              onTap: () => finishSession(context, ref),
            ),
            const SizedBox(width: 8),
          ],
          // Un abțibild nou așteaptă în album: steluță pe buton.
          Stack(
            clipBehavior: Clip.none,
            children: [
              BarButton(
                key: const ValueKey('album'),
                icon: Icons.collections_bookmark_rounded,
                color: const Color(0xFFE79B86),
                label: 'Albumul meu',
                onTap: () => context.go('/album'),
              ),
              if (ref.watch(settingsProvider.select((s) => s.hasNewStickers)))
                const Positioned(
                  right: -4,
                  top: -4,
                  child: IgnorePointer(
                    child: Icon(
                      Icons.star_rounded,
                      size: 26,
                      color: Color(0xFFF2C14E),
                      shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          BarButton(
            key: const ValueKey('parent-corner'),
            icon: Icons.lock_rounded,
            color: const Color(0xFF8A9BB0),
            label: 'Pentru părinți',
            onTap: () async {
              if (await askParentGate(context) && context.mounted) {
                context.go('/parinte');
              }
            },
          ),
        ],
      ),
    );
  }
}
