import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

double _luma(int argb) {
  final r = (argb >> 16) & 0xff, g = (argb >> 8) & 0xff, b = argb & 0xff;
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
}

void main() {
  test('același seed → aceeași scenă', () {
    final a = SceneSpec.generate(42), b = SceneSpec.generate(42);
    expect([a.mood, a.cloudCover, a.wind, a.hillShape, a.fireflies],
        [b.mood, b.cloudCover, b.wind, b.hillShape, b.fireflies]);
  });

  test('seed-uri diferite dau scene variate', () {
    final scenes = [for (var s = 0; s < 40; s++) SceneSpec.generate(s)];
    expect(scenes.map((s) => s.mood).toSet().length, greaterThan(2));
    expect(scenes.map((s) => s.hillShape).toSet().length, 40);
  });

  test('pe ecranele de joc scena e mai liniștită', () {
    for (var s = 0; s < 200; s++) {
      final game = SceneSpec.generate(s, use: SceneUse.game);
      expect(game.fireflies, inInclusiveRange(2, 5));
      expect(game.cloudCover, lessThanOrEqualTo(0.35));
      expect(game.wind, lessThanOrEqualTo(0.012));
      final home = SceneSpec.generate(s);
      expect(home.fireflies, lessThanOrEqualTo(40));
    }
  });

  test('nivelul determină scena', () {
    expect(SceneSpec.forLevel('pescarul', 3).seed, SceneSpec.forLevel('pescarul', 3).seed);
    expect(SceneSpec.forLevel('pescarul', 3).seed, isNot(SceneSpec.forLevel('pescarul', 4).seed));
  });

  test('paletele sunt deschise și calme (fără fundal întunecat)', () {
    for (final p in scenePalettes.values) {
      expect(_luma(p.skyTop), greaterThan(0.6));
      expect(_luma(p.skyBottom), greaterThan(0.75));
      expect(_luma(p.hillNear), greaterThan(0.55));
    }
  });
}
