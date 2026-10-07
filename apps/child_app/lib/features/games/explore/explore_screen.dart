import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../../app/layout.dart';
import '../../../app/theme.dart';
import '../../../shared/fx/scene_background.dart';
import '../../../shared/mascot.dart';
import '../../../shared/motion.dart';
import '../../../shared/reward_finish.dart';
import '../../../shared/stimulus_art.dart';
import '../../../shared/top_bar.dart';
import '../../../shared/ui/candy.dart';
import '../../../shared/voice.dart';
import '../../settings/settings.dart';
import '../sort/sort_screen.dart';

/// Rutele unei explorări: harta și, deasupra ei, sortarea unei opriri (întoarce rezultatul).
GoRoute exploreRoute({
  Page<void> Function(BuildContext, GoRouterState, Widget)? page,
}) {
  Page<void> wrap(BuildContext c, GoRouterState s, Widget w) =>
      page?.call(c, s, w) ?? MaterialPage<void>(key: s.pageKey, child: w);
  ExploreEpisode? episodeOf(GoRouterState s) =>
      exploreEpisodeById(s.pathParameters['id']!);
  return GoRoute(
    path: '/exploreaza/:id',
    redirect: (context, state) => episodeOf(state) == null ? '/' : null,
    pageBuilder: (context, state) =>
        wrap(context, state, ExploreScreen(episode: episodeOf(state)!)),
    routes: [
      GoRoute(
        path: 'oprire/:stop',
        pageBuilder: (context, state) {
          final e = episodeOf(state)!;
          final stop = e.stops.firstWhere(
            (s) => s.id == state.pathParameters['stop'],
            orElse: () => e.stops.first,
          );
          return wrap(
            context,
            state,
            SortScreen(
              preset: e.levelFor(stop),
              title: stop.name,
              onComplete: (result) => context.pop(result),
            ),
          );
        },
      ),
    ],
  );
}

/// Explorare (`/exploreaza/:id`): o hartă cu opriri legate de un drum. La fiecare oprire,
/// Licurici spune o mică poveste, apoi copilul sortează (ecranul „Sortăm”). Oprirea făcută
/// primește o stea; când toate sunt făcute, finalul comun.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key, required this.episode});

  final ExploreEpisode episode;

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  /// Opririle făcute → stele (1–3, după sortare).
  final _done = <String, int>{};
  String _bubble = 'Alege o oprire pe hartă.';
  String? _sticker;
  bool _finished = false;

  ExploreEpisode get _e => widget.episode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say([_bubble]);
    });
  }

  /// Prima oprire nefăcută (sugerată: pulsează).
  ExploreStop? get _next {
    for (final s in _e.stops) {
      if (!_done.containsKey(s.id)) return s;
    }
    return null;
  }

  Future<void> _open(ExploreStop stop) async {
    setState(() => _bubble = stop.intro);
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => _StopIntro(stop: stop),
    );
    if (go != true || !mounted) {
      setState(() => _bubble = 'Alege o oprire pe hartă.');
      return;
    }
    final result = await context.push<SortResult>(
      '/exploreaza/${_e.id}/oprire/${stop.id}',
    );
    if (result != null) {
      _completed(stop, result);
    } else if (mounted) {
      setState(() => _bubble = 'Alege o oprire pe hartă.');
    }
  }

  void _completed(ExploreStop stop, SortResult result) {
    if (!mounted) return;
    setState(() {
      _done[stop.id] = result.stars;
      if (_done.length == _e.stops.length) {
        _finished = true;
        _sticker = ref.read(settingsProvider.notifier).awardSticker();
        _bubble = _e.outro;
      } else {
        _bubble = 'Bravo! Alege altă oprire.';
      }
    });
    ref.read(voiceProvider).say([_bubble]);
  }

  int get _stars {
    if (_done.isEmpty) return 1;
    return (_done.values.reduce((a, b) => a + b) / _done.length).round().clamp(
      1,
      3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return Scaffold(
      body: SceneBackground(
        spec: SceneSpec.generate(_e.id.hashCode & 0xffff),
        child: SafeArea(
          child: Column(
            children: [
              TopBar(title: _e.name),
              Expanded(
                child: _finished
                    ? RewardFinish(
                        stars: _stars,
                        sticker: _sticker,
                        title: _e.outro,
                        actions: [
                          FinishAction(
                            'Încă o dată',
                            Icons.replay_rounded,
                            Tokens.primary,
                            () => setState(() {
                              _done.clear();
                              _finished = false;
                              _sticker = null;
                              _bubble = 'Alege o oprire pe hartă.';
                            }),
                          ),
                          FinishAction(
                            'Acasă',
                            Icons.home_rounded,
                            Tokens.good,
                            () => context.go('/'),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              // Jos rămâne loc pentru Licurici: opririle nu stau sub el.
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                layout.mascot + (layout.compact ? 4 : 24),
                              ),
                              child: _Map(
                                episode: _e,
                                done: _done,
                                next: _next,
                                onOpen: _open,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 6,
                            width: layout.size.width * 0.45,
                            child: IgnorePointer(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Mascot(
                                    size: layout.mascot,
                                    mood: MascotMood.wave,
                                  ),
                                  const SizedBox(width: 8),
                                  // Pe telefon balonul n-are loc; vocea spune oricum textul.
                                  if (!layout.compact)
                                    Flexible(
                                      child: SpeechBubble(
                                        tail: BubbleTail.left,
                                        child: Text(
                                          _bubble,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                        ),
                                      ),
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
      ),
    );
  }
}

/// Harta: un drum punctat care leagă opririle, în ordine; fiecare oprire e un buton rotund.
class _Map extends ConsumerWidget {
  const _Map({
    required this.episode,
    required this.done,
    required this.next,
    required this.onOpen,
  });

  final ExploreEpisode episode;
  final Map<String, int> done;
  final ExploreStop? next;
  final void Function(ExploreStop) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final compact = AppLayout.of(context).compact;
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(compact ? 76.0 : 120.0, box.maxHeight * 0.3);
        Offset at(ExploreStop s) =>
            Offset(s.x * box.maxWidth, s.y * box.maxHeight);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PathPainter([for (final s in episode.stops) at(s)]),
              ),
            ),
            for (final s in episode.stops)
              Positioned(
                // Eticheta e mai lată decât butonul: numele lungi încap pe două rânduri.
                left: (at(s).dx - side * 0.9).clamp(
                  0.0,
                  box.maxWidth - side * 1.8,
                ),
                top: (at(s).dy - side / 2).clamp(
                  0.0,
                  box.maxHeight - side - 34,
                ),
                width: side * 1.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StopButton(
                      stop: s,
                      side: side,
                      stars: done[s.id],
                      suggested: next == s,
                      motion: motion,
                      onTap: () => onOpen(s),
                    ),
                    const SizedBox(height: 4),
                    OutlinedTitle(
                      s.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      stroke: 4,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontSize: compact ? 13 : 18,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({
    required this.stop,
    required this.side,
    required this.stars,
    required this.suggested,
    required this.motion,
    required this.onTap,
  });

  final ExploreStop stop;
  final double side;
  final int? stars;
  final bool suggested;
  final MotionPolicy motion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = stars != null;
    Widget button = CandyPressable(
      key: ValueKey('stop-${stop.id}'),
      color: done ? Tokens.goodSoft : const Color(0xFFFFFBF4),
      radius: side / 2,
      lip: 6,
      width: side,
      height: side,
      semanticLabel: stop.name,
      border: suggested ? Tokens.sun : (done ? Tokens.good : null),
      borderWidth: suggested || done ? 4 : 0,
      onTap: onTap,
      child: Center(child: StimulusArt(stop.emoji, size: side * 0.58)),
    );
    if (suggested && motion.movement) {
      button = button
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: 1.07,
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        if (done)
          Positioned(
            right: -6,
            top: -6,
            child: Icon(
              Icons.star_rounded,
              key: ValueKey('stop-done-${stop.id}'),
              color: const Color(0xFFF2C14E),
              size: side * 0.36,
              shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
            ),
          ),
      ],
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.points);

  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final mid = (a + b) / 2 + Offset(0, -size.height * 0.08);
      path.quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xCCFFF6DC);
    // Drum punctat: bucăți scurte de-a lungul curbei.
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 30) {
        canvas.drawPath(m.extractPath(d, math.min(d + 16, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.points != points;
}

/// Povestea opririi, spusă de Licurici, apoi „Hai!”.
class _StopIntro extends ConsumerStatefulWidget {
  const _StopIntro({required this.stop});

  final ExploreStop stop;

  @override
  ConsumerState<_StopIntro> createState() => _StopIntroState();
}

class _StopIntroState extends ConsumerState<_StopIntro> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(voiceProvider).say([widget.stop.intro]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: CandyPanel(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Mascot(size: compact ? 90 : 130, mood: MascotMood.happy),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StimulusArt(widget.stop.emoji, size: compact ? 36 : 48),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.stop.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.stop.intro,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium!.copyWith(color: Tokens.ink),
                  ),
                  const SizedBox(height: 16),
                  CandyButton(
                    key: const ValueKey('stop-go'),
                    label: 'Hai!',
                    icon: Icons.play_arrow_rounded,
                    color: Tokens.good,
                    minWidth: 150,
                    onTap: () => Navigator.of(context).pop(true),
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
