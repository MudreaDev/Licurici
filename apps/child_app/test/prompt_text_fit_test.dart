import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici/features/games/choice/visuals.dart';

/// O frază lungă în stimul (ex. „Mare, mic, roșu”: „mingea portocalie”) pe panoul îngust al
/// telefonului mic: se micșorează, nu iese din panou. Înainte, depășirea apărea doar pentru
/// unele combinații aleatoare (testul pe toate jocurile o prindea din când în când).
void main() {
  for (final animated in [true, false]) {
    testWidgets('frază lungă în panou îngust (animații: $animated)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: !animated),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 300,
                    child: PromptVisuals(visuals: const [TextVisual('mingea portocalie mare')], solved: false),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PromptVisuals)).width, lessThanOrEqualTo(300));
    });
  }
}
