import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:licurici_core/licurici_core.dart';

/// De unde vine fotografia fișei: camera sistemului (pe web, un fișier). În teste se
/// înlocuiește cu o imagine generată.
typedef PhotoSource = Future<Uint8List?> Function();

final photoSourceProvider = Provider<PhotoSource>(
  (ref) => () async {
    final shot = await ImagePicker().pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      maxWidth: 2200,
      maxHeight: 2200,
      imageQuality: 92,
    );
    return shot?.readAsBytes();
  },
);

/// Rezultatul scanării: peștele găsit (modelul + desenul 1000×600) sau ce n-a mers.
class PaperFish {
  const PaperFish(this.species, this.drawing);

  final FishSpecies species;
  final ui.Image drawing;
}

/// Caută fișa în fotografia [encoded] (JPEG/PNG). Fotografia nu se păstrează nicăieri.
Future<(PaperFish?, ScanProblem?)> scanPhoto(Uint8List encoded) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  // Destul pentru detectare și pentru un desen de 1000×600, fără să încărcăm 12 MP în memorie.
  final scale = 1800 / (descriptor.width > descriptor.height ? descriptor.width : descriptor.height);
  final codec = await descriptor.instantiateCodec(
    targetWidth: scale < 1 ? (descriptor.width * scale).round() : null,
    targetHeight: scale < 1 ? (descriptor.height * scale).round() : null,
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  final img = frame.image;
  final w = img.width, h = img.height;
  final rgba = (await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
  img.dispose();

  final (id, drawing, problem) = await compute(_scan, (rgba, w, h));
  if (id == null || drawing == null) return (null, problem ?? ScanProblem.noSheet);
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(drawing, 1000, 600, ui.PixelFormat.rgba8888, done.complete);
  return (PaperFish(fishSpeciesById(id)!, await done.future), null);
}

/// Rulează în alt isolate (pe web, pe loc): doar date simple trec granița.
(String?, Uint8List?, ScanProblem?) _scan((Uint8List, int, int) job) {
  final r = scanPaper(job.$1, job.$2, job.$3);
  return (r.species?.id, r.drawing, r.problem);
}
