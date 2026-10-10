import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_content/game_content.dart';
import 'package:licurici/shared/voice.dart';

import '../integration_test/flow.dart';

/// Fluxul de pe dispozitiv (`integration_test/flow.dart`), aici cu timp simulat: copil → joc →
/// final → SQLite → „Trimite pe server” către un server HTTP local.
void main() {
  setUp(() {
    rootBundle.clear();
    svg.cache.clear();
  });

  testWidgets('copil → joc → final → salvare → trimitere pe server', (tester) async {
    // Serverul e unul HTTP adevărat, pe 127.0.0.1: fără clientul simulat al binding-ului de test.
    HttpOverrides.global = null;
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await childToServerFlow(tester, overrides: [voiceManifestProvider.overrideWith((ref) => VoiceManifest(const {}))]);
  });
}
