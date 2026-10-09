import 'package:flutter/material.dart';
import 'package:game_content/game_content.dart' as content;
import 'package:licurici_core/licurici_core.dart';

/// Tokenii de design (README §14) — paletă calmă, saturație redusă, fără alb/negru pur.
abstract final class Tokens {
  static const bg = Color(0xFFEEF5F4);
  static const bg2 = Color(0xFFE2EEEC);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF5FAF9);
  static const ink = Color(0xFF2F3D3B);

  /// Conturul din modul „contrast mare” (aproape negru, nu negru pur).
  static const contrastEdge = Color(0xFF15201E);
  static const inkSoft = Color(0xFF5F716E);
  static const line = Color(0xFFD6E4E1);

  static const primary = Color(0xFF5B9BB5);
  static const primaryDark = Color(0xFF3F7D96);
  static const mint = Color(0xFF7FC0A3);
  static const lavender = Color(0xFFA9A3D1);
  static const peach = Color(0xFFF0B9A0);
  static const sun = Color(0xFFF2CF6B);

  /// Verde = corect, mereu (o culoare = un sens).
  static const good = Color(0xFF6BBF8A);
  static const goodSoft = Color(0xFFE4F4EA);

  /// „Mai încearcă” — portocaliu cald, niciodată roșu alarmant.
  static const gentle = Color(0xFFE6A86A);
  static const gentleSoft = Color(0xFFFBEEDE);

  static const radius = 24.0;
  static const radiusS = 16.0;

  /// Înălțimea minimă a unei ținte de atins (≥ 64 dp).
  static const tap = 76.0;

  static const shadow = [
    BoxShadow(color: Color(0x1A2F3D3B), blurRadius: 20, offset: Offset(0, 6)),
  ];
  static const shadowLg = [
    BoxShadow(color: Color(0x292F3D3B), blurRadius: 34, offset: Offset(0, 12)),
  ];
}

/// O culoare pastel per arie de dezvoltare (cardurile și ecranul ariei).
Color domainColor(Domain d) => switch (d) {
  Domain.atn => const Color(0xFFF2CF6B),
  Domain.imi => const Color(0xFFF0B9A0),
  Domain.pot => const Color(0xFF7FC0A3),
  Domain.lrc => const Color(0xFF5B9BB5),
  Domain.com => const Color(0xFFF0B9A0),
  Domain.cog => const Color(0xFF8FB8DE),
  Domain.emo => const Color(0xFFE8A3B8),
  Domain.fex => const Color(0xFFA9A3D1),
  Domain.aut => const Color(0xFF9CCBB0),
  Domain.mot => const Color(0xFFE6A86A),
  Domain.pac => const Color(0xFF6FB3C9),
};

/// Tema „calm”: mai palidă, contrast mai blând.
abstract final class CalmTokens {
  static const bg = Color(0xFFF1F3F2);
  static const surface = Color(0xFFFAFBFA);
}

const _fontFamily = 'packages/${content.contentPackage}/${content.fontFamily}';

TextStyle _round(double size, FontWeight weight, [Color color = Tokens.ink]) =>
    TextStyle(
      fontFamily: _fontFamily,
      fontSize: size,
      color: color,
      height: 1.3,
      fontWeight: weight,
    );

/// [contrast]: textul secundar devine la fel de închis ca textul principal (vedere slabă).
ThemeData buildTheme({required bool calm, bool contrast = false}) {
  final soft = contrast ? Tokens.contrastEdge : Tokens.inkSoft;
  final ink = contrast ? Tokens.contrastEdge : Tokens.ink;
  final bg = calm ? CalmTokens.bg : Tokens.bg;
  final scheme = ColorScheme.fromSeed(
    seedColor: Tokens.primary,
    surface: calm ? CalmTokens.surface : Tokens.surface,
    primary: Tokens.primary,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamily: _fontFamily,
    textTheme: TextTheme(
      displaySmall: _round(40, FontWeight.w800, ink),
      headlineMedium: _round(30, FontWeight.w800, ink),
      titleLarge: _round(24, FontWeight.w700, ink),
      titleMedium: _round(20, FontWeight.w700, ink),
      bodyLarge: _round(20, FontWeight.w600, ink),
      bodyMedium: _round(18, FontWeight.w600, soft),
      labelLarge: _round(22, FontWeight.w800, ink),
    ),
    // Textul butoanelor (ecranele adultului) în nuanța închisă: contrast WCAG ≥ 3 pe fundal.
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Tokens.primaryDark)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: Tokens.primaryDark)),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
