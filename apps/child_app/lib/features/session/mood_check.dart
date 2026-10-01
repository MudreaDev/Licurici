import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../data/session.dart';
import '../../shared/emoji_art.dart';
import '../../shared/pressable.dart';
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
  }
  if (context.mounted) context.go(route);
}

/// „Gata pe azi”: dispoziția de final, apoi sesiunea se salvează.
Future<void> finishSession(BuildContext context, WidgetRef ref) async {
  final mood = await askMood(context, ref);
  await ref.read(sessionProvider.notifier).finish(moodAfter: mood);
  ref.read(voiceProvider).say(['Ne vedem data viitoare!']);
}

class _MoodDialog extends ConsumerWidget {
  const _MoodDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.read(voiceProvider);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cum te simți?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  // Mereu vizibil, și pe telefonul mic: întrebarea nu e obligatorie.
                  TextButton(
                    key: const ValueKey('mood-skip'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 64),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Sari peste'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final m in Mood.values)
                    Pressable(
                      key: ValueKey('mood-${m.name}'),
                      semanticLabel: m.label,
                      onTap: () {
                        voice.say([m.label]);
                        Navigator.of(context).pop(m);
                      },
                      child: SizedBox(
                        width: 80,
                        child: Column(
                          children: [
                            EmojiArt(m.emoji, size: 64, semanticLabel: m.label),
                            const SizedBox(height: 4),
                            Text(m.label, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
