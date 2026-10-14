import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:licurici_core/licurici_core.dart';

/// Laudele sunt variate (`Praise`): testele caută oricare dintre ele, nu doar „Bravo!”.
Finder findPraise() => find.byWidgetPredicate(
  (w) => w is Text && [...Praise.correct, ...Praise.helped, ...Praise.streak].contains(w.data),
  description: 'o laudă',
);

/// Titlul de final (oricare dintre frazele de final).
Finder findFinish() => find.byWidgetPredicate(
  (w) => w is Text && Praise.finish.contains(w.data),
  description: 'lauda de final',
);
