import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/layout.dart';
import '../../app/theme.dart';
import '../../shared/illustration.dart';
import '../../shared/ui/candy.dart';
import 'aquarium_store.dart';

/// Butoanele acvariului: obiecte pictate (borcanul cu mâncare, pensula, aparatul foto) în
/// bule rotunde mari, cu numele dedesubt — copilul recunoaște obiectul, nu o iconiță.
class DockButton extends StatelessWidget {
  const DockButton({
    super.key,
    required this.image,
    required this.fallback,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  /// Ilustrația (ex. `sprites/food_jar`); [fallback] dacă lipsește.
  final String image;
  final IconData fallback;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  /// Un semn mic în colț (ex. prețul în stele).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    final side = compact ? 66.0 : 92.0;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CandyPressable(
                color: const Color(0xFFFFF8EC),
                lipColor: shade(color, 0.1),
                border: color,
                borderWidth: compact ? 3 : 4,
                radius: side / 2,
                lip: side * 0.08,
                width: side,
                height: side,
                semanticLabel: label,
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.all(side * 0.1),
                  child: Image(
                    image: illustration(image),
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => Icon(fallback, color: color, size: side * 0.5),
                  ),
                ),
              ),
              if (badge case final b?) Positioned(right: -6, top: -6, child: b),
            ],
          ),
          SizedBox(height: compact ? 2 : 4),
          _Label(label, compact: compact),
        ],
      ),
    );
  }
}

/// Numele de sub buton, pe o bulină crem (se citește pe apă).
class _Label extends StatelessWidget {
  const _Label(this.text, {required this.compact});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 1 : 3),
    decoration: BoxDecoration(color: const Color(0xE6FFF8EC), borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge!.copyWith(
        color: Tokens.ink,
        fontSize: compact ? 13 : 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// Prețul mâncării: o steluță cu cifra.
class StarPrice extends StatelessWidget {
  const StarPrice(this.price, {super.key});

  final int price;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFF2C14E), size: 20),
        Text('$price', style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Tokens.ink, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

/// Butonul de zi/noapte din bara de sus: luna (noaptea) sau soarele (ziua), pictate.
class SkyButton extends StatelessWidget {
  const SkyButton({super.key, required this.night, required this.onTap});

  final bool night;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final side = AppLayout.of(context).barButton;
    final color = night ? const Color(0xFFF2C14E) : const Color(0xFF4B5A9C);
    return Tooltip(
      message: night ? 'Zi' : 'Noapte',
      child: CandyPressable(
        key: const ValueKey('night'),
        color: color,
        radius: side / 2,
        lip: side * 0.08,
        width: side,
        height: side - side * 0.08,
        semanticLabel: night ? 'Zi' : 'Noapte',
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(side * 0.14),
          child: Image(
            // Butonul arată ce urmează: noaptea, soarele (dimineața); ziua, luna.
            image: illustration(night ? 'sprites/sun_day' : 'sprites/moon_night'),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => Icon(
              night ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: Colors.white,
              size: side * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// „Peștii mei”: câte o bulă cu fiecare pește al copilului. Atingerea îl cheamă la geam.
class FishShelf extends StatelessWidget {
  const FishShelf({super.key, required this.fish, required this.onPick, this.picked});

  final List<OwnedFish> fish;
  final void Function(String id) onPick;

  /// Peștele chemat acum (bula lui se luminează).
  final String? picked;

  @override
  Widget build(BuildContext context) {
    final compact = AppLayout.of(context).compact;
    final side = compact ? 48.0 : 64.0;
    return Container(
      padding: EdgeInsets.all(compact ? 5 : 8),
      decoration: BoxDecoration(
        color: const Color(0x55FFFFFF),
        borderRadius: BorderRadius.circular(side),
        border: Border.all(color: const Color(0x88FFFFFF), width: 2),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, f) in fish.reversed.indexed)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : (compact ? 5 : 8)),
                child: _FishBubble(
                  key: ValueKey('shelf-${f.entry.id}'),
                  fish: f,
                  side: side,
                  lit: f.entry.id == picked,
                  onTap: () => onPick(f.entry.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FishBubble extends StatelessWidget {
  const _FishBubble({super.key, required this.fish, required this.side, required this.lit, required this.onTap});

  final OwnedFish fish;
  final double side;
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bubble = CandyPressable(
      color: lit ? const Color(0xFFFFF3C4) : const Color(0xFFEAF8FB),
      border: lit ? const Color(0xFFF2C14E) : Colors.white,
      borderWidth: 3,
      radius: side / 2,
      lip: side * 0.07,
      width: side,
      height: side,
      semanticLabel: 'Peștele meu: ${fish.species.name}',
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(side * 0.1),
        child: RawImage(image: fish.art, fit: BoxFit.contain),
      ),
    );
    return lit ? bubble.animate(key: ValueKey(lit)).scaleXY(begin: 1, end: 1.12, duration: 220.ms, curve: Curves.easeOutBack) : bubble;
  }
}
