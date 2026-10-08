import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Desenele colorate în „Colorăm” (creațiile copilului). **Rămân pe dispozitiv**: nu se
/// sincronizează și nu ies din aplicație (README §11, §13); se șterg cu „Șterge datele de pe
/// tabletă”. Cele mai noi primele; cel mult [drawingsKept].
class SavedDrawing {
  const SavedDrawing(this.id, this.page, this.png);

  final String id;

  /// Pagina colorată (`casa`, `floare`…).
  final String page;
  final Uint8List png;
}

const drawingsKept = 24;

abstract interface class DrawingStore {
  Future<List<SavedDrawing>> load();
  Future<void> add(SavedDrawing d);
  Future<void> clear();
}

/// Pe web (doar previzualizare) și în teste: în memorie.
class MemoryDrawingStore implements DrawingStore {
  final _items = <SavedDrawing>[];

  @override
  Future<List<SavedDrawing>> load() async => List.of(_items);

  @override
  Future<void> add(SavedDrawing d) async {
    _items.insert(0, d);
    if (_items.length > drawingsKept) _items.removeLast();
  }

  @override
  Future<void> clear() async => _items.clear();
}

/// Pe dispozitiv: `<suport aplicație>/drawings/index.json` + `<id>.png`.
class FileDrawingStore implements DrawingStore {
  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}/drawings');
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  Future<List<Map<String, Object?>>> _index(Directory d) async {
    final f = File('${d.path}/index.json');
    if (!f.existsSync()) return [];
    return (jsonDecode(await f.readAsString()) as List).cast<Map<String, Object?>>();
  }

  @override
  Future<List<SavedDrawing>> load() async {
    final d = await _dir();
    final out = <SavedDrawing>[];
    for (final j in await _index(d)) {
      final f = File('${d.path}/${j['id']}.png');
      if (f.existsSync()) out.add(SavedDrawing(j['id']! as String, j['page']! as String, await f.readAsBytes()));
    }
    return out;
  }

  @override
  Future<void> add(SavedDrawing s) async {
    final d = await _dir();
    await File('${d.path}/${s.id}.png').writeAsBytes(s.png, flush: true);
    final index = [
      {'id': s.id, 'page': s.page},
      ...await _index(d),
    ];
    for (final old in index.skip(drawingsKept)) {
      final f = File('${d.path}/${old['id']}.png');
      if (f.existsSync()) await f.delete();
    }
    await File('${d.path}/index.json').writeAsString(jsonEncode(index.take(drawingsKept).toList()), flush: true);
  }

  @override
  Future<void> clear() async {
    final d = await _dir();
    if (d.existsSync()) await d.delete(recursive: true);
  }
}

final drawingStoreProvider = Provider<DrawingStore>((ref) => kIsWeb ? MemoryDrawingStore() : FileDrawingStore());

/// Desenele salvate (se reîncarcă după fiecare desen nou).
final drawingsProvider = FutureProvider<List<SavedDrawing>>((ref) => ref.read(drawingStoreProvider).load());
