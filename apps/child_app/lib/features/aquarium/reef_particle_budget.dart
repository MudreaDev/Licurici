/// Limitele simultane pentru straturile acvariului, inclusiv interacțiunile.
abstract final class ReefParticleBudget {
  static const effects = 2;
  static const perEffect = 7;
  static const springBubbles = 4;
  static const plankton = 6;
  static const chestBubbles = 6;
  static const foreground = 4;
  static const night = 6;

  static const total = effects * perEffect + springBubbles + plankton + chestBubbles + foreground + night;
}
