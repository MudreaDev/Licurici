import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../shared/art_cache.dart';
import '../shared/emoji_art.dart';
import '../shared/mascot.dart';
import '../shared/motion.dart';
import '../shared/voice.dart';
import 'layout.dart';
import 'theme.dart';

/// Ilustrațiile interfeței, vizibile imediat după pornire.
const uiArt = ['🏠', '🔊', '⏸', '😌', '🔁', '⭐', '🧒', '📱'];

class BootState {
  const BootState(this.progress, {this.done = false});

  /// 0..1 — pașii de pornire terminați.
  final double progress;
  final bool done;
}

/// Pornirea aplicației. NU compilăm nimic pe telefon (Dart e compilat AOT la build);
/// aici doar încărcăm în memorie ce trebuie să fie instant disponibil. Fiecare pas e tolerant
/// la erori: o resursă lipsă nu blochează copilul pe ecranul de încărcare.
class BootNotifier extends Notifier<BootState> {
  /// Evită „pâlpâitul” când pornirea e foarte rapidă (nu e o așteptare artificială lungă).
  static const minVisible = Duration(milliseconds: 600);

  @override
  BootState build() {
    Future.microtask(_run);
    return const BootState(0);
  }

  Future<void> _run() async {
    final started = Stopwatch()..start();
    final steps = <Future<void> Function()>[
      () => ref.read(voiceManifestProvider.future),
      () => precacheArt(uiArt),
      () => precacheArt(allGames.map((g) => g.emoji)),
      () => precacheArt(reactionGames.map((g) => g.emoji)),
      // Sprint 2: deschiderea bazei locale Drift + migrările ei.
      // Mai târziu: verificarea pachetelor de conținut descărcate.
    ];
    for (final (i, step) in steps.indexed) {
      try {
        await step();
      } on Object catch (e) {
        debugPrint('pornire, pasul ${i + 1}: $e');
      }
      state = BootState((i + 1) / steps.length);
    }
    final elapsed = started.elapsed;
    if (elapsed < minVisible) await Future<void>.delayed(minVisible - elapsed);
    state = const BootState(1, done: true);
  }
}

final bootProvider = NotifierProvider<BootNotifier, BootState>(
  BootNotifier.new,
);

/// Pune ecranul de pornire peste aplicație până e gata, apoi îl estompează.
/// Tot aici: pe un telefon ținut în portret (posibil doar pe web) cerem rotirea.
class BootGate extends ConsumerStatefulWidget {
  const BootGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<BootGate> {
  bool _overlayGone = false;

  @override
  Widget build(BuildContext context) {
    final boot = ref.watch(bootProvider);
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    return Stack(
      children: [
        if (boot.done) Positioned.fill(child: widget.child),
        // Cu „reduce motion” durata e zero și AnimatedOpacity nu mai apelează onEnd,
        // deci scoatem ecranul direct (altfel ar rămâne peste aplicație).
        if (!_overlayGone && !(boot.done && !motion.feedback))
          Positioned.fill(
            child: IgnorePointer(
              ignoring: boot.done,
              child: AnimatedOpacity(
                opacity: boot.done ? 0 : 1,
                duration: motion.d(450),
                onEnd: () => setState(() => _overlayGone = true),
                child: BootScreen(progress: boot.progress),
              ),
            ),
          ),
        if (layout.phonePortrait) const Positioned.fill(child: RotateHint()),
      ],
    );
  }
}

class BootScreen extends ConsumerWidget {
  const BootScreen({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    final layout = AppLayout.of(context);
    return ColoredBox(
      color: Tokens.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Mascot(size: layout.compact ? 110 : 150, mood: MascotMood.idle),
            SizedBox(height: layout.compact ? 8 : 16),
            Text('Licurici', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 6),
            Text(
                  'Se pregătesc jocurile…',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
                .animate(
                  onPlay: (c) =>
                      motion.ambient ? c.repeat(reverse: true) : null,
                )
                .fade(begin: 1, end: 0.55, duration: 1200.ms),
            SizedBox(height: layout.compact ? 14 : 24),
            _GlowBar(progress: progress),
          ],
        ),
      ),
    );
  }
}

/// Bara de progres „luminoasă”, ca lumina licuriciului.
class _GlowBar extends ConsumerWidget {
  const _GlowBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    const width = 260.0;
    return Semantics(
      label: 'Se încarcă',
      value: '${(progress * 100).round()}%',
      child: Container(
        width: width,
        height: 18,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(9),
          boxShadow: Tokens.shadow,
        ),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress),
          duration: motion.d(350),
          curve: Curves.easeOut,
          builder: (context, v, _) => Container(
            width: math.max(12, (width - 6) * v),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF6DF84), Tokens.sun],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Color(0x88F6DF84), blurRadius: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// „Întoarce telefonul” — jocul e gândit pentru landscape.
class RotateHint extends ConsumerWidget {
  const RotateHint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motion = MotionPolicy.of(context, ref);
    Widget phone = const EmojiArt('📱', size: 110);
    if (motion.movement) {
      phone = phone
          .animate(onPlay: (c) => c.repeat())
          .rotate(
            begin: 0,
            end: -0.25,
            duration: 900.ms,
            curve: Curves.easeInOut,
          )
          .then(delay: 600.ms)
          .rotate(begin: 0, end: 0.25, duration: 500.ms);
    }
    return Material(
      color: Tokens.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              phone,
              const SizedBox(height: 24),
              Text(
                'Întoarce telefonul',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Jocurile se joacă ținând telefonul culcat.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
