import 'package:flutter/material.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici_core/licurici_core.dart';

import 'emoji_art.dart';

/// Ilustrațiile generate (packages/game_content/art/illustrations, README §14.1).
AssetImage illustration(String path) =>
    AssetImage('art/illustrations/$path.webp', package: contentPackage);

AssetImage gameIllustration(String gameId) => illustration('games/$gameId');
AssetImage domainIllustration(Domain d) =>
    illustration('domains/${d.code.toLowerCase()}');

/// O ilustrație cu rezervă OpenMoji: dacă fișierul lipsește, apare emoji-ul (nimic nu se strică
/// cât timp setul de ilustrații e incomplet).
class Illustration extends StatelessWidget {
  const Illustration(
    this.image, {
    super.key,
    required this.fallbackEmoji,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final ImageProvider image;
  final String fallbackEmoji;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Image(
    image: image,
    fit: fit,
    gaplessPlayback: true,
    filterQuality: FilterQuality.medium,
    semanticLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
    errorBuilder: (context, _, _) => LayoutBuilder(
      builder: (context, c) => Center(
        child: EmojiArt(
          fallbackEmoji,
          size: (c.biggest.shortestSide * 0.7).clamp(24, 200),
        ),
      ),
    ),
  );
}

/// Emoji-ul de rezervă al fiecărei arii.
String domainEmoji(Domain d) => switch (d) {
  Domain.atn => '👀',
  Domain.imi => '🙌',
  Domain.pot => '🧩',
  Domain.lrc => '👂',
  Domain.com => '💬',
  Domain.cog => '💭',
  Domain.emo => '😊',
  Domain.fex => '🏮',
  Domain.aut => '🪥',
  Domain.mot => '✋',
  Domain.pac => '🔢',
};
