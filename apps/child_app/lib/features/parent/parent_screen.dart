import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/theme.dart';
import '../../data/session.dart';
import '../../shared/mascot.dart';
import '../../shared/top_bar.dart';
import '../settings/settings.dart';
import 'sync_dialog.dart';

/// Rapoartele sesiunilor salvate pe dispozitiv (cele mai noi întâi), fiecare cu raportul
/// sesiunii anterioare pentru comparație.
final localReportsProvider = FutureProvider.autoDispose<List<SessionReport>>((
  ref,
) async {
  final records = await ref.watch(sessionStoreProvider).all();
  final reports = <SessionReport>[];
  for (final r in records) {
    reports.add(
      SessionReport.from(r, previous: reports.isEmpty ? null : reports.last),
    );
  }
  return reports.reversed.toList();
});

/// Colțul părintelui pe tabletă: rezumatul fiecărei sesiuni, din datele locale, fără cont și
/// fără internet. Detaliile pentru specialist sunt pliate sub fiecare sesiune.
class ParentScreen extends ConsumerWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(localReportsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'Pentru părinți',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BarButton(
                    key: const ValueKey('sync-sessions'),
                    icon: Icons.cloud_upload_rounded,
                    color: Tokens.primary,
                    label: 'Trimite sesiunile pe server',
                    onTap: () => showSyncDialog(context),
                  ),
                  const SizedBox(width: 8),
                  BarButton(
                    key: const ValueKey('export-sessions'),
                    icon: Icons.content_copy_rounded,
                    color: Tokens.mint,
                    label: 'Copiază sesiunile pentru specialist',
                    onTap: () => _export(context, ref),
                  ),
                ],
              ),
            ),
            const _StartLevel(),
            Expanded(
              child: reports.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const Center(
                  child: Text('Sesiunile nu au putut fi citite.'),
                ),
                data: (list) => list.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Mascot(size: 120, mood: MascotMood.sleep),
                              SizedBox(height: 12),
                              Text(
                                'Încă nu există sesiuni. După ce copilul se joacă și apasă „Gata pe azi”, '
                                'rezumatul apare aici.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            _SessionCard(report: list[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nivelul de pornire al jocurilor cu alegere (dificultatea inițială). Pe ecranul copilului
/// jocurile sunt pe arii de dezvoltare, nu pe clase (ADR-026); clasa rămâne doar aici.
class _StartLevel extends ConsumerWidget {
  const _StartLevel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(settingsProvider.select((s) => s.grade));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Text(
            'Nivel de pornire:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final g in Grade.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('start-level-${g.name}'),
                        label: Text(g.label),
                        selected: g == selected,
                        onSelected: (_) =>
                            ref.read(settingsProvider.notifier).setGrade(g),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copiază sesiunile (JSON pseudonimizat) în clipboard; specialistul le lipește în panoul web.
Future<void> _export(BuildContext context, WidgetRef ref) async {
  final sessions = await ref.read(sessionStoreProvider).all();
  await Clipboard.setData(ClipboardData(text: exportSessions(sessions)));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        sessions.isEmpty
            ? 'Nu există încă sesiuni de copiat.'
            : '${sessions.length} sesiuni copiate. Lipește-le în panoul web („Importă sesiuni”).',
      ),
    ),
  );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.report});
  final SessionReport report;

  @override
  Widget build(BuildContext context) {
    final r = report.record;
    final d = r.start.toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    final when =
        '${two(d.day)}.${two(d.month)}.${d.year} · ${two(d.hour)}:${two(d.minute)}';
    final text = Theme.of(context).textTheme;
    return Card(
      key: ValueKey('session-${r.id}'),
      color: Tokens.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(when, style: text.titleMedium)),
                if (r.moodBefore != null || r.moodAfter != null)
                  Text(
                    '${r.moodBefore?.emoji ?? '·'}  →  ${r.moodAfter?.emoji ?? '·'}',
                    style: text.titleLarge,
                    semanticsLabel:
                        'La început ${r.moodBefore?.label ?? 'nespus'}, la final ${r.moodAfter?.label ?? 'nespus'}',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(report.parentSummary, style: text.bodyLarge),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Detalii pentru specialist'),
                children: [
                  for (final n in report.specialistNotes)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $n'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
