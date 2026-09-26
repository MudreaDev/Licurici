import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:game_content/game_content.dart';

/// Ilustrația OpenMoji pentru un emoji (niciodată emoji de sistem — arată la fel peste tot).
class EmojiArt extends StatelessWidget {
  const EmojiArt(this.emoji, {super.key, this.size = 64, this.semanticLabel});

  final String emoji;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        openMojiAsset(emoji),
        package: contentPackage,
        width: size,
        height: size,
        semanticsLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        errorBuilder: (context, error, stack) =>
            Text(emoji, style: TextStyle(fontSize: size * 0.8)),
      );
}
