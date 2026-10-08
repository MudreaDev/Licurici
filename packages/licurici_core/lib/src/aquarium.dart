/// Acvariul (README §2): peștii copilului înoată liber. Copilul nu mișcă acvariul, doar
/// interacționează cu peștii: o atingere îi sperie (fug de deget), apăsarea lungă îi adună
/// încet în jurul degetului, mâncarea aruncată în apă îi cheamă.
///
/// Simularea e pură și deterministă (seed + pas de timp), ca să se poată testa.
///
/// **Coordonate.** `pos` e locul peștelui **pe ecran**, în înălțimi de acvariu: y ∈ [0, 1]
/// de sus în jos, x ∈ [0, [Aquarium.width]]. În plus, fiecare pește are o **adâncime**
/// `z` ∈ [0, 1] (0 = lângă geam, 1 = la peretele din spate): peștii din spate par mai mici,
/// se mișcă mai încet pe ecran și sunt mai estompați (îi desenează aplicația).
///
/// **Înotul** e fizic, nu o interpolare spre țintă: peștele are o direcție (`yaw`, în
/// planul orizontal x–adâncime) pe care o rotește cu o viteză unghiulară limitată, o viteză
/// pe care o câștigă din coadă (impuls) și o pierde prin frecare (alunecare). De aici vin
/// virajele largi, întoarcerea prin „față” sau „spate” și ritmul cozii.
library;

import 'dart:math';

/// Ce face peștele acum.
enum FishMode { wander, rest, flee, gather, food }

/// Cât de mic pare un pește la adâncimea [z] (perspectivă).
double depthScale(double z) => 1 - 0.42 * z.clamp(0.0, 1.0);

class SwimmingFish {
  SwimmingFish({
    required this.id,
    required this.species,
    required this.length,
    required this.cruise,
    required Point<double> at,
    this.z = 0.35,
    this.liveliness = 1,
    this.yaw = 0,
  }) : pos = at;

  final String id;
  final String species;

  /// Lungimea peștelui lângă geam (înălțimi de acvariu).
  final double length;

  /// Viteza obișnuită (înălțimi de acvariu pe secundă, lângă geam).
  final double cruise;

  /// Cât de tare dă din coadă (din model).
  final double liveliness;

  /// Locul pe ecran.
  Point<double> pos;

  /// Adâncimea: 0 = lângă geam, 1 = în spate.
  double z;

  /// Direcția în planul orizontal (radiani): 0 = spre dreapta, π = spre stânga,
  /// π/2 = spre fundal, −π/2 = spre copil.
  double yaw;

  /// Viteza de rotire a direcției (rad/s) — desenul îndoaie corpul după ea.
  double turnRate = 0;

  /// Viteza de-a lungul direcției (înălțimi/s, ca lângă geam).
  double speed = 0;

  /// Viteza pe verticală (înălțimi/s, ca lângă geam; pozitiv = în jos).
  double climb = 0;

  /// Cât de tare bate coada acum (0 = alunecă, 1 = împinge din toate puterile).
  double thrust = 0.3;

  /// Viteza pe ecran la ultimul pas (pentru desen).
  Point<double> vel = const Point(0, 0);

  Point<double> target = const Point(0, 0);

  /// Adâncimea spre care înoată.
  double targetZ = 0.35;

  FishMode mode = FishMode.wander;

  /// Își alege singur drumul (acvariul). Fals = ținta și modul le dă un joc (de ex.
  /// „Urmărește peștele”); fizica înotului rămâne aceeași.
  bool autopilot = true;

  /// −1 privește spre stânga, +1 spre dreapta, 0 = cu capul spre noi sau spre fundal.
  double get facing => cos(yaw);

  /// Faza bătăii din coadă (radiani) — o citește desenul.
  double phase = 0;

  /// 0…1: cât de bucuros e (a mâncat); face coada să bată mai tare câteva secunde.
  double joy = 0;

  /// 0…1: cât e de umflat (doar peștele-balon, când se sperie); scade încet.
  double puff = 0;

  /// Se umflă când se sperie (ca peștele-balon adevărat).
  bool get puffs => species == 'balon';

  double _timer = 0;
  double _burst = 0;
  Point<double> _offset = const Point(0, 0);

  /// Cât de mic pare la adâncimea lui.
  double get scale => depthScale(z);

  /// Lungimea pe ecran.
  double get apparentLength => length * scale;

  /// Cât de repede merge față de viteza obișnuită (pentru ritmul cozii).
  double get effort => (speed / cruise).clamp(0.0, 3.0);

  /// Înclinarea corpului (radiani, pozitiv = cu capul în jos), după urcare/coborâre.
  double get tilt => atan2(climb, max(speed, 0.02)).clamp(-0.5, 0.5);

  /// Gura (unde mănâncă), pe ecran.
  Point<double> get mouth => Point(pos.x + facing * apparentLength * 0.45, pos.y + sin(tilt) * apparentLength * 0.4);
}

class FoodFlake {
  FoodFlake(this.pos, this.drift, {this.z = 0.3});

  Point<double> pos;
  final double drift;

  /// Adâncimea fulgului.
  final double z;

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

  /// Apa: de sub suprafață până deasupra nisipului (lângă geam; în spate fundul e mai sus).
  static const double top = 0.14, bottom = 0.82;

  /// Cât de adânc e acvariul, în înălțimi (transformă `z` în distanță).
  static const double depth = 0.9;

  /// Cât urcă fundul pe ecran de la geam până la peretele din spate (perspectivă).
  static const double floorRise = 0.07;

  /// Fundul (pe ecran) la adâncimea [z].
  static double bottomAt(double z) => bottom - floorRise * z.clamp(0.0, 1.0);

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
      f.z = 0.15;
      f.climb = f.cruise * 2.2;
      f.speed = f.cruise * 0.6;
      f.mode = FishMode.flee; // coboară repede, apoi se liniștește
      f._timer = 0.9;
    }
    f.target = _randomSpot();
    f.targetZ = _randomZ();
    f._burst = _rng.nextDouble() * 2;
    fish.add(f);
  }

  void remove(String id) => fish.removeWhere((f) => f.id == id);

  /// Atingere scurtă: peștii din apropiere fug de deget (și spre fundal).
  void tap(Point<double> at) {
    for (final f in fish) {
      final d = f.pos - at;
      final dist = _len(d);
      if (dist > fleeRadius) continue;
      final away = dist < 1e-6 ? Point(_rng.nextBool() ? 1.0 : -1.0, 0.0) : d * (1 / dist);
      final strength = 1 - dist / fleeRadius;
      f.mode = FishMode.flee;
      f._timer = 0.8 + strength * 0.6;
      f.target = _clamp(at + away * (fleeRadius * 1.6));
      f.targetZ = min(1.0, f.z + 0.35 + 0.3 * strength);
      if (f.puffs) {
        // Peștele-balon nu fuge repede: se umflă pe loc (și se îndepărtează încet).
        f.puff = 1;
        f.speed = max(f.speed, f.cruise * 0.8);
      } else {
        // Pornirea în „C”: o smucitură scurtă a cozii, apoi țâșnește.
        f.speed = max(f.speed, f.cruise * (2 + 2.5 * strength));
        f.thrust = 1;
        f.turnRate = (_wrap(_desiredYaw(f) - f.yaw) * 9).clamp(-9.0, 9.0);
      }
      f.climb = away.y * f.cruise * 2;
    }
  }

  /// Apăsare lungă: peștii vin încet și se adună în jurul degetului, aproape de geam.
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
        f.targetZ = _randomZ(near: f.z);
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
          z: 0.1 + _rng.nextDouble() * 0.45,
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
      _swim(f, dt);
    }
  }

  void _stepFood(double dt) {
    for (final p in food) {
      p.age += dt;
      final ground = bottomAt(p.z) + 0.06;
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
    // Rămâne umflat ~1,5 s, apoi se dezumflă lin în ~2 s.
    f.puff = max(0, f.puff - dt * (f.puff > 0.75 ? 0.15 : 0.45));
    if (!f.autopilot) return;
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
          f.target = _randomSpot(near: f.pos);
          f.targetZ = _randomZ(near: f.z);
        }
      case FishMode.gather:
        // Se rotesc încet în jurul degetului, aproape de geam.
        final a = _time * 0.5;
        final o = Point(f._offset.x * cos(a) - f._offset.y * sin(a) * 1.7, f._offset.y * cos(a) + f._offset.x * sin(a) * 0.6);
        f.target = _clamp(g! + o);
        f.targetZ = 0.05 + 0.08 * (f._offset.y.abs() * 10 % 1);
      case FishMode.food:
        final flake = _nearestFood(f);
        if (flake == null) {
          f.mode = FishMode.wander;
          f.target = _randomSpot(near: f.pos);
          f.targetZ = _randomZ(near: f.z);
        } else {
          f.target = flake.pos;
          f.targetZ = flake.z;
          if (_len(f.mouth - flake.pos) < max(0.045, f.apparentLength * 0.24) && (f.z - flake.z).abs() < 0.16) {
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
            f.target = _randomSpot(near: f.pos);
            f.targetZ = _randomZ(near: f.z);
          }
        } else if (_len(f.target - f.pos) < 0.06 && (f.targetZ - f.z).abs() < 0.12) {
          // Uneori se oprește puțin, ca un pește adevărat.
          if (_rng.nextDouble() < 0.35) {
            f.mode = FishMode.rest;
            f._timer = 1.5 + _rng.nextDouble() * 2.5;
            f.target = f.pos;
            f.targetZ = f.z;
          } else {
            f.target = _randomSpot(near: f.pos);
            f.targetZ = _randomZ(near: f.z);
          }
        }
    }
  }

  /// Peștii nu se suprapun: se împing ușor (în spațiu, cu tot cu adâncimea).
  void _separate(double dt) {
    for (var i = 0; i < fish.length; i++) {
      for (var j = i + 1; j < fish.length; j++) {
        final a = fish[i], b = fish[j];
        final dx = a.pos.x - b.pos.x, dy = a.pos.y - b.pos.y, dz = (a.z - b.z) * depth;
        final dist = sqrt(dx * dx + dy * dy + dz * dz);
        final minD = (a.length + b.length) * 0.34;
        if (dist >= minD || dist < 1e-6) continue;
        final k = (minD - dist) / dist * 0.9 * dt;
        a.pos = Point(a.pos.x + dx * k, a.pos.y + dy * k);
        b.pos = Point(b.pos.x - dx * k, b.pos.y - dy * k);
        a.z = (a.z + dz / depth * k).clamp(0.0, 1.0);
        b.z = (b.z - dz / depth * k).clamp(0.0, 1.0);
      }
    }
  }

  /// Direcția spre țintă, în planul orizontal (x pe ecran, adâncimea).
  double _desiredYaw(SwimmingFish f) {
    final dx = (f.target.x - f.pos.x) / f.scale, dz = (f.targetZ - f.z) * depth;
    if (dx.abs() < 1e-4 && dz.abs() < 1e-4) return f.yaw;
    return atan2(dz, dx);
  }

  void _swim(SwimmingFish f, double dt) {
    final cruise = f.cruise;
    final dx = (f.target.x - f.pos.x) / f.scale, dy = (f.target.y - f.pos.y) / f.scale;
    final dz = (f.targetZ - f.z) * depth;
    final flat = sqrt(dx * dx + dz * dz);
    final dist = sqrt(flat * flat + dy * dy);

    // 1. Unde vrea să se uite. Când stă sau a ajuns, se întoarce încet din profil
    //    (așa îl vede copilul cel mai bine).
    var want = f.yaw;
    if (flat > 0.03) {
      want = atan2(dz, dx);
    } else if (f.mode == FishMode.rest || f.mode == FishMode.gather || dist < 0.05) {
      want = cos(f.yaw) >= 0 ? 0 : pi;
    }
    final diff = _wrap(want - f.yaw);

    // 2. Rotirea: viteză unghiulară limitată, cu inerție (de aici virajul în „C”).
    final maxTurn = switch (f.mode) {
      FishMode.flee => 7.0,
      FishMode.food => 3.2,
      FishMode.gather => 2.6,
      _ => 2.6,
    };
    final wantRate = (diff * 3.2).clamp(-maxTurn, maxTurn);
    f.turnRate += (wantRate - f.turnRate) * min(1.0, dt * (f.mode == FishMode.flee ? 14 : 5));
    f.yaw = _wrap(f.yaw + f.turnRate * dt);

    // 3. Viteza: impuls din coadă și alunecare. Încetinește în viraje strânse și la sosire.
    var goal = switch (f.mode) {
      FishMode.flee => cruise * 2.6,
      FishMode.food => cruise * 1.7,
      FishMode.gather => cruise * 1.1,
      FishMode.rest => cruise * 0.06,
      FishMode.wander => cruise,
    };
    if (f.mode == FishMode.wander) {
      // Plimbare în reprize: câteva bătăi de coadă, apoi plutește.
      f._burst -= dt;
      if (f._burst < -1.6 - (f.id.hashCode % 7) * 0.15) f._burst = 0.5 + _rng.nextDouble() * 0.6;
      goal *= f._burst > 0 ? 1.35 : 0.75;
    }
    goal *= min(1.0, dist / 0.12) * max(0.3, cos(diff).clamp(0.0, 1.0));
    if (f.puffs && f.puff > 0.3) goal *= 0.35; // umflat, abia se mișcă

    final accel = f.mode == FishMode.flee ? cruise * 9 : cruise * 2.2;
    double push;
    if (goal > f.speed) {
      f.speed = min(goal, f.speed + accel * dt);
      push = 0.45 + 0.55 * ((goal - f.speed) / max(cruise, 1e-6)).clamp(0.0, 1.0);
    } else {
      // Frecarea apei: alunecă și încetinește singur.
      f.speed = max(goal, f.speed - f.speed * dt * (f.mode == FishMode.flee ? 0.9 : 1.3));
      push = 0.12;
    }
    // Ca să țină viteza, coada tot bate puțin (cu atât mai tare cu cât merge mai repede).
    final hold = 0.18 + 0.35 * (f.speed / cruise).clamp(0.0, 2.0) / 2;
    f.thrust += (max(push, hold) - f.thrust) * min(1.0, dt * 4);

    // 4. Sus–jos: urcă și coboară mai încet decât înaintează (nu înoată vertical).
    final wantClimb = (dy * 2.4).clamp(-cruise * 1.4, cruise * 1.4) * (f.mode == FishMode.rest ? 0.4 : 1);
    f.climb += (wantClimb - f.climb) * min(1.0, dt * (f.mode == FishMode.flee ? 3.5 : 1.8));

    // 5. Mișcarea: pe ecran, depărtarea micșorează pașii.
    final s = f.scale;
    final vx = f.speed * cos(f.yaw) * s;
    final vz = f.speed * sin(f.yaw) / depth;
    final vy = f.climb * s;
    var x = f.pos.x + vx * dt, y = f.pos.y + vy * dt;
    f.z = (f.z + vz * dt).clamp(0.0, 1.0);

    // Pereții: peștele e oprit lin, nu trece prin ei.
    final mx = f.apparentLength * 0.5, my = f.apparentLength * 0.25;
    final lox = min(mx, width / 2), hix = max(width - mx, width / 2);
    if ((x < lox && vx < 0) || (x > hix && vx > 0)) f.speed *= 0.6;
    x = x.clamp(lox, hix).toDouble();
    if (!(f.mode == FishMode.flee && y < top)) {
      final lo = top + my, hi = bottomAt(f.z) - my;
      if (y < lo || y > hi) f.climb *= 0.5;
      y = y.clamp(lo, max(lo, hi)).toDouble();
    }
    f.vel = Point((x - f.pos.x) / max(dt, 1e-6), (y - f.pos.y) / max(dt, 1e-6));
    f.pos = Point(x, y);

    // 6. Coada: frecvența crește cu viteza; bucuria o face să bată mai des.
    f.phase += dt * (3.2 + 5.5 * f.effort + 4 * f.joy + 3 * max(0, f.thrust - 0.5)) * f.liveliness;
  }

  FoodFlake? _nearestFood(SwimmingFish f) {
    FoodFlake? best;
    var bd = double.infinity;
    for (final p in food) {
      if (p.pos.y < top) continue; // încă la suprafață
      final d = _len(p.pos - f.pos) + (p.z - f.z).abs() * 0.5;
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  }

  Point<double> _randomSpot({Point<double>? near}) {
    final p = Point(0.1 + _rng.nextDouble() * (width - 0.2), top + 0.06 + _rng.nextDouble() * (bottom - top - 0.14));
    if (near == null) return p;
    // Drumuri nu prea lungi: peștele explorează pe rând părți ale acvariului.
    final d = p - near;
    final l = _len(d);
    return l < 0.6 ? p : _clamp(near + d * (0.6 / l));
  }

  /// O adâncime nouă; de obicei aproape de cea de acum (mai mult de-a latul decât în adânc).
  double _randomZ({double? near}) {
    final z = 0.05 + _rng.nextDouble() * 0.8;
    if (near == null) return z;
    return (near + (z - near) * 0.5).clamp(0.03, 0.9);
  }

  Point<double> _clamp(Point<double> p) =>
      Point(p.x.clamp(0.08, width - 0.08).toDouble(), p.y.clamp(top + 0.05, bottom - 0.05).toDouble());
}

double _len(Point<double> p) => sqrt(p.x * p.x + p.y * p.y);

/// Unghiul adus în (−π, π].
double _wrap(double a) {
  var x = (a + pi) % (2 * pi);
  if (x < 0) x += 2 * pi;
  return x - pi;
}
