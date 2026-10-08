/// Colorăm (catalog #58, MOT5): joc liber de colorat (pagini desenate din cod în aplicație).
/// E creație, nu sarcină: nu are niveluri și nu se notează încercări.
library;

import 'grades.dart';

class ColorPlayGame {
  const ColorPlayGame();

  String get id => 'colorare';
  String get name => 'Colorăm';
  String get emoji => '🖍️';
  String get description => 'Colorează un desen';
  Set<Grade> get grades => Grade.parseCodes('G1234');
  List<String> get steps => const ['MOT5'];
}
