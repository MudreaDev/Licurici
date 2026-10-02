import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../motion.dart';
import '../sfx.dart';

/// Kitul vizual al aplicației copilului: suprafețe „de jucărie” cu o buză 3D jos, lumină
/// de sus și colțuri mari (README §14). Copilul vede imediat ce se poate apăsa: tot ce are buză
/// se apasă și „coboară” la atingere.

/// Culoarea mai închisă a aceleiași nuanțe (buza de jos, contururi).
Color shade(Color c, [double amount = 0.16]) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
      .toColor();
}

/// Culoarea mai deschisă (lumina de sus).
Color tint(Color c, [double amount = 0.1]) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}

/// Decorul unei suprafețe „candy”: degradeu de sus în jos, buză plină (fără blur) și o umbră
/// moale dedesubt. [lip] = 0 când e apăsată.
BoxDecoration candyDecoration({
  required Color color,
  required double radius,
  double lip = 6,
  Color? lipColor,
  bool shadow = true,
  Color? border,
  double borderWidth = 0,
}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [tint(color, 0.06), color],
  ),
  borderRadius: BorderRadius.circular(radius),
  border: border == null ? null : Border.all(color: border, width: borderWidth),
  boxShadow: [
    if (lip > 0)
      BoxShadow(color: lipColor ?? shade(color), offset: Offset(0, lip)),
    if (shadow)
      BoxShadow(
        color: const Color(0x2A2F3D3B),
        blurRadius: 18,
        offset: Offset(0, lip + 6),
      ),
  ],
);

/// O suprafață apăsabilă cu buză 3D: la atingere coboară cu înălțimea buzei.
class CandyPressable extends ConsumerStatefulWidget {
  const CandyPressable({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.radius = Tokens.radius,
    this.lip = 6,
    this.lipColor,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    this.border,
    this.borderWidth = 0,
    this.width,
    this.height,
    this.sound = true,
  });

  /// „Pop” scurt la atingere (tăcut în modul calm).
  final bool sound;
  final Color color;
  final Color? lipColor;
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final double lip;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final Color? border;
  final double borderWidth;
  final double? width;
  final double? height;

  @override
  ConsumerState<CandyPressable> createState() => _CandyPressableState();
}

class _CandyPressableState extends ConsumerState<CandyPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final motion = MotionPolicy.of(context, ref);
    final enabled = widget.onTap != null;
    final pressed = _down && motion.feedback;
    final lip = pressed ? 1.0 : widget.lip;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapCancel: () => _set(false),
          onTapUp: (_) => _set(false),
          onTap: widget.onTap == null
              ? null
              : () {
                  if (widget.sound) ref.read(sfxProvider).play(Sfx.tap);
                  widget.onTap!();
                },
          child: Padding(
            // Rezervăm mereu spațiul buzei, ca apăsarea să nu miște vecinii.
            padding: EdgeInsets.only(bottom: widget.lip),
            child: AnimatedContainer(
              duration: motion.d(90),
              curve: Curves.easeOut,
              width: widget.width,
              height: widget.height,
              transform: Matrix4.translationValues(0, widget.lip - lip, 0),
              padding: widget.padding,
              decoration: candyDecoration(
                color: widget.color,
                radius: widget.radius,
                lip: lip,
                lipColor: widget.lipColor,
                shadow: !pressed,
                border: widget.border,
                borderWidth: widget.borderWidth,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Buton rotund cu iconiță albă (bara de sus).
class CandyIconButton extends StatelessWidget {
  const CandyIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.size,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double? size;

  /// Comutator pornit: inel alb în jurul butonului.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final side = size ?? AppLayout.of(context).barButton;
    final lip = side * 0.08;
    return Tooltip(
      message: label,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: CandyPressable(
          color: color,
          radius: side / 2,
          lip: lip,
          width: side,
          height: side - lip,
          semanticLabel: label,
          onTap: onTap,
          border: active ? Colors.white : null,
          borderWidth: active ? 3 : 0,
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: side * 0.5,
              shadows: [
                Shadow(color: shade(color, 0.25), offset: const Offset(0, 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Buton mare cu iconiță și text (finalul jocului, dialoguri).
class CandyButton extends StatelessWidget {
  const CandyButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.minWidth = 200,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return CandyPressable(
      color: color,
      radius: 999,
      lip: compact ? 5 : 7,
      semanticLabel: label,
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 22 : 30,
        vertical: compact ? 10 : 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth - 60),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: compact ? 28 : 36),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: Colors.white,
                fontSize: compact ? 20 : 24,
                shadows: [
                  Shadow(color: shade(color, 0.25), offset: const Offset(0, 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panou crem, ne-apăsabil (conținut peste scenă).
class CandyPanel extends StatelessWidget {
  const CandyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = const Color(0xFFFFFBF4),
    this.radius = 30,
    this.lip = 6,
    this.opacity = 0.96,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final double lip;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: candyDecoration(
      color: color.withValues(alpha: opacity),
      radius: radius,
      lip: lip,
      lipColor: const Color(0xFFE7DCC8).withValues(alpha: opacity),
    ),
    child: child,
  );
}

/// Text cu contur alb gros — se citește peste orice scenă pictată.
class OutlinedTitle extends StatelessWidget {
  const OutlinedTitle(
    this.text, {
    super.key,
    this.style,
    this.color = Tokens.ink,
    this.stroke = 6,
    this.textAlign = TextAlign.start,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle? style;
  final Color color;
  final double stroke;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.headlineMedium!);
    return Stack(
      children: [
        // Conturul e doar decor: RichText, ca textul să existe o singură dată (cititoare de
        // ecran, teste).
        RichText(
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textScaler: MediaQuery.textScalerOf(context),
          text: TextSpan(
            text: text,
            style: DefaultTextStyle.of(context).style
                .merge(base)
                .copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = stroke
                    ..strokeJoin = StrokeJoin.round
                    ..color = Colors.white,
                  shadows: const [
                    Shadow(
                      color: Color(0x332F3D3B),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
          ),
        ),
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Balon de vorbire cu codiță spre stânga-jos (spre mascotă).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    super.key,
    required this.child,
    this.tail = BubbleTail.bottomLeft,
    this.padding,
  });

  final Widget child;
  final BubbleTail tail;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    return CustomPaint(
      painter: _BubblePainter(tail),
      child: Padding(
        padding:
            padding ??
            EdgeInsets.fromLTRB(
              compact ? 14 : 18,
              compact ? 8 : 12,
              compact ? 14 : 18,
              (compact ? 8 : 12) + 12,
            ),
        child: child,
      ),
    );
  }
}

enum BubbleTail { bottomLeft, bottom, left }

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.tail);

  final BubbleTail tail;

  @override
  void paint(Canvas canvas, Size size) {
    const r = 20.0;
    const t = 12.0;
    final body = switch (tail) {
      BubbleTail.left => Rect.fromLTRB(t, 0, size.width, size.height - t),
      _ => Rect.fromLTRB(0, 0, size.width, size.height - t),
    };
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(r)));
    final tailPath = Path();
    switch (tail) {
      case BubbleTail.bottomLeft:
        tailPath
          ..moveTo(22, body.bottom - 2)
          ..quadraticBezierTo(16, body.bottom + t * 0.7, 6, body.bottom + t)
          ..quadraticBezierTo(30, body.bottom + t * 0.6, 44, body.bottom - 2)
          ..close();
      case BubbleTail.bottom:
        final cx = size.width / 2;
        tailPath
          ..moveTo(cx - 14, body.bottom - 2)
          ..lineTo(cx, body.bottom + t)
          ..lineTo(cx + 14, body.bottom - 2)
          ..close();
      case BubbleTail.left:
        final cy = body.height * 0.62;
        tailPath
          ..moveTo(t + 2, cy - 12)
          ..quadraticBezierTo(t * 0.4, cy, 0, cy + 10)
          ..quadraticBezierTo(t * 0.9, cy + 8, t + 2, cy + 8)
          ..close();
    }
    final all = Path.combine(PathOperation.union, path, tailPath);
    canvas.drawShadow(all, const Color(0x552F3D3B), 6, false);
    canvas.drawPath(all, Paint()..color = const Color(0xFFFFFDF8));
    canvas.drawPath(
      all,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFEDE3D2),
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.tail != tail;
}
