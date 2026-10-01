import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

/// Boundary for the future authorized API data source.
final childrenProvider = Provider<List<ChildHistory>>((ref) => demoChildren());
String dateLabel(DateTime date) {
  final d = date.toLocal();
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String percent(double value) => '${(value * 100).round()}%';
