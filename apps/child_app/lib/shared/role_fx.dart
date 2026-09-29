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
  });

  final double opacity;
  final double scale;
  final double tilt;
  final bool tappable;
  final bool pulse;
  final bool float;

  static RoleStyle of(FxRole role, MotionPolicy motion) {
    final move = motion.movement;
    return switch (role) {
      FxRole.target => const RoleStyle(tappable: true),
      // la `gentle`/`off` ghidajul rămâne vizibil prin chenar (îl desenează jocul), fără pulsare
      FxRole.hinted => RoleStyle(tappable: true, pulse: move),
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
