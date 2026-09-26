/// Acces la conținutul inclus în aplicație: ilustrații, voce, fonturi.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

const String contentPackage = 'game_content';
const String fontFamily = 'Nunito';

/// Numele fișierului OpenMoji pentru un emoji (port din `gfx.js`):
/// code point-uri în hex majuscule, separate cu `-`, fără selectorul de variație FE0F.
String openMojiName(String emoji) => emoji.runes
    .where((cp) => cp != 0xFE0F)
    .map((cp) => cp.toRadixString(16).toUpperCase().padLeft(4, '0'))
    .join('-');

/// Calea asset-ului SVG (se folosește cu `package: contentPackage`).
String openMojiAsset(String emoji) => 'art/openmoji/${openMojiName(emoji)}.svg';

/// Manifestul vocii: text rostit → fișier mp3.
class VoiceManifest {
  VoiceManifest(this._clips);

  final Map<String, String> _clips;

  static Future<VoiceManifest> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle)
        .loadString('packages/$contentPackage/audio/ro/voice.json');
    return VoiceManifest((jsonDecode(raw) as Map<String, dynamic>).cast<String, String>());
  }

  /// Calea asset-ului pentru [text] (relativă la bundle), sau null dacă nu există clip.
  String? assetFor(String text) {
    final file = _clips[text.trim()];
    return file == null ? null : 'packages/$contentPackage/audio/ro/$file';
  }

  bool has(String text) => _clips.containsKey(text.trim());

  int get length => _clips.length;
}
