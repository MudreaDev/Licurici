import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';
import 'data.dart';
import 'shared.dart';

class ParentPage extends ConsumerStatefulWidget {
  const ParentPage({super.key});
  @override
  ConsumerState<ParentPage> createState() => _ParentPageState();
}

class _ParentPageState extends ConsumerState<ParentPage> {
  String? selectedId;
  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenProvider);
    final history =
        children.where((c) => c.child.id == selectedId).firstOrNull ??
        children.firstOrNull;
    final latest = history?.latest;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Alegere rol',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_outlined),
        ),
        title: const Text('Licurici · Pentru părinte'),
        actions: const [
          Padding(padding: EdgeInsets.all(20), child: Text('DEMO')),
        ],
      ),
      body: history == null
          ? const Center(child: Text('Copiii tăi vor apărea aici.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Bun venit! Cum a fost pentru ${history.child.nickname}?',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Fiecare pas contează. Aici găsești momentele voastre de învățare.',
                      ),
                      const SizedBox(height: 20),
                      if (children.length > 1)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: DropdownButton<String>(
                            value: history.child.id,
                            onChanged: (id) => setState(() => selectedId = id),
                            items: [
                              for (final c in children)
                                DropdownMenuItem(
                                  value: c.child.id,
                                  child: Text(c.child.nickname),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (latest == null)
                        const Section(
                          'Ultima sesiune',
                          child: Text(
                            'Primele momente de joacă vor apărea aici.',
                          ),
                        )
                      else
                        Section(
                          'Ultima sesiune',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${dateLabel(latest.record.start)} · ${latest.minutes} min',
                              ),
                              const SizedBox(height: 16),
                              SummaryText(latest.parentSummary),
                              const SizedBox(height: 24),
                              MoodPair(latest, size: 56, labels: true),
                            ],
                          ),
                        ),
                      Section(
                        'Ce exersăm acum',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (history.child.activeSteps.isEmpty)
                              const Text(
                                'Obiectivele vor apărea odată cu planul de lucru.',
                              ),
                            for (final id in history.child.activeSteps)
                              _Objective(id, latest),
                          ],
                        ),
                      ),
                      Section(
                        'Cum s-a simțit',
                        child: history.reports.isEmpty
                            ? const Text(
                                'Dispozițiile vor apărea după prima sesiune.',
                              )
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final r in history.reports.skip(
                                      history.reports.length > 6
                                          ? history.reports.length - 6
                                          : 0,
                                    ))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 28,
                                        ),
                                        child: Column(
                                          children: [
                                            Text(dateLabel(r.record.start)),
                                            const SizedBox(height: 12),
                                            MoodPair(r),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      Section(
                        'Sesiuni anterioare',
                        child: Column(
                          children: [
                            if (history.reports.length < 2)
                              const Text(
                                'După următoarea sesiune, istoricul va fi aici.',
                              ),
                            for (final r in history.reports.reversed.skip(1))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${dateLabel(r.record.start)} · ${r.minutes} min',
                                ),
                                subtitle: Text(
                                  r.parentSummary.split('. ').first,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => showReportDialog(
                                  context,
                                  'Sesiunea din ${dateLabel(r.record.start)}',
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SummaryText(r.parentSummary),
                                      const SizedBox(height: 20),
                                      MoodPair(r, labels: true),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Text(
                        'Ilustrații: OpenMoji · CC BY-SA 4.0',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _Objective extends StatelessWidget {
  const _Objective(this.id, this.report);
  final String id;
  final SessionReport? report;
  @override
  Widget build(BuildContext context) {
    final step = stepById(id);
    final stats = report?.steps.where((s) => s.stepId == id).firstOrNull?.stats;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step?.objective ?? 'Obiectiv în curs de pregătire',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            stats == null
                ? 'Încă nu am exersat acest obiectiv în ultima sesiune.'
                : 'Pași făcuți fără ajutor, în ultima sesiune',
          ),
          const SizedBox(height: 10),
          if (stats != null)
            Tooltip(
              message: '${percent(stats.independence)} independent',
              child: LinearProgressIndicator(
                value: stats.independence,
                minHeight: 10,
                borderRadius: BorderRadius.circular(8),
                semanticsLabel: step?.objective,
                semanticsValue: percent(stats.independence),
              ),
            ),
        ],
      ),
    );
  }
}
