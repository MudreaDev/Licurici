/// Scene generate din seed (ADR-027 + ADR-028): fiecare nivel / sesiune primește un fundal
/// propriu, dar mereu calm. Aplicația îl desenează cu shadere și particule; aici sunt doar
/// parametrii, deterministici pentru același seed.
library;

import 'dart:math';

/// Unde apare scena: pe ecranele de joc fundalul trebuie să fie mai liniștit decât acasă,
/// ca să nu concureze cu stimulul.
enum SceneUse { home, game }

/// Momentul zilei — doar palete pastel, fără noapte întunecată (README §14.1).
enum SceneMood { morning, day, afternoon, dusk }

/// O paletă: culori ARGB (ca să rămânem fără Flutter în pachetul ăsta).
class ScenePalette {
  const ScenePalette({
    required this.skyTop,
    required this.skyBottom,
    required this.hillFar,
    required this.hillNear,
    required this.cloud,
    required this.glow,
  });

  final int skyTop, skyBottom, hillFar, hillNear, cloud, glow;

  List<int> get all => [skyTop, skyBottom, hillFar, hillNear, cloud, glow];
}

const Map<SceneMood, ScenePalette> scenePalettes = {
  SceneMood.morning: ScenePalette(
    skyTop: 0xFFBFE3EE,
    skyBottom: 0xFFF6EBD9,
    hillFar: 0xFFB5D8C8,
    hillNear: 0xFF9CCBB0,
    cloud: 0xFFFFFFFF,
    glow: 0xFFF7DC8A,
  ),
  SceneMood.day: ScenePalette(
    skyTop: 0xFFA9D6EA,
    skyBottom: 0xFFE6F4F1,
    hillFar: 0xFFAED6C1,
    hillNear: 0xFF8FC6A6,
    cloud: 0xFFFFFFFF,
    glow: 0xFFF2CF6B,
  ),
  SceneMood.afternoon: ScenePalette(
    skyTop: 0xFFB9D4EC,
    skyBottom: 0xFFF5E4D2,
    hillFar: 0xFFBCD3B5,
    hillNear: 0xFFA1C49A,
    cloud: 0xFFFFF8EE,
    glow: 0xFFF0B9A0,
  ),
  SceneMood.dusk: ScenePalette(
    skyTop: 0xFFB7B3DD,
    skyBottom: 0xFFF3D9CF,
    hillFar: 0xFFA9B9C9,
    hillNear: 0xFF8FAFAE,
    cloud: 0xFFF7EEF4,
    glow: 0xFFF2CF6B,
  ),
};

class SceneSpec {
  const SceneSpec({
    required this.seed,
    required this.use,
    required this.mood,
    required this.cloudCover,
    required this.wind,
    required this.hillShape,
    required this.fireflies,
  });

  /// Aceeași scenă pentru același (seed, use) — reproductibil, ca nivelurile (ADR-027).
  factory SceneSpec.generate(int seed, {SceneUse use = SceneUse.home}) {
    final r = Random(seed);
    final quiet = use == SceneUse.game;
    double between(double a, double b) => a + r.nextDouble() * (b - a);
    return SceneSpec(
      seed: seed,
      use: use,
      mood: SceneMood.values[r.nextInt(SceneMood.values.length)],
      cloudCover: quiet ? between(0.15, 0.35) : between(0.25, 0.6),
      wind: quiet ? between(0.004, 0.012) : between(0.01, 0.03),
      hillShape: r.nextDouble() * 100,
      fireflies: quiet ? 2 + r.nextInt(4) : 8 + r.nextInt(11),
    );
  }

  /// Scena unui nivel: aceeași pentru același joc și nivel.
  factory SceneSpec.forLevel(String gameId, int level, {SceneUse use = SceneUse.game}) =>
      SceneSpec.generate(Object.hash(gameId, level) & 0x7fffffff, use: use);

  final int seed;
  final SceneUse use;
  final SceneMood mood;

  /// 0..1 — cât din cer e acoperit de nori.
  final double cloudCover;

  /// Viteza norilor (fracțiuni din lățime pe secundă).
  final double wind;

  /// Decalajul zgomotului pentru forma dealurilor.
  final double hillShape;

  /// Câți licurici plutesc în scenă (≤ 40 de particule, README §15.1).
  final int fireflies;

  ScenePalette get palette => scenePalettes[mood]!;

  @override
  String toString() => 'SceneSpec($seed, ${use.name}, ${mood.name})';
}
