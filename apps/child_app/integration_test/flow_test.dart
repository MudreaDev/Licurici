// Pe dispozitiv: `flutter test integration_test -d <id>` (`flutter devices` arată id-ul).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('copil → joc → final → salvare → trimitere pe server', childToServerFlow);
}
