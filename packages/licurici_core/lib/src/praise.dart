/// Ce îi spune Licurici copilului după un răspuns: laude variate, ca jocul să pară viu
/// („Bravo!”, „Super!”, „Bine jucat!”…), dar mereu scurte, calde și fără ironie.
///
/// Din terapie (ABA, întărire diferențiată): un răspuns **din prima, singur** primește o
/// laudă mai mare decât unul **cu ajutor** (acolo doar confirmăm: „Așa e!”); o serie de
/// răspunsuri bune la rând e numită ca atare („Încă una! Ești în formă!”). Nicio frază nu
/// se repetă de două ori la rând, ca să nu sune mecanic.
///
/// Fiecare frază are clip de voce (`tool/voice_coverage.dart` le citește de aici).
library;

import 'dart:math';

class Praise {
  Praise([Random? random]) : _random = random ?? Random();

  final Random _random;
  final _last = <List<String>, String>{};

  /// După un răspuns corect, din prima.
  static const correct = [
    'Bravo!',
    'Super!',
    'Bine jucat!',
    'Foarte bine!',
    'Excelent!',
    'Ai reușit!',
    'Minunat!',
    'Așa da!',
    'Grozav!',
    'Perfect!',
    'Ce bine!',
    'Felicitări!',
  ];

  /// Corect, dar după o greșeală sau cu ajutor: confirmăm, fără sărbătoare mare.
  static const helped = [
    'Așa e!',
    'Da, acesta!',
    'Corect!',
    'Bine!',
    'Ai găsit!',
  ];

  /// După o serie de răspunsuri bune la rând (vezi [streakLength]).
  static const streak = [
    'Încă una! Ești în formă!',
    'Nu greșești deloc!',
    'Merge minunat azi!',
    'Ce serie frumoasă!',
  ];

  /// La finalul jocului.
  static const finish = [
    'Ai terminat! Bravo!',
    'Gata! Ai jucat minunat!',
    'Bine jucat! Ai terminat jocul!',
    'Super! Ai terminat!',
    'Ce joc frumos! Ai reușit!',
    'Felicitări! Ai terminat jocul!',
  ];

  /// După o greșeală: încurajare blândă, niciodată „greșit”.
  static const retry = [
    'Mai încearcă',
    'Hai, încă o dată!',
    'Aproape! Mai încearcă.',
    'Încearcă din nou, poți!',
  ];

  /// Toate frazele (pentru acoperirea vocii și pentru teste).
  static const all = [...correct, ...helped, ...streak, ...finish, ...retry];

  /// Câte răspunsuri bune din prima, la rând, fac o „serie”.
  static const streakLength = 3;

  /// O frază din [list], alta decât cea spusă ultima dată din aceeași listă.
  String pick(List<String> list) {
    final last = _last[list];
    var next = list[_random.nextInt(list.length)];
    if (list.length > 1) {
      while (next == last) {
        next = list[_random.nextInt(list.length)];
      }
    }
    _last[list] = next;
    return next;
  }

  /// Lauda pentru un răspuns corect: [firstTry] = fără greșeli și fără ajutor la runda asta;
  /// [inARow] = câte răspunsuri din prima la rând, cu acesta cu tot.
  String forCorrect({bool firstTry = true, int inARow = 1}) {
    if (!firstTry) return pick(helped);
    if (inARow >= streakLength && inARow % streakLength == 0) return pick(streak);
    return pick(correct);
  }

  String forFinish() => pick(finish);

  String forRetry() => pick(retry);
}
