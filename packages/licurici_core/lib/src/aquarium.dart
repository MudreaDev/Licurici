/// Acvariul (README §2): peștii copilului înoată liber. Copilul nu mișcă acvariul, doar
/// interacționează cu peștii: o atingere îi sperie (fug de deget), apăsarea lungă îi adună
/// încet în jurul degetului, mâncarea aruncată în apă îi cheamă.
///
/// Simularea e pură și deterministă (seed + pas de timp), ca să se poată testa. Coordonatele
/// sunt în înălțimi de acvariu: y ∈ [0, 1] de sus în jos, x ∈ [0, [Aquarium.width]].
library;

import 'dart:math';

/// Ce face peștele acum.
enum FishMode { wander, rest, flee, gather, food }

class SwimmingFish {
  SwimmingFish({
    required this.id,
    required this.species,
    required this.length,
    required this.cruise,
    required Point<double> at,
    this.liveliness = 1,
  }) : pos = at;

  final String id;
  final String species;

  /// Lungimea peștelui (înălțimi de acvariu).
  final double length;

  /// Viteza obișnuită (înălțimi de acvariu pe secundă).
  final double cruise;

  /// Cât de tare dă din coadă (din model).
  final double liveliness;

  Point<double> pos;
  Point<double> vel = const Point(0, 0);
  Point<double> target = const Point(0, 0);
  FishMode mode = FishMode.wander;

  /// −1 privește spre stânga, +1 spre dreapta; trece lin prin 0 la întoarcere.
  double facing = 1;

  /// Faza bătăii din coadă (radiani) — o citește desenul.
  double phase = 0;

  /// 0…1: cât de bucuros e (a mâncat); face coada să bată mai tare câteva secunde.
  double joy = 0;

  double _timer = 0;
  Point<double> _offset = const Point(0, 0);

  /// Cât de repede merge față de viteza obișnuită (pentru ritmul cozii).
  double get effort => (_len(vel) / cruise).clamp(0.0, 3.0);

  /// Înclinarea corpului (radiani): în sus sau în jos după direcția mersului.
  double get tilt => atan2(vel.y, max(vel.x.abs(), 0.02)).clamp(-0.45, 0.45) * (facing >= 0 ? 1 : -1);

  /// Gura (unde mănâncă).
  Point<double> get mouth => Point(pos.x + facing.sign * length * 0.45, pos.y);
}

class FoodFlake {
  FoodFlake(this.pos, this.drift);

  Point<double> pos;
  final double drift;

  /// Secunde de când a căzut pe nisip.
  double grounded = 0;
  double age = 0;
}

/// Ce s-a întâmplat la un pas (pentru sunete și sclipiri).
sealed class AquariumEvent {
  const AquariumEvent(this.at);
  final Point<double> at;
}

class FishAte extends AquariumEvent {
  const FishAte(super.at, this.fishId);
  final String fishId;
}

class Aquarium {
  Aquarium({required this.width, int seed = 0}) : _rng = Random(seed);

  /// Lățimea acvariului în înălțimi (raportul ecranului).
  double width;

  /// Apa: de sub suprafață până deasupra nisipului.
  static const double top = 0.14, bottom = 0.82;

  final Random _rng;
  final fish = <SwimmingFish>[];
  final food = <FoodFlake>[];
  final _events = <AquariumEvent>[];

  Point<double>? _gather;
  double _time = 0;

  /// Raza în care o atingere sperie peștii.
  static const double fleeRadius = 0.42;

  void add(SwimmingFish f, {bool diveIn = false}) {
    if (diveIn) {
      f.pos = Point(f.pos.x, -0.1);
      f.vel = Point(0, f.cruise * 2.2);
      f.mode = FishMode.flee; // coboară repede, apoi se liniștește
      f._timer = 0.9;
    }
    f.target = _randomSpot();
    fish.add(f);
  }

  void remove(String id) => fish.removeWhere((f) => f.id == id);

  /// Atingere scurtă: peștii din apropiere fug de deget.
  void tap(Point<double> at) {
    for (final f in fish) {
      final d = f.pos - at;
      final dist = _len(d);
      if (dist > fleeRadius) continue;
      final away = dist < 1e-6 ? Point(_rng.nextBool() ? 1.0 : -1.0, 0.0) : d * (1 / dist);
      final strength = 1 - dist / fleeRadius;
      f.mode = FishMode.flee;
      f._timer = 0.8 + strength * 0.6;
      f.vel = away * (f.cruise * (2.5 + 2.5 * strength));
      f.target = _clamp(at + away * (fleeRadius * 1.6));
    }
  }

  /// Apăsare lungă: peștii vin încet și se adună în jurul degetului.
  void gather(Point<double> at) {
    final first = _gather == null;
    _gather = _clamp(at);
    if (!first) return;
    for (final (i, f) in fish.indexed) {
      f.mode = FishMode.gather;
      // Fiecare își alege locul lui în cerc, ca să nu se suprapună.
      final a = i * 2.39996 + _rng.nextDouble() * 0.5;
      final r = 0.07 + 0.05 * (i % 3);
      f._offset = Point(cos(a) * r * 1.4, sin(a) * r * 0.8);
    }
  }

  /// Degetul s-a ridicat: peștii pleacă iar în treaba lor.
  void release() {
    _gather = null;
    for (final f in fish) {
      if (f.mode == FishMode.gather) {
        f.mode = FishMode.wander;
        f.target = _randomSpot();
      }
    }
  }

  /// Mâncare aruncată la suprafață, în jurul lui [x].
  void feed(double x, {int flakes = 6}) {
    for (var i = 0; i < flakes; i++) {
      food.add(
        FoodFlake(
          Point((x + (_rng.nextDouble() - 0.5) * 0.3).clamp(0.05, width - 0.05), top - 0.06 - _rng.nextDouble() * 0.05),
          _rng.nextDouble() * pi * 2,
        ),
      );
    }
  }

  /// Evenimentele de la ultimul apel.
  List<AquariumEvent> drainEvents() {
    final e = List<AquariumEvent>.of(_events);
    _events.clear();
    return e;
  }

  void step(double dt) {
    _time += dt;
    _stepFood(dt);
    for (final f in fish) {
      _think(f, dt);
    }
    _separate(dt);
    for (final f in fish) {
      _move(f, dt);
    }
  }

  void _stepFood(double dt) {
    for (final p in food) {
      p.age += dt;
      final ground = bottom + 0.06;
      if (p.pos.y < ground) {
        final sink = p.pos.y < top ? 0.25 : 0.07;
        p.pos = Point(p.pos.x + sin(_time * 2.2 + p.drift) * 0.025 * dt, min(ground, p.pos.y + sink * dt));
      } else {
        p.grounded += dt;
      }
    }
    food.removeWhere((p) => p.grounded > 8);
  }

  void _think(SwimmingFish f, double dt) {
    f._timer -= dt;
    f.joy = max(0, f.joy - dt * 0.4);
    final g = _gather;
    if (g != null) {
      if (f.mode != FishMode.flee || f._timer <= 0) f.mode = FishMode.gather;
    } else if (f.mode == FishMode.gather) {
      f.mode = FishMode.wander;
    }

    switch (f.mode) {
      case FishMode.flee:
        if (f._timer <= 0) {
          f.mode = FishMode.wander;
          f.target = _randomSpot();
        }
      case FishMode.gather:
        // Se rotesc încet în jurul degetului.
        final a = _time * 0.5;
        final o = Point(f._offset.x * cos(a) - f._offset.y * sin(a) * 1.7, f._offset.y * cos(a) + f._offset.x * sin(a) * 0.6);
        f.target = _clamp(g! + o);
      case FishMode.food:
        final flake = _nearestFood(f);
        if (flake == null) {
          f.mode = FishMode.wander;
          f.target = _randomSpot();
        } else {
          f.target = flake.pos;
          if (_len(f.mouth - flake.pos) < max(0.045, f.length * 0.22)) {
            food.remove(flake);
            f.joy = 1;
            _events.add(FishAte(flake.pos, f.id));
          }
        }
      case FishMode.wander || FishMode.rest:
        if (_nearestFood(f) != null) {
          f.mode = FishMode.food;
        } else if (f.mode == FishMode.rest) {
          if (f._timer <= 0) {
            f.mode = FishMode.wander;
            f.target = _randomSpot();
          }
        } else if (_len(f.target - f.pos) < 0.06) {
          // Uneori se oprește puțin, ca un pește adevărat.
          if (_rng.nextDouble() < 0.35) {
            f.mode = FishMode.rest;
            f._timer = 1.5 + _rng.nextDouble() * 2.5;
            f.target = f.pos;
          } else {
            f.target = _randomSpot(near: f.pos);
          }
        }
    }
  }

  void _separate(double dt) {
    for (var i = 0; i < fish.length; i++) {
      for (var j = i + 1; j < fish.length; j++) {
        final a = fish[i], b = fish[j];
        final d = a.pos - b.pos;
        final dist = _len(d);
        final minD = (a.length + b.length) * 0.32;
        if (dist >= minD || dist < 1e-6) continue;
        final push = d * ((minD - dist) / dist * 1.5 * dt);
        a.vel += push;
        b.vel -= push;
      }
    }
  }

  void _move(SwimmingFish f, double dt) {
    final speed = switch (f.mode) {
      FishMode.flee => f.cruise * 2.4,
      FishMode.food => f.cruise * 1.6,
      FishMode.gather => f.cruise * 1.1,
      FishMode.rest => f.cruise * 0.08,
      FishMode.wander => f.cruise,
    };
    final to = f.target - f.pos;
    final dist = _len(to);
    // Încetinește când ajunge (nu se oprește brusc).
    final want = dist < 1e-6 ? const Point(0.0, 0.0) : to * (speed * min(1, dist / 0.12) / dist);
    final k = min(1.0, dt * (f.mode == FishMode.flee ? 2.5 : 1.4));
    f.vel += (want - f.vel) * k;
    f.pos += f.vel * dt;

    // Pereții apei: peștele e împins înapoi lin, nu trece prin ei.
    final mx = f.length * 0.5, my = f.length * 0.25;
    final x = f.pos.x.clamp(mx, width - mx).toDouble();
    final y = f.mode == FishMode.flee && f.pos.y < top ? f.pos.y : f.pos.y.clamp(top + my, bottom - my).toDouble();
    if (x != f.pos.x) f.vel = Point(-f.vel.x * 0.3, f.vel.y);
    f.pos = Point(x, y);

    // Se întoarce doar când merge clar în sens opus (fără tremurat).
    if (f.vel.x.abs() > f.cruise * 0.15) {
      final want = f.vel.x.sign;
      f.facing = (f.facing + (want - f.facing).clamp(-dt * 4.5, dt * 4.5)).clamp(-1.0, 1.0);
    }
    f.phase += dt * (3 + 6 * f.effort + 4 * f.joy) * f.liveliness;
  }

  FoodFlake? _nearestFood(SwimmingFish f) {
    FoodFlake? best;
    var bd = double.infinity;
    for (final p in food) {
      if (p.pos.y < top) continue; // încă la suprafață
      final d = _len(p.pos - f.pos);
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  }

  Point<double> _randomSpot({Point<double>? near}) {
    final p = Point(0.1 + _rng.nextDouble() * (width - 0.2), top + 0.06 + _rng.nextDouble() * (bottom - top - 0.12));
    if (near == null) return p;
    // Drumuri nu prea lungi: peștele explorează pe rând părți ale acvariului.
    final d = p - near;
    final l = _len(d);
    return l < 0.6 ? p : _clamp(near + d * (0.6 / l));
  }

  Point<double> _clamp(Point<double> p) =>
      Point(p.x.clamp(0.08, width - 0.08).toDouble(), p.y.clamp(top + 0.05, bottom - 0.05).toDouble());
}

double _len(Point<double> p) => sqrt(p.x * p.x + p.y * p.y);
