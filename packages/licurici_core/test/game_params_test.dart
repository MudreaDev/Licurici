import 'package:licurici_core/licurici_core.dart';
import 'package:test/test.dart';

void main() {
  test('plafonul oprește urcarea, fără să coboare sub 1', () {
    expect(capLevel(7, 5), 5);
    expect(capLevel(3, 5), 3);
    expect(capLevel(9, null), 9);
    expect(capLevel(0, 4), 1);
    expect(gameParams.map((p) => p.id), ['start', 'max']);
  });
}
