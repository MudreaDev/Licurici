import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../data/session.dart';
import '../settings/settings.dart';
import '../../shared/illustration.dart';
import '../../shared/mascot.dart';
import '../../shared/ui/candy.dart';
import '../../shared/voice.dart';

/// „Cum te simți?” — copilul își alege singur dispoziția (plan §4: autoevaluare; e și un
/// exercițiu de comunicare a emoțiilor). Fără răspuns corect, fără presiune: „Sari peste”
/// e mereu disponibil, iar alegerea doar se notează pentru adult.
Future<Mood?> askMood(BuildContext context, WidgetRef ref) {
  ref.read(voiceProvider).say(['Cum te simți?']);
  return showDialog<Mood>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _MoodDialog(),
  );
}

/// Deschide un joc; la primul joc din sesiune întreabă întâi „Cum te simți?”.
Future<void> openGame(BuildContext context, WidgetRef ref, String route) async {
  final session = ref.read(sessionProvider.notifier);
  if (session.needsMoodBefore) {
    final mood = await askMood(context, ref);
    session.start(moodBefore: mood);
    // De aici se numără abțibildurile „de azi” (pentru „La revedere”).
    ref
        .read(_stickersAtStart.notifier)
        .mark(ref.read(settingsProvider).stickers.length);
  }
  if (context.mounted) context.go(route);
}

/// „Gata pe azi”: dispoziția de final, apoi sesiunea se salvează.
Future<void> finishSession(BuildContext context, WidgetRef ref) async {
  final mood = await askMood(context, ref);
  await ref.read(sessionProvider.notifier).finish(moodAfter: mood);
  ref.read(voiceProvider).say(['Ne vedem data viitoare!']);
  final all = ref.read(settingsProvider).stickers;
  final from = ref.read(_stickersAtStart).clamp(0, all.length);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _Goodbye(stickers: all.sublist(from)),
  );
}

/// Câte abțibilduri avea copilul când a început sesiunea.
class _StickersAtStart extends Notifier<int> {
  @override
  int build() => 0;

  void mark(int count) => state = count;
}

final _stickersAtStart = NotifierProvider<_StickersAtStart, int>(
  _StickersAtStart.new,
);

/// „La revedere”: Licurici adoarme, iar copilul vede ce a adunat azi. Un singur buton.
class _Goodbye extends ConsumerWidget {
  const _Goodbye({required this.stickers});

  final List<String> stickers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = AppLayout.of(context).compact;
    final text = Theme.of(context).textTheme;
    final size = compact ? 56.0 : 84.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 640),
      child: CandyPanel(
        padding: EdgeInsets.fromLTRB(
          24,
          compact ? 12 : 22,
          24,
          compact ? 12 : 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Mascot(size: compact ? 90 : 150, mood: MascotMood.sleep),
              Text(
                'Bravo pentru azi!',
                style: (compact ? text.headlineMedium : text.displaySmall)!
                    .copyWith(color: const Color(0xFF3D5A80)),
                textAlign: TextAlign.center,
              ),
              if (stickers.isNotEmpty) ...[
                SizedBox(height: compact ? 8 : 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final id in stickers.take(8))
                      SizedBox.square(
                        dimension: size,
                        child: Illustration(
                          illustration('rewards/sticker_$id'),
                          fallbackEmoji: '⭐',
                        ),
                      ),
                  ],
                ),
              ],
              SizedBox(height: compact ? 10 : 18),
              CandyButton(
                key: const ValueKey('goodbye'),
                label: 'Pe mâine!',
                icon: Icons.nightlight_round,
                color: Tokens.lavender,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Culoarea fiecărei dispoziții (calde pentru plăcut, reci pentru greu, niciodată roșu).
Color _moodColor(Mood m) => switch (m) {
  Mood.bucuros => const Color(0xFFF2CF6B),
  Mood.linistit => Tokens.mint,
  Mood.obosit => Tokens.lavender,
  Mood.trist => Tokens.primary,
  Mood.suparat => Tokens.peach,
};

/// Fața copilului pictat pentru fiecare dispoziție (aceeași ca în jocurile cu emoții).
String _moodFace(Mood m) => switch (m) {
  Mood.bucuros => 'fericit',
  Mood.linistit => 'calm',
  Mood.obosit => 'obosit',
  Mood.trist => 'trist',
  Mood.suparat => 'suparat',
};

class _MoodDialog extends ConsumerWidget {
  const _MoodDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.read(voiceProvider);
    final compact = AppLayout.of(context).compact;
    final text = Theme.of(context).textTheme;
    final face = compact ? 72.0 : 112.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(maxWidth: 760),
      child: CandyPanel(
        padding: EdgeInsets.fromLTRB(
          20,
          compact ? 10 : 18,
          20,
          compact ? 12 : 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Mascot(size: compact ? 56 : 84, mood: MascotMood.think),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cum te simți?',
                      style:
                          (compact ? text.headlineMedium : text.displaySmall)!
                              .copyWith(color: const Color(0xFF3D5A80)),
                    ),
                  ),
                  // Mereu vizibil, și pe telefonul mic: întrebarea nu e obligatorie.
                  TextButton(
                    key: const ValueKey('mood-skip'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 64),
                      foregroundColor: Tokens.inkSoft,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Sari peste'),
                  ),
                ],
              ),
              SizedBox(height: compact ? 6 : 14),
              Wrap(
                spacing: compact ? 8 : 14,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final (i, m) in Mood.values.indexed)
                    CandyPressable(
                          key: ValueKey('mood-${m.name}'),
                          color: tint(_moodColor(m), 0.18),
                          lipColor: shade(_moodColor(m), 0.04),
                          radius: 26,
                          semanticLabel: m.label,
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                          onTap: () {
                            voice.say([m.label]);
                            Navigator.of(context).pop(m);
                          },
                          child: SizedBox(
                            width: face,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  dimension: face,
                                  child: Illustration(
                                    illustration('faces/${_moodFace(m)}'),
                                    fallbackEmoji: m.emoji,
                                    semanticLabel: m.label,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Un singur rând, oricât de îngust e cardul.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    m.label,
                                    maxLines: 1,
                                    style: text.titleMedium!.copyWith(
                                      color: shade(_moodColor(m), 0.35),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate(delay: (60 * i).ms)
                        .fadeIn(duration: 220.ms)
                        .scaleXY(
                          begin: 0.85,
                          end: 1,
                          curve: Curves.easeOutBack,
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
