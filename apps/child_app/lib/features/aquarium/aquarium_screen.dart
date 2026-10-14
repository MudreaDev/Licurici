import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:printing/printing.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../shared/mascot.dart';
import '../../shared/motion.dart';
import '../../shared/sfx.dart';
import '../../shared/stimulus_art.dart';
import '../../shared/top_bar.dart';
import '../../shared/ui/candy.dart';
import '../../shared/voice.dart';
import '../parent/parent_gate.dart';
import '../settings/settings.dart';
import 'aquarium_dock.dart';
import 'aquarium_store.dart';
import 'paper_scan_flow.dart';
import 'paper_sheet.dart';
import 'reef_life.dart';
import 'reef_night.dart';
import 'reef_scene.dart';
import 'tank_painter.dart';

/// Acvariul copilului (`/acvariu`, README §2): peștii colorați de el înoată liber.
/// Acvariul nu se mișcă; copilul doar se joacă cu peștii:
/// - **atinge** apa → peștii din apropiere fug de deget;
/// - **ține apăsat** → peștii vin încet și se adună în jurul degetului;
/// - **Mâncare** → fulgi care cad; peștii vin și îi mănâncă.
class AquariumScreen extends ConsumerStatefulWidget {
  const AquariumScreen({super.key, this.newFishId});

  /// Peștele abia colorat: intră în apă de sus, cu bule.
  final String? newFishId;

  @override
  ConsumerState<AquariumScreen> createState() => _AquariumScreenState();
}

class _AquariumScreenState extends ConsumerState<AquariumScreen> with SingleTickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  final _ambient = ValueNotifier<double>(0);
  final _gather = ValueNotifier<math.Point<double>?>(null);

  /// Noaptea (0 = zi, 1 = noapte), trecere lină; degetul ținut e lanterna (pixeli).
  final _night = ValueNotifier<double>(0);
  final _finger = ValueNotifier<Offset?>(null);
  bool _nightOn = false;
  final _fx = <TankFx>[];
  final _chest = ReefChest();
  Size _size = Size.zero;
  late final Ticker _ticker = createTicker(_tick);
  Aquarium? _sim;
  var _owned = <String, OwnedFish>{};
  Duration _last = Duration.zero;
  double _height = 1;
  bool _greeted = false;
  SoundEffects? _sfx;

  /// Indiciile pentru gesturi (o dată pe vizită): după câteva secunde fără nicio atingere,
  /// o mânuță arată ce se poate face.
  double _wall = 0, _idleSince = 0;
  _Hint? _hint;
  double _hintAt = 0;
  bool _usedGather = false, _usedChest = false, _hintedGather = false, _hintedChest = false;
  int _broke = 0, _spent = 0;
  bool _scanning = false;

  /// Peștele adus de pe hârtie chiar acum (intră de sus, ca cel colorat pe ecran).
  String? _diveId;

  /// Peștele chemat din raftul „Peștii mei” (bula lui e luminată câteva secunde).
  String? _called;
  Timer? _calledOff;

  @override
  void initState() {
    super.initState();
    _ticker.start();
    unawaited(Caustics.load());
    // Apa, foarte încet, cât stă copilul în acvariu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final sfx = ref.read(sfxProvider);
      _sfx = sfx;
      sfx.ambient('ocean_loop');
    });
  }

  @override
  void dispose() {
    _calledOff?.cancel();
    _sfx?.ambient(null);
    _ticker.dispose();
    _time.dispose();
    _ambient.dispose();
    _gather.dispose();
    _night.dispose();
    _finger.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final raw = (elapsed - _last).inMicroseconds / 1e6;
    final dt = math.min(0.05, raw);
    _last = elapsed;
    // Timpul „de ceas” (pentru indicii): nu se taie la 50 ms ca pasul simulării.
    _wall += math.min(raw, 1.0);
    final dusk = (_nightOn ? 1.0 : 0.0) - _night.value;
    if (dusk.abs() > 0.001) _night.value += dusk * math.min(1.0, math.min(raw, 0.1) * 2.5);
    final sim = _sim;
    if (sim == null) return;
    final g = _gather.value;
    if (g != null) sim.gather(g);
    sim.step(dt);
    for (final e in sim.drainEvents()) {
      switch (e) {
        case FishAte():
          _fx.add(TankFx(e.at, TankFxKind.ate, _time.value));
          ref.read(sfxProvider).play(Sfx.bubble);
        case FishPecked():
          _fx.add(TankFx(e.at, TankFxKind.sand, _time.value));
        case FishTickled():
          _fx.add(TankFx(e.at, TankFxKind.joy, _time.value));
          ref.read(sfxProvider).play(Sfx.bubble);
      }
    }
    _fx.removeWhere((e) => _time.value - e.born > 1.6);
    _time.value += dt;
    _hints();
    // În modul calm fundalul stă; peștii înoată mai departe.
    if (MotionPolicy.of(context, ref).ambient) _ambient.value += dt;
  }

  /// Ține simularea la zi cu peștii salvați (unul nou intră de sus).
  void _sync(List<OwnedFish> fish, double width) {
    final sim = _sim ??= Aquarium(width: width, seed: 42);
    sim.width = width;
    final ids = {for (final f in fish) f.entry.id};
    for (final f in List.of(sim.fish)) {
      if (!ids.contains(f.id)) sim.remove(f.id);
    }
    final rnd = math.Random(sim.fish.length + 7);
    for (final o in fish) {
      if (sim.fish.any((f) => f.id == o.entry.id)) continue;
      final dive = o.entry.id == widget.newFishId || o.entry.id == _diveId;
      sim.add(
        SwimmingFish(
          id: o.entry.id,
          species: o.species.id,
          length: 0.28 + rnd.nextDouble() * 0.05 - (o.species.id == 'balon' ? 0.03 : 0),
          cruise: 0.1 + rnd.nextDouble() * 0.04,
          liveliness: o.species.swim,
          at: math.Point(0.2 + rnd.nextDouble() * (width - 0.4), Aquarium.top + 0.1 + rnd.nextDouble() * 0.45),
          z: 0.1 + rnd.nextDouble() * 0.6,
          yaw: rnd.nextBool() ? 0 : math.pi,
        ),
        diveIn: dive,
      );
      if (dive) _fx.add(TankFx(math.Point(sim.fish.last.pos.x, Aquarium.top), TankFxKind.ate, _time.value));
    }
    _owned = {for (final f in fish) f.entry.id: f};
  }

  math.Point<double> _toTank(Offset local) => math.Point(local.dx / _height, local.dy / _height);

  /// Mâncarea costă o stea (stelele se câștigă în jocuri). Fără stele, Licurici spune de
  /// unde se iau — fără reproș.
  void _feed() {
    final sim = _sim;
    if (sim == null || sim.food.length > 24) return;
    if (!ref.read(settingsProvider.notifier).spendStars(foodPrice)) {
      ref.read(voiceProvider).say(['Joacă un joc și câștigi stele pentru mâncare.']);
      setState(() => _broke++);
      return;
    }
    final rnd = math.Random();
    sim.feed(sim.width * (0.25 + rnd.nextDouble() * 0.5));
    ref.read(sfxProvider).play(Sfx.tap);
    setState(() => _spent++); // pușculița sare puțin: steaua a plătit mâncarea
  }

  /// Fișele A4 de colorat — pentru părinte (printarea cere poarta pentru adulți).
  Future<void> _printSheets() async {
    if (!await askParentGate(context) || !mounted) return;
    await Printing.layoutPdf(name: 'licurici-pesti-de-colorat', onLayout: (_) => buildSheetsPdf(fishSpecies));
  }

  /// Peștele colorat pe hârtie: o poză cu fișa, apoi peștele intră în acvariu.
  Future<void> _scanPaper() async {
    final photo = await ref.read(photoSourceProvider)();
    if (photo == null || !mounted) return;
    setState(() => _scanning = true);
    ref.read(voiceProvider).say(['Îl caut pe peștele tău.']);
    final (found, problem) = await scanPhoto(photo);
    if (!mounted) return;
    if (found == null) {
      setState(() => _scanning = false);
      final retry = await _showScanProblem(problem ?? ScanProblem.noSheet);
      if (retry && mounted) unawaited(_scanPaper());
      return;
    }
    final id = 'p${DateTime.now().microsecondsSinceEpoch}';
    _diveId = id;
    await ref.read(aquariumProvider.notifier).add(found.species, found.drawing, id: id);
    found.drawing.dispose();
    if (!mounted) return;
    setState(() => _scanning = false);
    ref.read(sfxProvider).play(Sfx.correct);
    ref.read(voiceProvider).say(['Uite! Peștele tău înoată în acvariu!']);
  }

  /// Ce n-a mers, spus blând de Licurici. Întoarce true dacă vrea să mai încerce.
  Future<bool> _showScanProblem(ScanProblem problem) async {
    ref.read(voiceProvider).say([
      switch (problem) {
        ScanProblem.noSheet => 'Nu văd fișa. Fă poza de sus, cu toată foaia.',
        ScanProblem.unknownFish => 'Încearcă o poză mai clară.',
      },
    ]);
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: CandyPanel(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Mascot(size: 110, mood: MascotMood.encourage),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      problem == ScanProblem.noSheet
                          ? 'Nu văd fișa.\nFă poza de sus, să se vadă toată foaia și cele patru pătrate negre.'
                          : 'Văd fișa, dar nu știu ce pește e.\nÎncearcă o poză mai clară, cu mai multă lumină.',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Tokens.ink),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        CandyButton(
                          key: const ValueKey('scan-retry'),
                          label: 'Mai încerc',
                          icon: Icons.photo_camera_rounded,
                          color: Tokens.good,
                          minWidth: 160,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                        CandyButton(
                          key: const ValueKey('scan-close'),
                          label: 'Închide',
                          icon: Icons.close_rounded,
                          color: const Color(0xFF8A9BB0),
                          minWidth: 140,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return retry ?? false;
  }

  /// Arată (sau ascunde) indiciul potrivit.
  void _hints() {
    if (_hint != null) {
      if (_wall - _hintAt > 4.5) setState(() => _hint = null);
      return;
    }
    final idle = _wall - _idleSince;
    if (!_usedGather && !_hintedGather && idle > 7) {
      _hintedGather = true;
      _showHint(_Hint.gather, 'Ține degetul pe apă: peștii vin la tine.');
    } else if (!_usedChest && !_hintedChest && _hintedGather && idle > 9) {
      _hintedChest = true;
      _showHint(_Hint.chest, 'Atinge cufărul cu comori!');
    }
  }

  void _showHint(_Hint h, String says) {
    setState(() {
      _hint = h;
      _hintAt = _wall;
    });
    ref.read(voiceProvider).say([says]);
  }

  /// Copilul și-a ales peștele din raft: vine la geam și se învârte bucuros.
  void _callFish(String id) {
    _touched();
    if (_sim?.call(id) != true) return;
    ref.read(sfxProvider).play(Sfx.bubble);
    ref.read(voiceProvider).say(['Uite-l pe al tău!']);
    setState(() => _called = id);
    _calledOff?.cancel();
    _calledOff = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _called = null);
    });
  }

  /// Zi ↔ noapte. Noaptea, degetul ținut pe apă e o lanternă: peștii vin la lumină.
  void _toggleNight() {
    setState(() => _nightOn = !_nightOn);
    ref.read(sfxProvider).play(Sfx.tap);
    ref.read(voiceProvider).say([_nightOn ? 'Noapte bună, peștișori!' : 'Bună dimineața, peștișori!']);
  }

  /// Copilul a atins ecranul: indiciul pleacă, numărătoarea reîncepe.
  void _touched() {
    _idleSince = _wall;
    if (_hint != null) setState(() => _hint = null);
  }

  void _greet(List<OwnedFish> fish) {
    if (_greeted) return;
    _greeted = true;
    final voice = ref.read(voiceProvider);
    if (widget.newFishId != null) {
      voice.say(['Uite! Peștele tău înoată în acvariu!']);
    } else if (fish.length == 1 && fish.first.entry.gift) {
      voice.say(['Ți-am adus un pește!', 'Colorează și tu unul.']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fish = ref.watch(aquariumProvider);
    final layout = AppLayout.of(context);
    final list = fish.value;
    if (list != null) WidgetsBinding.instance.addPostFrameCallback((_) => _greet(list));
    final gift = list != null && list.length == 1 && list.first.entry.gift;
    final stars = ref.watch(settingsProvider.select((s) => s.stars));

    return Scaffold(
      backgroundColor: const Color(0xFF1C6F9C),
      body: LayoutBuilder(
        builder: (context, c) {
          _height = c.maxHeight;
          _size = c.biggest;
          if (list != null) _sync(list, c.maxWidth / c.maxHeight);
          return Stack(
            fit: StackFit.expand,
            children: [
              ReefScene(
                ambient: _ambient,
                chest: _chest,
                child: _sim == null
                    ? const SizedBox.expand()
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          _touched();
                          if (ReefChest.hitRect(_size).contains(d.localPosition)) {
                            _usedChest = true;
                            _chest.open(_ambient.value);
                            ref.read(sfxProvider).play(Sfx.bubble);
                          }
                          final p = _toTank(d.localPosition);
                          _sim!.tap(p);
                          _fx.add(TankFx(p, TankFxKind.tap, _time.value));
                        },
                        onLongPressStart: (d) {
                          _touched();
                          _usedGather = true;
                          _gather.value = _toTank(d.localPosition);
                          _finger.value = d.localPosition;
                        },
                        onLongPressMoveUpdate: (d) {
                          _gather.value = _toTank(d.localPosition);
                          _finger.value = d.localPosition;
                        },
                        onLongPressEnd: (_) {
                          _gather.value = null;
                          _finger.value = null;
                          _sim!.release();
                        },
                        onLongPressCancel: () {
                          _gather.value = null;
                          _finger.value = null;
                          _sim?.release();
                        },
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: TankPainter(aquarium: _sim!, fish: _owned, time: _time, fx: _fx, gather: _gather),
                            size: Size.infinite,
                          ),
                        ),
                      ),
              ),
              IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: ReefNightPainter(time: _ambient, night: _night, finger: _finger, chest: _chest),
                  ),
                ),
              ),
              if (_hint case final h?)
                _HandHint(
                  key: ValueKey(h),
                  at: h == _Hint.chest ? ReefChest.hitRect(_size).center : Offset(_size.width * 0.5, _size.height * 0.45),
                  hold: h == _Hint.gather,
                ),
              SafeArea(
                child: Column(
                  children: [
                    TopBar(
                      title: 'Acvariul meu',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SkyButton(night: _nightOn, onTap: _toggleNight),
                          const SizedBox(width: 10),
                          BarButton(
                            key: const ValueKey('print-sheets'),
                            icon: Icons.print_rounded,
                            color: const Color(0xFF8A9BB0),
                            label: 'Fișe de printat (pentru părinți)',
                            onTap: _printSheets,
                          ),
                          const SizedBox(width: 10),
                          _StarPurse(stars: stars, shake: _broke, spent: _spent),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, layout.compact ? 10 : 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: gift
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.bottomLeft,
                                    child: _GiftHint(compact: layout.compact),
                                  )
                                : Align(
                                    alignment: Alignment.bottomLeft,
                                    child: list == null || list.isEmpty
                                        ? const SizedBox.shrink()
                                        : FishShelf(fish: list, picked: _called, onPick: _callFish),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          DockButton(
                            key: const ValueKey('feed'),
                            image: 'sprites/food_jar',
                            fallback: Icons.grain_rounded,
                            label: 'Mâncare',
                            color: const Color(0xFFF2A33A),
                            badge: const StarPrice(foodPrice),
                            onTap: _feed,
                          ),
                          SizedBox(width: layout.compact ? 10 : 16),
                          DockButton(
                            key: const ValueKey('color-fish'),
                            image: 'sprites/brush_fish',
                            fallback: Icons.brush_rounded,
                            label: 'Colorez',
                            color: Tokens.primary,
                            onTap: () => context.go('/acvariu/coloreaza'),
                          ),
                          SizedBox(width: layout.compact ? 10 : 16),
                          DockButton(
                            key: const ValueKey('scan-paper'),
                            image: 'sprites/camera_sheet',
                            fallback: Icons.photo_camera_rounded,
                            label: 'De pe hârtie',
                            color: const Color(0xFF7FC0A3),
                            onTap: _scanning ? null : _scanPaper,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (fish.isLoading) const Center(child: CircularProgressIndicator(color: Colors.white)),
              if (_scanning) const _Searching(),
            ],
          );
        },
      ),
    );
  }
}

enum _Hint { gather, chest }

/// Mânuța care arată un gest: apasă și ține (cu un cerc care crește) sau atinge scurt.
class _HandHint extends StatefulWidget {
  const _HandHint({super.key, required this.at, required this.hold});

  final Offset at;
  final bool hold;

  @override
  State<_HandHint> createState() => _HandHintState();
}

class _HandHintState extends State<_HandHint> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final k = _c.value;
        // Coboară, apasă (ține sau atinge), se ridică.
        final press = widget.hold ? (k < 0.2 ? k / 0.2 : (k < 0.8 ? 1.0 : (1 - k) / 0.2)) : math.sin(k * math.pi).clamp(0.0, 1.0);
        final ring = widget.hold ? ((k - 0.2) / 0.6).clamp(0.0, 1.0) : 0.0;
        return Stack(
          children: [
            if (widget.hold)
              Positioned(
                left: widget.at.dx - 60,
                top: widget.at.dy - 60,
                width: 120,
                height: 120,
                child: Center(
                  child: Container(
                    width: 30 + 90 * ring,
                    height: 30 + 90 * ring,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8 * (1 - ring * 0.6)), width: 4),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: widget.at.dx - 30,
              top: widget.at.dy - 28 + 18 * (1 - press),
              child: Transform.scale(scale: 1 - 0.1 * press, child: const StimulusArt('👆', size: 76)),
            ),
          ],
        );
      },
    ),
  );
}

/// Licurici, la prima vizită: „Ți-am adus un pește!”.
class _GiftHint extends StatelessWidget {
  const _GiftHint({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Mascot(size: compact ? 80 : 120, mood: MascotMood.wave),
      Padding(
        padding: EdgeInsets.only(bottom: compact ? 40 : 70),
        child: SpeechBubble(
          tail: BubbleTail.left,
          child: Text(
            'Ți-am adus un pește!\nColorează și tu unul.',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Tokens.ink),
          ),
        ),
      ),
    ],
  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
}

/// Câte stele de mâncare costă o mână de fulgi.
const foodPrice = 1;

/// Pușculița: stelele copilului. Clatină ușor când nu ajung pentru mâncare.
class _StarPurse extends StatelessWidget {
  const _StarPurse({required this.stars, required this.shake, required this.spent});

  final int stars;
  final int shake;

  /// Câte mâini de mâncare s-au plătit (fiecare face pușculița să sară o dată).
  final int spent;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return CandyPanel(
      key: const ValueKey('stars'),
      radius: 999,
      lip: 4,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18, vertical: compact ? 4 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: const Color(0xFFF2C14E), size: compact ? 30 : 40),
          const SizedBox(width: 6),
          Text(
            '$stars',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Tokens.ink, fontSize: compact ? 22 : 28),
          ),
        ],
      ),
    )
        .animate(key: ValueKey('spent-$spent'), target: spent == 0 ? 0 : 1)
        .scaleXY(begin: 1, end: 1.15, duration: 140.ms, curve: Curves.easeOut)
        .then()
        .scaleXY(begin: 1.15, end: 1, duration: 260.ms, curve: Curves.easeOutBack)
        .animate(key: ValueKey(shake), target: shake == 0 ? 0 : 1)
        .shake(hz: 4, rotation: 0.04, duration: 450.ms);
  }
}

/// În timp ce caută peștele în poză: Licurici se gândește.
class _Searching extends StatelessWidget {
  const _Searching();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x66062A40),
    child: Center(
      child: CandyPanel(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(size: 100, mood: MascotMood.think),
            const SizedBox(width: 12),
            Text('Îl caut pe peștele tău…', style: Theme.of(context).textTheme.titleLarge!.copyWith(color: Tokens.ink)),
          ],
        ),
      ),
    ),
  );
}
