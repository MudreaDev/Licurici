import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Reacțiile animate ale unui obiect (README §15.1), într-un singur widget cu structură STABILĂ:
/// copilul nu este niciodată reconstruit când pornește o reacție (altfel animațiile lui de
/// intrare ar reporni). Fiecare reacție se declanșează schimbând contorul ei.
///
/// - [popTick]: crește scurt și revine (răspuns corect);
/// - [hopTick]: sare în sus și revine (valul de obiecte), cu întârzierea [hopDelay];
/// - [shakeTick]: clătinare blândă ±4 px, care se stinge (greșeală, fără roșu);
/// - [pulse]: pulsează continuu cât e activ (ghidaj după inactivitate).
class Juice extends StatefulWidget {
  const Juice({
    super.key,
    required this.child,
    this.enabled = true,
    this.popTick = 0,
    this.hopTick = 0,
    this.hopDelay = Duration.zero,
    this.shakeTick = 0,
    this.pulse = false,
  });

  final Widget child;
  final bool enabled;
  final int popTick;
  final int hopTick;
  final Duration hopDelay;
  final int shakeTick;
  final bool pulse;

  @override
  State<Juice> createState() => _JuiceState();
}

class _JuiceState extends State<Juice> with TickerProviderStateMixin {
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  Timer? _hopTimer;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(Juice old) {
    super.didUpdateWidget(old);
    if (!widget.enabled) return;
    if (widget.popTick != old.popTick) _pop.forward(from: 0);
    if (widget.shakeTick != old.shakeTick) _shake.forward(from: 0);
    if (widget.hopTick != old.hopTick) {
      _hopTimer?.cancel();
      _hopTimer = Timer(widget.hopDelay, () {
        if (mounted) _hop.forward(from: 0);
      });
    }
    if (widget.pulse != old.pulse || widget.enabled != old.enabled) _syncPulse();
  }

  void _syncPulse() {
    if (widget.pulse && widget.enabled) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _hopTimer?.cancel();
    _pop.dispose();
    _hop.dispose();
    _shake.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_pop, _hop, _shake, _pulse]),
        child: widget.child,
        builder: (context, child) {
          final scale = 1 +
              0.12 * math.sin(math.pi * Curves.easeOut.transform(_pop.value)) +
              0.035 * (1 - math.cos(2 * math.pi * _pulse.value));
          final dy = -14 * math.sin(math.pi * _hop.value);
          final s = _shake.value;
          final dx = s == 0 ? 0.0 : math.sin(s * math.pi * 6) * 4 * (1 - s);
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(scale: scale, child: child),
          );
        },
      );
}
