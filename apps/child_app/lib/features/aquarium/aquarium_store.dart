import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:path_provider/path_provider.dart';

import 'fish_art.dart';

/// Un pește din acvariul copilului. Desenul (creația copilului) **rămâne pe dispozitiv**;
/// nu se sincronizează (README §2, §11, §13).
class AquariumEntry {
  const AquariumEntry({required this.id, required this.species, required this.created, this.gift = false});

  final String id;
  final String species;
  final DateTime created;

  /// Peștele dăruit de Licurici la prima vizită.
  final bool gift;

  Map<String, Object> toJson() => {
    'id': id,
    'species': species,
    'created': created.toIso8601String(),
    if (gift) 'gift': true,
  };

  static AquariumEntry fromJson(Map<String, Object?> j) => AquariumEntry(
    id: j['id']! as String,
    species: j['species']! as String,
    created: DateTime.parse(j['created']! as String),
    gift: j['gift'] == true,
  );
}

/// Unde stau peștii: lista + desenul fiecăruia (PNG).
abstract interface class AquariumStore {
  Future<List<(AquariumEntry, Uint8List)>> load();
  Future<void> save(List<AquariumEntry> entries, {(String, Uint8List)? drawing, String? removed});
}

/// Pe web (doar previzualizare) și în teste: în memorie.
class MemoryAquariumStore implements AquariumStore {
  final _drawings = <String, Uint8List>{};
  var _entries = <AquariumEntry>[];

  @override
  Future<List<(AquariumEntry, Uint8List)>> load() async => [
    for (final e in _entries)
      if (_drawings[e.id] case final d?) (e, d),
  ];

  @override
  Future<void> save(List<AquariumEntry> entries, {(String, Uint8List)? drawing, String? removed}) async {
    _entries = List.of(entries);
    if (drawing != null) _drawings[drawing.$1] = drawing.$2;
    if (removed != null) _drawings.remove(removed);
  }
}

/// Pe dispozitiv: `<suport aplicație>/aquarium/index.json` + `<id>.png`.
class FileAquariumStore implements AquariumStore {
  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/aquarium');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  @override
  Future<List<(AquariumEntry, Uint8List)>> load() async {
    final d = await _dir();
    final index = File('${d.path}/index.json');
    if (!index.existsSync()) return [];
    final list = (jsonDecode(await index.readAsString()) as List).cast<Map<String, Object?>>();
    final out = <(AquariumEntry, Uint8List)>[];
    for (final j in list) {
      final e = AquariumEntry.fromJson(j);
      final f = File('${d.path}/${e.id}.png');
      if (f.existsSync()) out.add((e, await f.readAsBytes()));
    }
    return out;
  }

  @override
  Future<void> save(List<AquariumEntry> entries, {(String, Uint8List)? drawing, String? removed}) async {
    final d = await _dir();
    if (drawing != null) await File('${d.path}/${drawing.$1}.png').writeAsBytes(drawing.$2, flush: true);
    await File('${d.path}/index.json').writeAsString(jsonEncode([for (final e in entries) e.toJson()]), flush: true);
    if (removed != null) {
      final f = File('${d.path}/$removed.png');
      if (f.existsSync()) await f.delete();
    }
  }
}

final aquariumStoreProvider = Provider<AquariumStore>((ref) => kIsWeb ? MemoryAquariumStore() : FileAquariumStore());

/// Un pește încărcat: intrarea și imaginea gata de înot.
class OwnedFish {
  const OwnedFish(this.entry, this.species, this.art);

  final AquariumEntry entry;
  final FishSpecies species;
  final ui.Image art;
}

/// Câți pești încap: peste atât, cel mai vechi (în afară de cadou) iese din acvariu.
const aquariumCapacity = 14;

class AquariumNotifier extends AsyncNotifier<List<OwnedFish>> {
  AquariumStore get _store => ref.read(aquariumStoreProvider);

  @override
  Future<List<OwnedFish>> build() async {
    final saved = await _store.load();
    final fish = <OwnedFish>[];
    for (final (e, png) in saved) {
      final s = fishSpeciesById(e.species);
      if (s == null) continue;
      final drawing = await _decodePng(png);
      fish.add(OwnedFish(e, s, await buildFishImage(s, drawing)));
      drawing.dispose();
    }
    if (fish.isEmpty) {
      // Prima vizită: Licurici dăruiește un pește-clovn gata colorat.
      final s = fishSpeciesById('clovn')!;
      final drawing = await paintGiftDrawing(s);
      final e = AquariumEntry(id: 'cadou', species: s.id, created: DateTime.now(), gift: true);
      await _store.save([e], drawing: (e.id, await _png(drawing)));
      fish.add(OwnedFish(e, s, await buildFishImage(s, drawing)));
      drawing.dispose();
    }
    return fish;
  }

  /// Peștele colorat de copil intră în acvariu. Întoarce id-ul lui.
  Future<String> add(FishSpecies s, ui.Image drawing) async {
    final current = await future;
    final e = AquariumEntry(id: 'p${DateTime.now().microsecondsSinceEpoch}', species: s.id, created: DateTime.now());
    final art = await buildFishImage(s, drawing);
    var next = [...current, OwnedFish(e, s, art)];
    String? removed;
    if (next.length > aquariumCapacity) {
      final oldest = next.firstWhere((f) => !f.entry.gift, orElse: () => next.first);
      removed = oldest.entry.id;
      next = [for (final f in next) if (f.entry.id != removed) f];
    }
    await _store.save([for (final f in next) f.entry], drawing: (e.id, await _png(drawing)), removed: removed);
    state = AsyncData(next);
    return e.id;
  }
}

final aquariumProvider = AsyncNotifierProvider<AquariumNotifier, List<OwnedFish>>(AquariumNotifier.new);

Future<Uint8List> _png(ui.Image img) async =>
    (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

Future<ui.Image> _decodePng(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
