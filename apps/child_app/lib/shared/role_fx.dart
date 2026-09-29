import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'juice.dart';
import 'motion.dart';
import 'pressable.dart';

/// Rolul unui obiect într-o mecanică (ADR-028). Jocurile NU animă obiectele: le dau un rol,
/// iar [RoleFx] alege efectul. Orice joc nou primește aceleași animații, gratis.
enum FxRole {
  /// Variantă care se poate atinge (țintă posibilă): intră pe ecran, se apasă.
  target,

  /// Ținta indicată de ajutor (P3 / ghidaj după pauză): pulsează.
  hinted,

  /// Ținta arătată de mâna animată (P4, model complet): mâna vine și „atinge” răspunsul.
  modeled,

  /// Răspunsul corect, ales: pop (squash & stretch), rămâne evidențiat.
  correct,

  /// Variantă greșită atinsă: tremur blând (fără roșu), apoi estompată.
  rejected,

  /// Distractor scos din joc (după rezolvare sau P2 — reducerea variantelor): estompat.
  faded,

  /// Recompensă (stele, pești): intră elastic, apoi plutește.
  reward,

  /// Obiect tras cu degetul: ridicat (mai mare), ușor înclinat.
  dragged,
}

/// Cum arată un rol (valori țintă; tranzițiile le face [RoleFx]). Funcție pură → testabilă.
class RoleStyle {
  const RoleStyle({
    this.opacity = 1,
    this.scale = 1,
    this.tilt = 0,
    this.tappable = false,
    this.pulse = false,
    this.float = false,
    this.hand = false,
  });

  final double opacity;
  final double scale;
  final double tilt;
  final bool tappable;
  final bool pulse;
  final bool float;

  /// Mâna care arată răspunsul (vizibilă și fără mișcare: e ajutor, nu decor).
  final bool hand;

  static RoleStyle of(FxRole role, MotionPolicy motion) {
    final move = motion.movement;
    return switch (role) {
      FxRole.target => const RoleStyle(tappable: true),
      // la `gentle`/`off` ghidajul rămâne vizibil prin chenar (îl desenează jocul), fără pulsare
      FxRole.hinted => RoleStyle(tappable: true, pulse: move),
      FxRole.modeled => RoleStyle(tappable: true, pulse: move, hand: true),
      FxRole.correct => const RoleStyle(),
      FxRole.rejected || FxRole.faded => const RoleStyle(opacity: 0.35),
      FxRole.reward => RoleStyle(float: motion.ambient),
      FxRole.dragged => RoleStyle(
        scale: motion.feedback ? 1.08 : 1,
        tilt: move ? 0.05 : 0,
        tappable: true,
      ),
    };
  }
}

/// Aplică efectul rolului peste [child]: intrare eșalonată după [index], apăsare, pop, tremur,
/// pulsare, plutire, estompare. Totul prin [MotionPolicy]: `gentle` păstrează estompările,
/// `off` nu mișcă nimic. Structura e stabilă: [child] nu e reconstruit când se schimbă rolul.
class RoleFx extends ConsumerStatefulWidget {
  const RoleFx({
    super.key,
    required this.role,
    required this.child,
    this.index = 0,
    this.onTap,
    this.semanticLabel,
    this.enter = true,
  });

  final FxRole role;
  final Widget child;

  /// Poziția în grup: întârzie intrarea (val) și defazează plutirea.
  final int index;

  /// Atingerea (ignorată dacă rolul nu se poate atinge).
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Animația de intrare (la montare).
  final bool enter;

  @override
  ConsumerState<RoleFx> createState() => _RoleFxState();
}

class _RoleFxState extends ConsumerState<RoleFx> {
  int _pop = 0;
  int _shake = 0;

  @override
  void didUpdateWidget(RoleFx old) {
    super.didUpdateWidget(old);
    if (widget.role == old.role) return;
    if (widget.role == FxRole.correct) _pop++;
    if (widget.role == FxRole.rejected) _shake++;
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final style = RoleStyle.of(widget.role, motion);
    Widget w = Juice(
      enabled: motion.movement,
      popTick: _pop,
      shakeTick: _shake,
      pulse: style.pulse,
      float: style.float,
      floatPhase: widget.index * 0.21,
      child: AnimatedScale(
        scale: style.scale,
        duration: motion.d(160),
        curve: Curves.easeOut,
        child: AnimatedRotation(
          turns: style.tilt / 6.283185307179586,
          duration: motion.d(160),
          child: widget.child,
        ),
      ),
    );
    w = AnimatedOpacity(
      opacity: style.opacity,
      duration: motion.d(300),
      child: w,
    );
    // Structură stabilă: mâna e mereu al doilea copil al stivei (sau nimic), obiectul rămâne primul.
    w = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        w,
        if (style.hand)
          Positioned.fill(
            child: IgnorePointer(child: _ModelHand(moving: motion.movement)),
          ),
      ],
    );
    w = Pressable(
      semanticLabel: widget.semanticLabel,
      onTap: style.tappable ? widget.onTap : null,
      child: w,
    );
    if (!widget.enter) return w;
    final delay = motion.d(60 * widget.index);
    return widget.role == FxRole.reward
        ? w
              .animate(delay: motion.d(250 + 350 * widget.index))
              .fadeIn(duration: motion.d(200))
              .scaleXY(
                begin: motion.movement ? 0.2 : 1,
                end: 1,
                duration: motion.d(500),
                curve: Curves.elasticOut,
              )
              .rotate(begin: motion.movement ? -0.15 : 0, end: 0)
        : w
              .animate(delay: delay)
              .fadeIn(duration: motion.d(280))
              .slideX(
                begin: motion.movement ? 0.2 : 0,
                end: 0,
                curve: Curves.easeOutBack,
              );
  }
}

/// Mâna animată (P4): intră dinspre colț, apasă de două ori ținta, se oprește, reia.
/// Fără mișcare (modul calm, reduce motion) stă nemișcată pe țintă.
class _ModelHand extends StatelessWidget {
  const _ModelHand({required this.moving});

  final bool moving;

  @override
  Widget build(BuildContext context) {
    Widget hand = const Icon(
      Icons.touch_app_rounded,
      key: ValueKey('model-hand'),
      size: 54,
      color: Color(0xFF3D4A5C),
      shadows: [Shadow(color: Colors.white, blurRadius: 6)],
    );
    if (moving) {
      hand = hand
          .animate(onPlay: (c) => c.repeat())
          .fadeIn(duration: 200.ms)
          .move(
            begin: const Offset(70, 80),
            end: Offset.zero,
            duration: 650.ms,
            curve: Curves.easeOutCubic,
          )
          .then()
          .scaleXY(end: 0.85, duration: 140.ms)
          .then()
          .scaleXY(end: 1 / 0.85, duration: 140.ms)
          .then()
          .scaleXY(end: 0.85, duration: 140.ms)
          .then()
          .scaleXY(end: 1 / 0.85, duration: 140.ms)
          .then(delay: 700.ms)
          .fadeOut(duration: 250.ms);
    }
    return Align(alignment: const Alignment(0.35, 0.45), child: hand);
  }
}
