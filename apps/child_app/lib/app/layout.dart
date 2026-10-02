import 'package:flutter/widgets.dart';

/// Aplicația copilului rulează în LANDSCAPE (telefon și tabletă). Pe telefon, înălțimea utilă e
/// mică (~360–430 dp), așa că dimensiunile se adaptează după înălțime, nu după lățime.
class AppLayout {
  const AppLayout._(this.size);

  factory AppLayout.of(BuildContext context) =>
      AppLayout._(MediaQuery.sizeOf(context));

  final Size size;

  /// Telefon ținut landscape: înălțime mică.
  bool get compact => size.height < 500;

  /// Suficient de lat pentru două panouri (stimul în stânga, variante în dreapta).
  bool get twoPane => size.width >= size.height * 1.2;

  /// Telefon ținut în portret (posibil doar pe web): cerem rotirea.
  bool get phonePortrait => size.shortestSide < 600 && size.height > size.width;

  /// Latura butoanelor din bara de sus (≥ 48 dp chiar și pe telefon).
  double get barButton => compact ? 52 : 64;

  double get mascot => compact ? 64 : (size.height >= 700 ? 128 : 96);
}
