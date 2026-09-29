import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Un strat decupat al personajului (`tools/mascot-rig/split.py` → `rig.json`).
/// Toate coordonatele sunt în cadrul comun (1024 px pe latura mare).
class RigLayer {
  const RigLayer({required this.name, required this.rect, this.pivot});

  final String name;

  /// Unde stă stratul în cadru.
  final Rect rect;

  /// Punctul de articulație (rădăcina aripii, umărul); `null` = centrul stratului.
  final Offset? pivot;

  Offset get origin => pivot ?? rect.center;
}

/// Un ochi (pentru pleoapa desenată în cod la clipit).
class RigEye {
  const RigEye(this.center, this.radius);

  final Offset center;
  final Size radius;

  Rect get rect => Rect.fromCenter(
    center: center,
    width: radius.width * 2,
    height: radius.height * 2,
  );
}

/// Reperele efectelor desenate în cod peste straturi.
class RigAnchors {
  const RigAnchors({
    this.lantern,
    this.lanternRadius = 0,
    this.wandTip,
    this.eyes = const [],
    this.skin = const Color(0xFF8BB1A7),
  });

  /// Centrul burții luminoase (lanterna licuriciului).
  final Offset? lantern;
  final double lanternRadius;

  /// Vârful baghetei, de unde pornesc scânteile.
  final Offset? wandTip;
  final List<RigEye> eyes;

  /// Culoarea pleoapei.
  final Color skin;
}

class RigData {
  const RigData({
    required this.frame,
    required this.layers,
    this.anchors = const RigAnchors(),
  });

  factory RigData.fromJson(Map<String, Object?> json) {
    Offset pt(Object? v) {
      final l = v! as List;
      return Offset((l[0] as num).toDouble(), (l[1] as num).toDouble());
    }

    final frame = pt(json['frame']);
    final layers = <String, RigLayer>{
      for (final MapEntry(:key, :value)
          in (json['layers']! as Map<String, Object?>).entries)
        key: () {
          final m = value! as Map<String, Object?>;
          final r = (m['rect']! as List).cast<num>();
          return RigLayer(
            name: key,
            rect: Rect.fromLTRB(
              r[0].toDouble(),
              r[1].toDouble(),
              r[2].toDouble(),
              r[3].toDouble(),
            ),
            pivot: m['pivot'] == null ? null : pt(m['pivot']),
          );
        }(),
    };
    final a = json['anchors'] as Map<String, Object?>? ?? const {};
    final lantern = a['lantern'] as Map<String, Object?>?;
    final skin = a['skin'] as String?;
    return RigData(
      frame: Size(frame.dx, frame.dy),
      layers: layers,
      anchors: RigAnchors(
        lantern: lantern == null ? null : pt(lantern['center']),
        lanternRadius: (lantern?['radius'] as num?)?.toDouble() ?? 0,
        wandTip: a['wand_tip'] == null ? null : pt(a['wand_tip']),
        eyes: [
          for (final e in (a['eyes'] as List? ?? const []).cast<Map>())
            RigEye(pt(e['center']), () {
              final r = pt(e['radius']);
              return Size(r.dx, r.dy);
            }()),
        ],
        skin: skin == null
            ? const RigAnchors().skin
            : Color(0xFF000000 | int.parse(skin.substring(1), radix: 16)),
      ),
    );
  }

  final Size frame;

  /// În ordinea desenării (din spate în față), ca în `rig.json`.
  final Map<String, RigLayer> layers;
  final RigAnchors anchors;

  /// Dreptunghiul care cuprinde toate straturile (personajul, fără golul din jur).
  Rect get bounds =>
      layers.values.map((l) => l.rect).reduce((a, b) => a.expandToInclude(b));
}

/// Datele + imaginile decodate, gata de desenat.
class LoadedRig {
  const LoadedRig(this.data, this.images);

  final RigData data;
  final Map<String, ui.Image> images;

  static String dir(String name) => 'assets/mascot/$name';

  /// Încarcă `assets/mascot/<name>/rig.json` și straturile PNG.
  static Future<LoadedRig> load(String name, {AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final data = RigData.fromJson(
      jsonDecode(await b.loadString('${dir(name)}/rig.json'))
          as Map<String, Object?>,
    );
    final images = <String, ui.Image>{};
    await Future.wait(
      data.layers.keys.map((layer) async {
        final bytes = await b.load('${dir(name)}/$layer.png');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        images[layer] = (await codec.getNextFrame()).image;
      }),
    );
    return LoadedRig(data, images);
  }
}
