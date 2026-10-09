import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici/data/session.dart';
import 'package:licurici/features/home/today_path.dart';
import 'package:licurici_core/licurici_core.dart';

void main() {
  test('„Drumul de azi” se scurtează când copilul spune că e obosit', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final sub = c.listen(todayPlanProvider, (_, _) {});
    addTearDown(sub.close);
    final normal = await c.read(todayPlanProvider.future);
    expect(normal.activities.where((a) => a.kind == ActivityKind.target), hasLength(2));
    c.read(sessionProvider.notifier).start(moodBefore: Mood.obosit);
    final gentle = await c.read(todayPlanProvider.future);
    expect(gentle.activities.where((a) => a.kind == ActivityKind.target), hasLength(1));
  });
}
