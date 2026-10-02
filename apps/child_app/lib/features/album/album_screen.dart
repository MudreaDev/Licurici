import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../shared/fx/scene_background.dart';
import '../../shared/illustration.dart';
import '../../shared/juice.dart';
import '../../shared/mascot.dart';
import '../../shared/motion.dart';
import '../../shared/top_bar.dart';
import '../../shared/ui/candy.dart';
import '../home/home_screen.dart';
import '../settings/settings.dart';

/// „Albumul meu” (`/album`): abțibildurile câștigate la finalul jocurilor. Locurile goale
/// arată umbra abțibildului, ca copilul să vadă ce mai poate aduna (fără cifre, fără
/// presiune: nu se pierde nimic, nu există „nivel ratat”).
class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  /// Abțibildurile noi de la ultima vizită (strălucesc o dată la deschidere).
  late final int _seenBefore = ref.read(settingsProvider).stickersSeen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(settingsProvider.notifier).markStickersSeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    final earned = ref.watch(settingsProvider.select((s) => s.stickers));
    final counts = <String, int>{};
    for (final id in earned) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final have = counts.length;
    final fresh = {
      for (var i = _seenBefore.clamp(0, earned.length); i < earned.length; i++)
        earned[i],
    };

    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.generate(daySeed() ^ 0x5eed),
        child: SafeArea(
          child: Column(
            children: [
              const TopBar(title: 'Albumul meu'),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    layout.compact ? 8 : 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (layout.twoPane)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Mascot(
                            size: layout.compact ? 90 : 170,
                            mood: have == 0
                                ? MascotMood.encourage
                                : MascotMood.happy,
                          ),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, box) {
                            const columns = 6;
                            const gap = 14.0;
                            final pad = layout.compact ? 12.0 : 24.0;
                            // Două rânduri de câte 6, cât de mari încap în pagină.
                            final side =
                                ((box.maxWidth - 2 * pad - gap * 5) / columns)
                                    .clamp(
                                      48.0,
                                      (box.maxHeight - 2 * pad - gap - 12) / 2,
                                    );
                            return Center(
                              child: CandyPanel(
                                padding: EdgeInsets.all(pad),
                                child: SizedBox(
                                  width: side * columns + gap * (columns - 1),
                                  child: Wrap(
                                    spacing: gap,
                                    runSpacing: gap,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      for (final (i, id) in stickerIds.indexed)
                                        if (motion.feedback)
                                          _Slot(
                                                id: id,
                                                count: counts[id] ?? 0,
                                                size: side,
                                                isNew: fresh.contains(id),
                                              )
                                              .animate(delay: motion.d(40 * i))
                                              .fadeIn(duration: motion.d(250))
                                              .scaleXY(
                                                begin: motion.movement
                                                    ? 0.8
                                                    : 1,
                                                end: 1,
                                                curve: Curves.easeOutBack,
                                              )
                                        else
                                          _Slot(
                                            id: id,
                                            count: counts[id] ?? 0,
                                            size: side,
                                            isNew: fresh.contains(id),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un loc din album: abțibildul (cu numărul de dubluri) sau umbra lui.
class _Slot extends ConsumerStatefulWidget {
  const _Slot({
    required this.id,
    required this.count,
    required this.size,
    this.isNew = false,
  });

  final String id;
  final int count;
  final double size;

  /// Primit de la ultima vizită: inel auriu și o mică săritură la deschidere.
  final bool isNew;

  @override
  ConsumerState<_Slot> createState() => _SlotState();
}

class _SlotState extends ConsumerState<_Slot> {
  int _hop = 0;

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final has = widget.count > 0;
    final image = Illustration(
      illustration('rewards/sticker_${widget.id}'),
      fallbackEmoji: '⭐',
    );
    return Semantics(
      label: has ? 'Abțibild' : 'Loc gol',
      button: has,
      child: GestureDetector(
        onTap: has ? () => setState(() => _hop++) : null,
        child: Container(
          width: widget.size,
          height: widget.size,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: has ? Colors.transparent : const Color(0xFFF3ECDF),
            border: has
                ? (widget.isNew
                      ? Border.all(color: const Color(0xFFF2C14E), width: 4)
                      : null)
                : Border.all(color: const Color(0xFFDCCDB3), width: 3),
            boxShadow: widget.isNew
                ? const [BoxShadow(color: Color(0x88F2C14E), blurRadius: 18)]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: has
                    ? Juice(
                        enabled: motion.movement,
                        hopTick: _hop,
                        popTick: widget.isNew ? 1 : 0,
                        child: image,
                      )
                    // Umbra: aceeași formă, ștearsă — „aici va fi un abțibild”.
                    : Opacity(
                        opacity: 0.3,
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF8C7E66),
                            BlendMode.srcIn,
                          ),
                          child: image,
                        ),
                      ),
              ),
              if (widget.count > 1)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Tokens.primary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '×${widget.count}',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium!.copyWith(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
