import 'package:flutter/widgets.dart';

import 'illustration.dart';
import 'stimulus_art.dart';

/// Piesele pictate (Codex, `art/illustrations/parts/`) care înlocuiesc desenele din cod: masa și
/// cutia de la „Unde e ursulețul?”, inelele Turnului, ghiveciul, bulele, cuburile, paharele…
/// Imaginile sunt decupate la conturul lor (fără margini), ca să se poată așeza exact într-un
/// dreptunghi. Până există piesa, ecranul își păstrează desenul din cod.
bool hasPart(String name) => IllustrationIndex.has('parts/$name');

/// Tonurile de gri ale desenului, ridicate (umbrele rămân), gata de înmulțit cu o culoare.
const tintBase = ColorFilter.matrix([
  0.1913, 0.6437, 0.0650, 0, 76.5, //
  0.1913, 0.6437, 0.0650, 0, 76.5,
  0.1913, 0.6437, 0.0650, 0, 76.5,
  0, 0, 0, 1, 0,
]);

/// Piesa [name], întinsă pe tot spațiul primit ([fit] = fill) sau păstrându-și proporțiile.
/// [tint]: piesa (desenată în crem) e colorată cu culoarea dată, cu umbrele păstrate.
class Part extends StatelessWidget {
  const Part(this.name, {super.key, this.tint, this.fit = BoxFit.fill, this.alignment = Alignment.center});

  final String name;
  final Color? tint;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    Widget w = Image(
      image: illustration('parts/$name'),
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
    final c = tint;
    if (c != null) {
      w = ColorFiltered(
        colorFilter: ColorFilter.mode(c, BlendMode.modulate),
        child: ColorFiltered(colorFilter: tintBase, child: w),
      );
    }
    return w;
  }
}
