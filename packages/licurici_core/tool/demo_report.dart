import 'package:licurici_core/licurici_core.dart';

void main() {
  for (final h in demoChildren().take(2)) {
    final r = h.latest!;
    print('== ${h.child.nickname}');
    print(r.parentSummary);
    r.specialistNotes.forEach(print);
  }
}
