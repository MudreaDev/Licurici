import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

/// Laudele lui Licurici în aplicație (frazele și regulile sunt în `Praise`, în nucleu).
/// Ține minte seria de răspunsuri bune din prima (oricare ar fi jocul) și ultima frază de
/// final, ca ecranul de final să scrie exact ce a spus vocea.
class Cheer {
  Cheer([Praise? praise]) : _praise = praise ?? Praise();

  final Praise _praise;
  int _inARow = 0;

  /// Fraza de final spusă ultima dată (titlul ecranului de final).
  String lastFinish = Praise.finish.first;

  /// Un răspuns corect. [firstTry] = fără greșeli și fără ajutor la runda asta.
  String correct({bool firstTry = true}) {
    _inARow = firstTry ? _inARow + 1 : 0;
    return _praise.forCorrect(firstTry: firstTry, inARow: _inARow);
  }

  /// O greșeală: încurajare (seria reîncepe).
  String retry() {
    _inARow = 0;
    return _praise.forRetry();
  }

  /// Jocul s-a terminat.
  String finish() {
    _inARow = 0;
    return lastFinish = _praise.forFinish();
  }
}

final cheerProvider = Provider<Cheer>((ref) => Cheer());
