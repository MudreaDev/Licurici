import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici_core/licurici_core.dart';

class Section extends StatelessWidget {
  const Section(this.title, {super.key, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  );
}

class EmojiArt extends StatelessWidget {
  const EmojiArt(this.mood, {super.key, this.size = 40});
  final Mood? mood;
  final double size;
  @override
  Widget build(BuildContext context) => mood == null
      ? const Text('Nespecificat')
      : Tooltip(
          message: mood!.label,
          child: SvgPicture.asset(
            openMojiAsset(mood!.emoji),
            package: contentPackage,
            width: size,
            height: size,
            semanticsLabel: mood!.label,
          ),
        );
}

class MoodPair extends StatelessWidget {
  const MoodPair(this.report, {super.key, this.size = 40, this.labels = false});
  final SessionReport report;
  final double size;
  final bool labels;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmojiArt(report.record.moodBefore, size: size),
          if (labels)
            Text(
              'La început: ${report.record.moodBefore?.label ?? 'nespecificat'}',
            ),
        ],
      ),
      const Icon(Icons.arrow_forward, size: 18),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmojiArt(report.record.moodAfter, size: size),
          if (labels)
            Text(
              'La final: ${report.record.moodAfter?.label ?? 'nespecificat'}',
            ),
        ],
      ),
    ],
  );
}

/// Core summaries contain emoji; render them using packaged OpenMoji artwork.
class SummaryText extends StatelessWidget {
  const SummaryText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final pattern = RegExp(
      '(${Mood.values.map((m) => RegExp.escape(m.emoji)).join('|')})',
    );
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in pattern.allMatches(text)) {
      spans.add(TextSpan(text: text.substring(start, match.start)));
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: EmojiArt(
            Mood.values.firstWhere((m) => m.emoji == match[0]),
            size: 24,
          ),
        ),
      );
      start = match.end;
    }
    spans.add(TextSpan(text: text.substring(start)));
    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 20, height: 1.6),
    );
  }
}

class NotesList extends StatelessWidget {
  const NotesList(this.notes, {super.key});
  final List<String> notes;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final note in notes)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            '•  $note',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
    ],
  );
}

void showReportDialog(BuildContext context, String title, Widget content) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(child: content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Închide'),
          ),
        ],
      ),
    );
