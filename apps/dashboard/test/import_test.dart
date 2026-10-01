import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:licurici_dashboard/app.dart';

void main() {
  testWidgets(
    'sesiunile copiate din aplicație apar ca „Copilul meu” în panoul specialistului',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = createRouter(initialLocation: '/');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: DashboardApp(router: router)),
      );
      await tester.pumpAndSettle();

      // Text greșit → mesaj clar, nimic importat.
      await tester.tap(find.byKey(const ValueKey('import-sessions')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('import-text')),
        'nu e json',
      );
      await tester.tap(find.byKey(const ValueKey('import-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Textul nu este un export Licurici.'), findsOneWidget);

      // Exportul real → import → copilul apare primul în lista specialistului.
      final sessions = demoChildren()[1].sessions;
      await tester.enterText(
        find.byKey(const ValueKey('import-text')),
        exportSessions(sessions),
      );
      await tester.tap(find.byKey(const ValueKey('import-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '${sessions.length} sesiuni importate: apar ca „Copilul meu”.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Sunt specialist'));
      await tester.pumpAndSettle();
      expect(find.text('Copilul meu'), findsWidgets);
    },
  );
}
