import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../data/session.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/juice.dart';
import '../../../shared/motion.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';

/// Vorbește (COM3): tabla de comunicare. Stânga — filele („Vreau”, „Mă simt”…); sus —
/// propoziția alcătuită, cu butonul care o rostește din nou; jos — pictogramele. Atingerea unei
/// pictograme rostește imediat propoziția întreagă („Vreau apă”). Nu există greșeli; fiecare
/// propoziție e o cerere notată în sesiune (`SessionEventKind.request`).
class AacScreen extends ConsumerStatefulWidget {
  const AacScreen({super.key, this.game = const AacGame()});

  final AacGame game;

  @override
  ConsumerState<AacScreen> createState() => _AacScreenState();
}

class _AacScreenState extends ConsumerState<AacScreen> {
  AacCategory _category = aacBoard.first;
  AacWord? _word;
  int _pop = 0;

  @override
  void initState() {
    super.initState();
    Future(() {
      if (!mounted) return;
      precacheStimuli(context, {
        for (final c in aacBoard) ...[c.emoji, ...c.words.map((w) => w.emoji)],
      });
    });
  }

  String? get _sentence =>
      _word == null ? null : aacSentence(_category, _word!);

  void _pickCategory(AacCategory c) {
    if (c == _category) return;
    setState(() {
      _category = c;
      _word = null;
    });
    ref.read(voiceProvider).say([c.starter]);
  }

  void _pickWord(AacWord w) {
    setState(() {
      _word = w;
      _pop++;
    });
    ref.read(voiceProvider).say([aacSentence(_category, w)]);
    // Fiecare cerere se salvează imediat (copilul poate ieși oricând).
    ref.read(sessionProvider.notifier)
      ..record((r) => r.event(SessionEventKind.request, gameId: widget.game.id))
      ..checkpoint();
  }

  void _repeat() {
    if (_sentence case final s?) ref.read(voiceProvider).say([s]);
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.forLevel(widget.game.id, 1),
        child: SafeArea(
          child: Column(
            children: [
              TopBar(title: widget.game.name),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Tabs(
                        current: _category,
                        compact: layout.compact,
                        onPick: _pickCategory,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            _Strip(
                              category: _category,
                              word: _word,
                              compact: layout.compact,
                              pop: _pop,
                              motion: motion,
                              onSpeak: _repeat,
                            ),
                            SizedBox(height: layout.compact ? 8 : 14),
                            Expanded(
                              child: _Grid(
                                words: _category.words,
                                selected: _word,
                                compact: layout.compact,
                                onPick: _pickWord,
                              ),
                            ),
                          ],
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

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.current,
    required this.compact,
    required this.onPick,
  });

  final AacCategory current;
  final bool compact;
  final ValueChanged<AacCategory> onPick;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final h = math.min(
        // − buza 3D a fiecărui buton (~7 dp).
        (box.maxHeight - 8 * (aacBoard.length - 1)) / aacBoard.length - 8,
        compact ? 56.0 : 96.0,
      );
      return SizedBox(
        width: compact ? 120 : 190,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, c) in aacBoard.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              CandyPressable(
                key: ValueKey('aac-tab-${c.id}'),
                color: c == current ? Tokens.sun : const Color(0xFFFFFBF4),
                lipColor: c == current
                    ? shade(Tokens.sun, 0.15)
                    : const Color(0xFFE3D9C6),
                height: h,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                semanticLabel: c.starter,
                onTap: () => onPick(c),
                child: Row(
                  children: [
                    StimulusArt(c.emoji, size: h * 0.62),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.starter,
                        maxLines: 2,
                        style:
                            (compact
                                    ? Theme.of(context).textTheme.labelMedium
                                    : Theme.of(context).textTheme.titleLarge)!
                                .copyWith(color: Tokens.ink, height: 1.05),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// Banda propoziției: începutul (cuvânt) + poza aleasă + cuvântul; butonul o rostește din nou.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.category,
    required this.word,
    required this.compact,
    required this.pop,
    required this.motion,
    required this.onSpeak,
  });

  final AacCategory category;
  final AacWord? word;
  final bool compact;
  final int pop;
  final MotionPolicy motion;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final text =
        (compact
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.headlineMedium)!
            .copyWith(color: Tokens.ink);
    final art = compact ? 40.0 : 64.0;
    return Container(
      key: const ValueKey('aac-strip'),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 6 : 10),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFBF4),
        borderRadius: BorderRadius.circular(Tokens.radius),
        border: Border.all(color: const Color(0xFFE3D9C6), width: 3),
        boxShadow: Tokens.shadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: word == null
                ? Text(
                    category.id == 'spun'
                        ? 'Atinge o poză.'
                        : '${category.starter} …',
                    style: text.copyWith(color: const Color(0xFF9AA0AE)),
                  )
                : Juice(
                    enabled: motion.movement,
                    popTick: pop,
                    child: Row(
                      children: [
                        if (category.id != 'spun') ...[
                          Text(category.starter, style: text),
                          const SizedBox(width: 10),
                        ],
                        StimulusArt(word!.emoji, size: art),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            word!.word,
                            key: const ValueKey('aac-sentence'),
                            style: text.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          CandyPressable(
            key: const ValueKey('aac-speak'),
            color: word == null ? const Color(0xFFE8E2D6) : Tokens.good,
            lipColor: shade(
              word == null ? const Color(0xFFE8E2D6) : Tokens.good,
              0.15,
            ),
            width: compact ? 52 : 72,
            height: compact ? 52 : 72,
            radius: 40,
            semanticLabel: 'Spune din nou',
            onTap: word == null ? null : onSpeak,
            child: Icon(
              Icons.volume_up_rounded,
              color: Colors.white,
              size: compact ? 28 : 38,
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.words,
    required this.selected,
    required this.compact,
    required this.onPick,
  });

  final List<AacWord> words;
  final AacWord? selected;
  final bool compact;
  final ValueChanged<AacWord> onPick;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      // Cât mai mari: alegem numărul de coloane care dă celule cât mai mari, toate vizibile.
      const gap = 10.0;
      var best = 0.0, cols = 1;
      for (var c = 1; c <= words.length; c++) {
        final rows = (words.length / c).ceil();
        final side = math.min(
          (box.maxWidth - gap * (c - 1)) / c,
          (box.maxHeight - gap * (rows - 1)) / rows,
        );
        if (side > best) {
          best = side;
          cols = c;
        }
      }
      final side = best.clamp(56.0, 210.0);
      return Center(
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: [
            for (final (i, w) in words.indexed)
              SizedBox(
                width: math.min(side, (box.maxWidth - gap * (cols - 1)) / cols),
                height: side,
                child: CandyPressable(
                  key: ValueKey('aac-word-$i'),
                  color: w == selected
                      ? Tokens.goodSoft
                      : const Color(0xFFFFFDF8),
                  lipColor: w == selected
                      ? shade(Tokens.good, 0.1)
                      : const Color(0xFFE3D9C6),
                  border: w == selected ? Tokens.good : null,
                  borderWidth: w == selected ? 4 : 0,
                  padding: const EdgeInsets.all(6),
                  semanticLabel: w.word,
                  onTap: () => onPick(w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: FittedBox(
                          child: StimulusArt(w.emoji, size: side * 0.6),
                        ),
                      ),
                      Text(
                        w.word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (compact
                                    ? Theme.of(context).textTheme.labelSmall
                                    : Theme.of(context).textTheme.titleLarge)!
                                .copyWith(color: Tokens.ink),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
