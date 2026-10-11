import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:game_content/game_content.dart';

/// Pre-încarcă ilustrațiile OpenMoji în cache-ul flutter_svg, ca să apară instant (fără
/// „pâlpâit” în timpul animațiilor de intrare). O ilustrație lipsă nu oprește încărcarea:
/// `EmojiArt` are oricum rezervă.
Future<void> precacheArt(Iterable<String> emojis) async {
  await Future.wait(
    // Fețele desenate din cod (`face:…`) nu au SVG.
    emojis.toSet().where((e) => !e.startsWith('face:')).map((emoji) async {
      final loader = SvgAssetLoader(
        openMojiAsset(emoji),
        packageName: contentPackage,
      );
      try {
        await svg.cache.putIfAbsent(
          loader.cacheKey(null),
          () => loader.loadBytes(null),
        );
      } on Object catch (e) {
        debugPrint('ilustrație lipsă pentru $emoji: $e');
      }
    }),
  );
}
