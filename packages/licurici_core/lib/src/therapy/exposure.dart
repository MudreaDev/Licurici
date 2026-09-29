/// Fără repetări, dar cu repetarea bună (plan §3.5 d): istoricul combinațiilor văzute de copil
/// și repetarea spațiată (Leitner) a itemilor greșiți — în altă formă, generată din nou.
library;

/// Ce a văzut copilul: combinații (stimul + distractori + așezare) și când a văzut fiecare stimul.
class ExposureHistory {
  ExposureHistory({this.capacity = 5000});

  factory ExposureHistory.fromJson(Map<String, Object?> j) {
    final h = ExposureHistory(capacity: j['capacity'] as int? ?? 5000);
    h._clock = j['clock'] as int? ?? 0;
    h._seen.addAll((j['seen'] as List? ?? const []).cast<String>());
    h._last.addAll((j['last'] as Map? ?? const {}).cast<String, int>());
    return h;
  }

  /// Câte combinații păstrăm (cele mai vechi se uită primele).
  final int capacity;
  final _seen = <String>{}; // ordonat după inserare (cele mai vechi primele)
  final _last = <String, int>{};
  int _clock = 0;

  /// Cheia unei combinații: ținta, distractorii (fără ordine) și așezarea (ordinea pe ecran).
  static String keyOf(String target, Iterable<String> distractors, Iterable<String> layout) =>
      '$target|${(distractors.toList()..sort()).join(',')}|${layout.join(',')}';

  int get rounds => _clock;
  bool seen(String key) => _seen.contains(key);

  /// De câte runde nu a mai apărut [stimulusId] (`null` = niciodată).
  int? ago(String stimulusId) {
    final t = _last[stimulusId];
    return t == null ? null : _clock - t;
  }

  void add(String key, {Iterable<String> stimuli = const []}) {
    _clock++;
    _seen
      ..remove(key)
      ..add(key);
    while (_seen.length > capacity) {
      _seen.remove(_seen.first);
    }
    for (final s in stimuli) {
      _last[s] = _clock;
    }
  }

  Map<String, Object?> toJson() => {
        'capacity': capacity,
        'clock': _clock,
        'seen': _seen.toList(),
        'last': _last,
      };
}

/// Cutiile Leitner: un item greșit revine după 1 zi; fiecare reușită îl mută în cutia următoare
/// (3, 7, 30 de zile). O greșeală îl întoarce la început.
class SpacedReview {
  SpacedReview({this.intervals = const [Duration(days: 1), Duration(days: 3), Duration(days: 7), Duration(days: 30)]})
      : assert(intervals.isNotEmpty);

  final List<Duration> intervals;
  final _items = <String, ({int box, DateTime due})>{};

  int? boxOf(String item) => _items[item]?.box;

  void record(String item, {required bool correct, required DateTime now}) {
    final cur = _items[item];
    if (correct && cur == null) return; // reușit din prima: nu intră la repetat
    final box = correct ? (cur!.box + 1).clamp(0, intervals.length - 1) : 0;
    if (correct && cur!.box == intervals.length - 1) {
      _items.remove(item); // a trecut și de ultimul interval: stăpânit
      return;
    }
    _items[item] = (box: box, due: now.add(intervals[box]));
  }

  /// Itemii de repetat acum, cei mai „restanți” primii.
  List<String> due(DateTime now) {
    final list = _items.entries.where((e) => !e.value.due.isAfter(now)).toList()
      ..sort((a, b) => a.value.due.compareTo(b.value.due));
    return [for (final e in list) e.key];
  }
}
