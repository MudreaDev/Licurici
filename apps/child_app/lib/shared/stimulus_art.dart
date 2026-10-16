import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici_core/licurici_core.dart';

import 'art_cache.dart';
import 'drawn_face.dart';
import 'emoji_art.dart';
import 'illustration.dart';
import 'painted_extra.dart';

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
  '👆': 'sprites/hand',
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
  // Acțiunile (același copil): „Ce face?”, rutine, tabla de comunicare
  '🛌': 'actions/doarme',
  '🥣': 'actions/mananca',
  '🥤': 'actions/bea',
  '🏃': 'actions/alearga',
  '📚': 'actions/citeste',
  '🖍️': 'actions/deseneaza',
  '🎤': 'actions/canta',
  '👐': 'actions/se-spala',
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
  // Obiectele din loturile Codex (generat, `tools/art/painted_map.py`).
  ...paintedExtra,
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

/// Ilustrația copilului pictat pentru [face] (`faces2/<id>_<emoție>_<intensitate>`): treapta cea
/// mai apropiată dintre cele pictate (20…100% la copiii din `ladderLooks`, altfel doar 100%).
String? paintedFace(FaceSpec face) {
  final id = face.look.paintedId;
  if (id == null) return null;
  final ladder = face.emotion != FaceEmotion.neutru && ladderLooks.contains(face.look);
  final pct = ladder ? ((face.intensity * 5).round().clamp(1, 5) * 20) : 100;
  final path = 'faces2/${id}_${face.emotion.name}_$pct';
  return IllustrationIndex.has(path) ? path : null;
}

/// Ilustrația pictată a unui stimul, dacă există.
AssetImage? spriteFor(String emoji) {
  if (FaceSpec.parse(emoji) case final face?) {
    final path = paintedFace(face);
    return path == null ? null : illustration(path);
  }
  return switch (_paths[emoji]) {
    final path? when IllustrationIndex.has(path) => illustration(path),
    _ => null,
  };
}

/// Imaginile de pre-încărcat pentru o listă de stimuli.
Iterable<AssetImage> spritesFor(Iterable<String> emojis) =>
    emojis.toSet().map(spriteFor).nonNulls;

/// Pre-încarcă stimulii (ilustrații pictate + rezervele OpenMoji), ca animațiile de intrare
/// să pornească cu imaginile deja în memorie. Emoji-urile cu ilustrație pictată nu mai trec
/// prin SVG. Așteptarea e plafonată la [patience]: pe web compilarea SVG-urilor poate dura
/// secunde, iar copilul nu trebuie să stea în fața unui ecran gol — ce nu e gata apare imediat
/// după.
Future<void> precacheStimuli(
  BuildContext context,
  Iterable<String> emojis, {
  Duration patience = const Duration(milliseconds: 1500),
}) {
  final sprites = spritesFor(emojis).toList();
  final work = Future.wait([
    precacheArt(emojis.where((e) => spriteFor(e) == null)),
    for (final image in sprites)
      precacheImage(image, context, onError: (_, _) {}),
  ]);
  final done = Completer<void>();
  final timer = Timer(patience, () {
    if (!done.isCompleted) done.complete();
  });
  work.whenComplete(() {
    timer.cancel();
    if (!done.isCompleted) done.complete();
  });
  return done.future;
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
    // Fețele (`face:…`, licurici_core/face.dart): copilul pictat, dacă există ilustrația;
    // altfel fața desenată din cod.
    if (FaceSpec.parse(emoji) case final face?) {
      if (paintedFace(face) case final path?) {
        return SizedBox.square(
          dimension: size,
          child: Illustration(illustration(path), fallbackEmoji: '🧒', semanticLabel: semanticLabel ?? 'o față'),
        );
      }
      return DrawnFace(face, size: size, semanticLabel: semanticLabel);
    }
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
