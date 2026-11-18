import 'package:licurici_core/licurici_core.dart';

void main() {
  for (final domain in Domain.values) {
    final entries = catalog.where((entry) => entry.domain == domain).toList();
    print('## ${childLabel(domain)} (${domain.code}) — ${entries.length} jocuri');
    print('');
    for (final entry in entries) {
      print('- [ ] ${entry.name} (`${entry.id}`, ${entry.kind.name})');
    }
    print('');
  }
}
