import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:game_content/game_content.dart';

import 'art_cache.dart';
import 'emoji_art.dart';
import 'illustration.dart';

/// Stimulii din `licurici_core` sunt identificați prin emoji (logica e independentă de
/// grafică). Unde avem o ilustrație pictată (`art/illustrations/…`), o folosim; altfel rămâne
/// OpenMoji. Setul pictat crește treptat, fără să schimbe nimic în jocuri.
const _paths = {
  // Jocurile cu reacție
  '🐟': 'sprites/fish',
  '🐙': 'sprites/octopus',
  '🦀': 'sprites/crab',
  '🐠': 'sprites/fish_colorful',
  '✨': 'sprites/firefly',
  // Emoțiile: același copil, opt expresii
  '😊': 'faces/fericit',
  '😢': 'faces/trist',
  '😠': 'faces/suparat',
  '😡': 'faces/suparat',
  '😨': 'faces/speriat',
  '😲': 'faces/surprins',
  '😴': 'faces/obosit',
  '😌': 'faces/calm',
  '😄': 'faces/mandru',
  '🧒': 'faces/calm',
  // Obiecte
  '🍎': 'objects/apple',
  '🍏': 'objects/green_apple',
  '🍒': 'objects/cherries',
  '🍓': 'objects/strawberry',
  '🍌': 'objects/banana',
  '🍉': 'objects/watermelon',
  '🥕': 'objects/carrot',
  '🍞': 'objects/bread',
  '🥚': 'objects/egg',
  '🥛': 'objects/milk',
  '🍭': 'objects/lollipop',
  '🌸': 'objects/flower',
  '🌷': 'objects/tulip',
  '🌳': 'objects/tree',
  '🌲': 'objects/pine',
  '🍂': 'objects/leaf',
  '🪨': 'objects/rock',
  '💧': 'objects/droplet',
  '❄️': 'objects/snowflake',
  '☀️': 'objects/sun',
  '🌞': 'objects/sun',
  '🌙': 'objects/moon',
  '☁️': 'objects/cloud',
  '🌈': 'objects/rainbow',
  '🔥': 'objects/flame',
  '❤️': 'objects/heart',
  '⭐': 'objects/star',
  '🌟': 'objects/star',
  '🎈': 'objects/balloon',
  '🎁': 'objects/present',
  '⚽': 'objects/ball',
  '🥁': 'objects/drum',
  '🧸': 'objects/teddy',
  '📖': 'objects/book',
  '🏠': 'objects/house',
  '🚗': 'objects/car',
  '🪙': 'objects/coin',
  '🧼': 'objects/soap',
  '🧦': 'objects/socks',
  '🪶': 'objects/feather',
  '🐶': 'objects/dog',
  '🐱': 'objects/cat',
  '🐇': 'objects/rabbit',
  '🐻': 'objects/bear',
  '🦊': 'objects/fox',
  '🐭': 'objects/mouse',
  '🐥': 'objects/chick',
  '🦆': 'objects/duck',
  '🐓': 'objects/rooster',
  '🐄': 'objects/cow',
  '🐎': 'objects/horse',
  '🐑': 'objects/sheep',
  '🐖': 'objects/pig',
  '🐘': 'objects/elephant',
  '🦒': 'objects/giraffe',
  '🦓': 'objects/zebra',
  '🦉': 'objects/owl',
  '🦋': 'objects/butterfly',
  '🐝': 'objects/bee',
  '🐢': 'objects/turtle',
  '🐬': 'objects/dolphin',
  '🐍': 'objects/snake',
  '🐿️': 'objects/squirrel',
  '🐛': 'objects/caterpillar',
};

/// Ce ilustrații există cu adevărat în pachet (din manifestul de resurse). Fără el, o
/// ilustrație lipsă ar apărea întâi goală, apoi ca emoji — un „pâlpâit” pe care îl evităm.
abstract final class IllustrationIndex {
  static Set<String> _keys = const {};

  static Future<void> load() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    _keys = manifest.listAssets().toSet();
  }

  static bool has(String path) =>
      _keys.contains('packages/$contentPackage/art/illustrations/$path.webp');
}

/// Ilustrația pictată a unui stimul, dacă există.
AssetImage? spriteFor(String emoji) => switch (_paths[emoji]) {
  final path? when IllustrationIndex.has(path) => illustration(path),
  _ => null,
};

/// Imaginile de pre-încărcat pentru o listă de stimuli.
Iterable<AssetImage> spritesFor(Iterable<String> emojis) =>
    emojis.toSet().map(spriteFor).nonNulls;

/// Pre-încarcă stimulii (ilustrații pictate + rezervele OpenMoji), ca animațiile de intrare
/// să pornească cu imaginile deja în memorie.
Future<void> precacheStimuli(
  BuildContext context,
  Iterable<String> emojis,
) async {
  final sprites = spritesFor(emojis).toList();
  await Future.wait([
    precacheArt(emojis),
    for (final image in sprites)
      precacheImage(image, context, onError: (_, _) {}),
  ]);
}

/// Un stimul: ilustrația pictată sau, în lipsa ei, emoji-ul OpenMoji.
class StimulusArt extends StatelessWidget {
  const StimulusArt(
    this.emoji, {
    super.key,
    required this.size,
    this.flip = false,
    this.semanticLabel,
  });

  final String emoji;
  final double size;

  /// Oglindit pe orizontală (peștele înoată spre stânga).
  final bool flip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final sprite = spriteFor(emoji);
    Widget art = sprite == null
        ? EmojiArt(emoji, size: size, semanticLabel: semanticLabel)
        : SizedBox.square(
            dimension: size,
            child: Illustration(
              sprite,
              fallbackEmoji: emoji,
              semanticLabel: semanticLabel,
            ),
          );
    if (flip) {
      art = Transform.flip(flipX: true, child: art);
    }
    return art;
  }
}
