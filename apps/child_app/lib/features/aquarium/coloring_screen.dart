import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../shared/sfx.dart';
import '../../shared/top_bar.dart';
import '../../shared/ui/candy.dart';
import '../../shared/voice.dart';
import 'aquarium_store.dart';
import 'fish_art.dart';

/// Colorez un pește (`/acvariu/coloreaza`): copilul alege un model și îl colorează pe ecran
/// (carioca sau găleata), apoi peștele lui intră în acvariu. Varianta pe hârtie (fișa
/// printată + camera) folosește același model și același desen.
class ColoringScreen extends ConsumerStatefulWidget {
  const ColoringScreen({super.key});

  @override
  ConsumerState<ColoringScreen> createState() => _ColoringScreenState();
}

enum _Tool { brush, fill }

const _palette = [
  Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835), Color(0xFF8BC34A), //
  Color(0xFF2E9D4F), Color(0xFF26C6DA), Color(0xFF1E5BD8), Color(0xFF8E24AA),
  Color(0xFFF06292), Color(0xFF8D5524), Color(0xFF2B2B2B), Color(0xFFFFFFFF),
];
const _sizes = [14.0, 30.0, 58.0];

class _ColoringScreenState extends ConsumerState<ColoringScreen> {
  FishSpecies? _species;
  ui.Image? _paint;
  Uint8List? _walls;
  final _undo = ListQueue<ui.Image>();
  final _stroke = <Offset>[];
  final _pending = <(List<Offset>, Color, double)>[];
  Color _color = _palette[1];
  double _size = _sizes[1];
  _Tool _tool = _Tool.brush;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(voiceProvider).say(['Alege un pește.']));
  }

  @override
  void dispose() {
    _paint?.dispose();
    for (final i in _undo) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _start(FishSpecies s) async {
    ref.read(sfxProvider).play(Sfx.tap);
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(Offset.zero & fishBox, Paint()..color = Colors.white);
    final blank = await rec.endRecording().toImage(fishBox.width.toInt(), fishBox.height.toInt());
    // Liniile fișei sunt „pereți” pentru găleată.
    final rec2 = ui.PictureRecorder();
    paintLineArt(Canvas(rec2), s);
    final lines = await rec2.endRecording().toImage(fishBox.width.toInt(), fishBox.height.toInt());
    final px = (await lines.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
    lines.dispose();
    final walls = Uint8List(px.length ~/ 4);
    for (var i = 0; i < walls.length; i++) {
      walls[i] = px[i * 4 + 3] > 70 ? 1 : 0;
    }
    if (!mounted) return;
    setState(() {
      _species = s;
      _paint = blank;
      _walls = walls;
    });
    ref.read(voiceProvider).say(['Colorează peștele cum vrei tu.']);
  }

  void _push(ui.Image next) {
    final old = _paint;
    if (old != null) {
      _undo.addLast(old);
      if (_undo.length > 15) _undo.removeFirst().dispose();
    }
    _paint = next;
  }

  Future<void> _commitStroke() async {
    if (_stroke.isEmpty || _paint == null) return;
    final stroke = (List.of(_stroke), _color, _size);
    _stroke.clear();
    _pending.add(stroke);
    setState(() {});
    final base = _paint!;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImage(base, Offset.zero, Paint());
    _drawStroke(c, stroke.$1, stroke.$2, stroke.$3);
    final next = await rec.endRecording().toImage(base.width, base.height);
    if (!mounted) return;
    setState(() {
      _push(next);
      _pending.remove(stroke);
    });
  }

  Future<void> _fill(Offset at) async {
    final base = _paint, walls = _walls;
    if (base == null || walls == null || _busy) return;
    _busy = true;
    final w = base.width, h = base.height;
    final x0 = at.dx.round(), y0 = at.dy.round();
    if (x0 < 0 || y0 < 0 || x0 >= w || y0 >= h || walls[y0 * w + x0] == 1) {
      _busy = false;
      return;
    }
    final px = (await base.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
    floodFill(px, walls, w, h, x0, y0, _color);
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, w, h, ui.PixelFormat.rgba8888, done.complete);
    final next = await done.future;
    _busy = false;
    if (!mounted) return;
    ref.read(sfxProvider).play(Sfx.tap);
    setState(() => _push(next));
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _paint?.dispose();
      _paint = _undo.removeLast();
    });
  }

  Future<void> _done() async {
    final s = _species, paint = _paint;
    if (s == null || paint == null || _busy) return;
    setState(() => _busy = true);
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImage(paint, Offset.zero, Paint());
    paintLineArt(c, s);
    final drawing = await rec.endRecording().toImage(paint.width, paint.height);
    final id = await ref.read(aquariumProvider.notifier).add(s, drawing);
    drawing.dispose();
    ref.read(sfxProvider).play(Sfx.correct);
    if (mounted) context.go('/acvariu?nou=$id');
  }

  @override
  Widget build(BuildContext context) {
    final s = _species;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFE9EE), Color(0xFF8CCFDD)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                title: s == null ? 'Alege un pește' : 'Colorez ${s.name}',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BarButton(
                      icon: Icons.water_rounded,
                      color: const Color(0xFF3FA7C4),
                      label: 'Acvariul',
                      onTap: () => context.go('/acvariu'),
                    ),
                    if (s != null) ...[
                      const SizedBox(width: 10),
                      BarButton(
                        key: const ValueKey('undo'),
                        icon: Icons.undo_rounded,
                        color: const Color(0xFF8A9BB0),
                        label: 'Înapoi',
                        onTap: _undo.isEmpty ? null : _undoLast,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: s == null ? _Picker(onPick: _start) : _editor(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editor(BuildContext context) {
    final layout = AppLayout.of(context);
    final gap = layout.compact ? 8.0 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(gap, 0, gap, gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CandyPanel(
              padding: EdgeInsets.all(gap),
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, c) {
                  final scale = math.min(c.maxWidth / fishBox.width, c.maxHeight / fishBox.height);
                  final size = fishBox * scale;
                  Offset toBox(Offset p) => p / scale;
                  return Center(
                    child: SizedBox.fromSize(
                      size: size,
                      child: Listener(
                        key: const ValueKey('sheet'),
                        onPointerDown: (e) {
                          if (_tool == _Tool.fill) {
                            _fill(toBox(e.localPosition));
                          } else {
                            setState(() => _stroke.add(toBox(e.localPosition)));
                          }
                        },
                        onPointerMove: (e) {
                          if (_tool == _Tool.brush && _stroke.isNotEmpty) {
                            setState(() => _stroke.add(toBox(e.localPosition)));
                          }
                        },
                        onPointerUp: (_) => _commitStroke(),
                        onPointerCancel: (_) => _commitStroke(),
                        child: CustomPaint(
                          painter: _SheetPainter(
                            species: _species!,
                            layer: _paint,
                            pending: _pending,
                            stroke: (_stroke, _color, _size),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(width: gap),
          SizedBox(width: layout.compact ? 200 : 260, child: _tools(context, gap)),
        ],
      ),
    );
  }

  Widget _tools(BuildContext context, double gap) => LayoutBuilder(
    builder: (context, c) {
      // Patru rânduri de culori + rândul de unelte + butonul „Gata”.
      final swatch = math.min(64.0, math.min((c.maxWidth - 2 * 8) / 3, (c.maxHeight - 150) / 4 - 8));
      final tool = math.min(52.0, (c.maxWidth - 3 * 6) / 4);
      return Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final (i, col) in _palette.indexed)
                _Swatch(
                  key: ValueKey('color-$i'),
                  color: col,
                  size: swatch,
                  selected: col == _color,
                  onTap: () => setState(() => _color = col),
                ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final s in _sizes)
                _ToolButton(
                  size: tool,
                  selected: _tool == _Tool.brush && _size == s,
                  label: 'Carioca',
                  onTap: () => setState(() {
                    _tool = _Tool.brush;
                    _size = s;
                  }),
                  child: Container(
                    width: (8 + s * 0.45) * tool / 52,
                    height: (8 + s * 0.45) * tool / 52,
                    decoration: BoxDecoration(
                      color: _color == Colors.white ? Tokens.line : _color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              _ToolButton(
                key: const ValueKey('fill'),
                size: tool,
                selected: _tool == _Tool.fill,
                label: 'Găleata',
                onTap: () => setState(() => _tool = _Tool.fill),
                child: Icon(
                  Icons.format_color_fill_rounded,
                  color: _color == Colors.white ? Tokens.inkSoft : _color,
                  size: tool * 0.58,
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          CandyButton(
            key: const ValueKey('done'),
            label: 'Gata!',
            icon: Icons.check_rounded,
            color: Tokens.good,
            minWidth: 180,
            onTap: _busy ? null : _done,
          ),
        ],
      );
    },
  );
}

void _drawStroke(Canvas c, List<Offset> pts, Color color, double width) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  if (pts.length == 1) {
    c.drawCircle(pts.first, width / 2, paint..style = PaintingStyle.fill);
    return;
  }
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final m = (pts[i] + pts[i + 1]) / 2;
    p.quadraticBezierTo(pts[i].dx, pts[i].dy, m.dx, m.dy);
  }
  p.lineTo(pts.last.dx, pts.last.dy);
  c.drawPath(p, paint);
}

/// Umple zona în care s-a atins, până la liniile fișei (sau până la altă culoare).
/// Culoarea intră și puțin sub linii, ca să nu rămână margini albe.
@visibleForTesting
void floodFill(Uint8List px, Uint8List walls, int w, int h, int x0, int y0, Color color) {
  final seed = (y0 * w + x0) * 4;
  final sr = px[seed], sg = px[seed + 1], sb = px[seed + 2];
  final nr = (color.r * 255).round(), ng = (color.g * 255).round(), nb = (color.b * 255).round();
  if ((sr - nr).abs() + (sg - ng).abs() + (sb - nb).abs() < 6) return;
  bool same(int i) =>
      walls[i] == 0 && (px[i * 4] - sr).abs() + (px[i * 4 + 1] - sg).abs() + (px[i * 4 + 2] - sb).abs() < 60;
  final mask = Uint8List(w * h);
  final stack = <int>[y0 * w + x0];
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final y = i ~/ w;
    var l = i, r = i;
    while (l % w > 0 && mask[l - 1] == 0 && same(l - 1)) {
      l--;
    }
    while (r % w < w - 1 && mask[r + 1] == 0 && same(r + 1)) {
      r++;
    }
    for (var k = l; k <= r; k++) {
      mask[k] = 1;
      if (y > 0 && mask[k - w] == 0 && same(k - w)) stack.add(k - w);
      if (y < h - 1 && mask[k + w] == 0 && same(k + w)) stack.add(k + w);
    }
  }
  // Două treceri de dilatare, doar peste linii.
  for (var pass = 0; pass < 3; pass++) {
    final grow = <int>[];
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == 1 || walls[i] == 0) continue;
      final x = i % w;
      if ((x > 0 && mask[i - 1] == 1) ||
          (x < w - 1 && mask[i + 1] == 1) ||
          (i >= w && mask[i - w] == 1) ||
          (i + w < mask.length && mask[i + w] == 1)) {
        grow.add(i);
      }
    }
    for (final i in grow) {
      mask[i] = 1;
    }
  }
  for (var i = 0; i < mask.length; i++) {
    if (mask[i] == 0) continue;
    px[i * 4] = nr;
    px[i * 4 + 1] = ng;
    px[i * 4 + 2] = nb;
    px[i * 4 + 3] = 255;
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter({required this.species, required this.layer, required this.pending, required this.stroke});

  final FishSpecies species;
  final ui.Image? layer;
  final List<(List<Offset>, Color, double)> pending;
  final (List<Offset>, Color, double) stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / fishBox.width);
    final img = layer;
    if (img != null) {
      canvas.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
    }
    for (final (pts, c, w) in pending) {
      _drawStroke(canvas, pts, c, w);
    }
    if (stroke.$1.isNotEmpty) _drawStroke(canvas, stroke.$1, stroke.$2, stroke.$3);
    paintLineArt(canvas, species);
  }

  @override
  bool shouldRepaint(_SheetPainter old) => true;
}

class _Swatch extends StatelessWidget {
  const _Swatch({super.key, required this.color, required this.size, required this.selected, required this.onTap});

  final Color color;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: color == Colors.white ? 'Alb (gumă)' : 'Culoare',
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.12 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? Tokens.ink : Colors.white, width: selected ? 4 : 3),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: color == Colors.white ? const Icon(Icons.auto_fix_normal_rounded, color: Tokens.inkSoft) : null,
        ),
      ),
    ),
  );
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.size,
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final double size;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? Tokens.ink : Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: child,
      ),
    ),
  );
}

/// Alegerea modelului: fișele, ca niște cartonașe.
class _Picker extends StatelessWidget {
  const _Picker({required this.onPick});

  final void Function(FishSpecies) onPick;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    final gap = compact ? 10.0 : 18.0;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, box) {
          // Cartonașele cât mai mari, toate pe ecran: alegem câte pe rând.
          var best = (0.0, 1);
          for (var cols = 2; cols <= fishSpecies.length; cols++) {
            final rows = (fishSpecies.length / cols).ceil();
            final w = math.min(
              (box.maxWidth - gap * (cols - 1)) / cols,
              ((box.maxHeight - gap * (rows - 1)) / rows) * 1.4,
            );
            if (w > best.$1) best = (w, cols);
          }
          final w = math.min(best.$1, 260.0), h = w / 1.4;
          return Center(
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              alignment: WrapAlignment.center,
              children: [
                for (final s in fishSpecies)
                  CandyPressable(
                    key: ValueKey('species-${s.id}'),
                    color: Colors.white,
                    radius: 22,
                    lip: 5,
                    width: w,
                    height: h,
                    semanticLabel: s.name,
                    onTap: () => onPick(s),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Expanded(
                            child: CustomPaint(painter: _ThumbPainter(s), size: Size.infinite),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              s.name,
                              style: Theme.of(context).textTheme.titleMedium!.copyWith(color: Tokens.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.species);

  final FishSpecies species;

  @override
  void paint(Canvas canvas, Size size) {
    final k = math.min(size.width / fishBox.width, size.height / fishBox.height);
    canvas.translate((size.width - fishBox.width * k) / 2, (size.height - fishBox.height * k) / 2);
    canvas.scale(k);
    paintLineArt(canvas, species, color: Tokens.ink);
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.species != species;
}
