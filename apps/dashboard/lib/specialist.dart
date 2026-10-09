import 'api.dart';
import 'ask_panel.dart';
import 'game_plan.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:licurici_core/licurici_core.dart';
import 'data.dart';
import 'live.dart';
import 'shared.dart';
import 'progress.dart';

class SpecialistPage extends ConsumerWidget {
  const SpecialistPage({super.key, this.childId});
  final String? childId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider);
    final selected = children.where((h) => h.child.id == childId).firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        Widget childList() =>
            _ChildrenList(children, childId, compact: compact);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Licurici · Specialist'),
            actions: [
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Schimbă rolul'),
              ),
              const Padding(padding: EdgeInsets.all(16), child: Text('DEMO')),
            ],
          ),
          drawer: compact ? Drawer(child: SafeArea(child: childList())) : null,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact) SizedBox(width: 290, child: childList()),
              if (!compact) const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.people_outline, size: 56),
                              const SizedBox(height: 20),
                              Text(
                                childId == null
                                    ? 'Alege un copil pentru a vedea progresul.'
                                    : 'Copilul nu a fost găsit.',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              if (compact)
                                Builder(
                                  builder: (context) => TextButton(
                                    onPressed: () =>
                                        Scaffold.of(context).openDrawer(),
                                    child: const Text('Vezi copiii'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : _ChildDetail(
                        key: ValueKey(selected.child.id),
                        history: selected,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChildrenList extends StatelessWidget {
  const _ChildrenList(this.children, this.selectedId, {required this.compact});
  final List<ChildHistory> children;
  final String? selectedId;
  final bool compact;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Copii urmăriți · ${children.length}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      if (children.isEmpty) const Text('Nu există copii partajați încă.'),
      for (final h in children)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: selectedId == h.child.id
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    h.child.nickname,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                  PlayingBadge(childId: h.child.id),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${h.child.ageYears} ani · ${h.sessions.length} sesiuni',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    h.latest == null
                        ? 'Fără sesiuni'
                        : 'Ultima: ${dateLabel(h.latest!.record.start)}',
                  ),
                  if (h.latest?.struggling.isNotEmpty ?? false)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFF80622F),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Atenție',
                            style: TextStyle(color: Color(0xFF80622F)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              onTap: () {
                if (compact) Navigator.pop(context);
                context.go('/specialist/copil/${h.child.id}');
              },
            ),
          ),
        ),
    ],
  );
}

class _ChildDetail extends StatelessWidget {
  const _ChildDetail({super.key, required this.history});
  final ChildHistory history;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 20,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    history.child.nickname,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    '${history.child.ageYears} ani · ${history.sessions.length} sesiuni',
                  ),
                ],
              ),
              AiSummaryButton(history: history),
            ],
          ),
        ),
        const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Prezentare'),
            Tab(text: 'Progres'),
            Tab(text: 'Sesiuni'),
            Tab(text: 'Confuzii'),
            Tab(text: 'Jocuri'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _TabBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Overview(history.latest),
                    AskPanel(key: ValueKey('ask-${history.child.id}'), history: history),
                  ],
                ),
              ),
              _TabBody(child: ProgressPanel(history)),
              _TabBody(child: _Sessions(history)),
              _TabBody(
                child: Section(
                  'Confuzii · toate sesiunile',
                  child: ConfusionBars(aggregateConfusions(history)),
                ),
              ),
              _TabBody(child: GamePlanPanel(key: ValueKey('plan-${history.child.id}'), history: history)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(padding: const EdgeInsets.all(24), child: child);
}

class _Overview extends StatelessWidget {
  const _Overview(this.report);
  final SessionReport? report;
  @override
  Widget build(BuildContext context) {
    final r = report;
    if (r == null) return const Text('Nu există sesiuni încă.');
    final s = r.overall;
    final values = <String, String>{
      'Acuratețe': percent(s.accuracy),
      'Independență': percent(s.independence),
      'Ajutor mediu · P0–P4': 'P${s.meanPromptLevel.toStringAsFixed(1)}',
      'Latență mediană': s.medianLatencyMs == null
          ? '—'
          : '${s.medianLatencyMs} ms',
      'Oboseală · Δ latență': r.fatigue == null
          ? 'Date insuficiente'
          : '${r.fatigue! >= 0 ? '+' : ''}${percent(r.fatigue!)}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ultima sesiune · ${dateLabel(r.record.start)}'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final e in values.entries)
              SizedBox(
                width: 205,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key),
                        const SizedBox(height: 12),
                        Text(
                          e.value,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Oboseală: variația latenței mediane între a doua și prima jumătate a sesiunii; un indiciu, nu un diagnostic.',
        ),
        const SizedBox(height: 24),
        Section(
          'Observații pentru specialist',
          child: NotesList(r.specialistNotes),
        ),
      ],
    );
  }
}

class _Sessions extends StatelessWidget {
  const _Sessions(this.history);
  final ChildHistory history;
  @override
  Widget build(BuildContext context) => Section(
    'Sesiuni · cele mai recente întâi',
    child: history.reports.isEmpty
        ? const Text('Nu există sesiuni încă.')
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columns: [
                for (final label in [
                  'Data',
                  'Durată',
                  'Încercări',
                  'Acuratețe',
                  'Independență',
                  'Pauze',
                  'Dispoziție',
                ])
                  DataColumn(label: Text(label)),
              ],
              rows: [
                for (final r in history.reports.reversed)
                  DataRow(
                    onSelectChanged: (_) => showReportDialog(
                      context,
                      'Sesiunea din ${dateLabel(r.record.start)}',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NotesList(r.specialistNotes),
                          Section(
                            'Confuzii în sesiune',
                            child: ConfusionBars(r.confusions),
                          ),
                          ExpansionTile(
                            title: const Text(
                              'Date trimise la AI (pseudonimizate)',
                            ),
                            subtitle: const Text(
                              'Previzualizare locală. Nu s-a trimis nimic.',
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: SelectableText(
                                  const JsonEncoder.withIndent(
                                    '  ',
                                  ).convert(r.toAiJson()),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    cells: [
                      DataCell(Text(dateLabel(r.record.start))),
                      DataCell(Text('${r.minutes} min')),
                      DataCell(Text('${r.overall.count}')),
                      DataCell(Text(percent(r.overall.accuracy))),
                      DataCell(Text(percent(r.overall.independence))),
                      DataCell(Text('${r.count(SessionEventKind.pause)}')),
                      DataCell(MoodPair(r, size: 24)),
                    ],
                  ),
              ],
            ),
          ),
  );
}

List<Confusion> aggregateConfusions(ChildHistory history) {
  final counts = <(String, String), int>{};
  for (final r in history.reports) {
    for (final c in r.confusions) {
      final key = (c.target, c.chosen);
      counts[key] = (counts[key] ?? 0) + c.count;
    }
  }
  return [
    for (final e in counts.entries) Confusion(e.key.$1, e.key.$2, e.value),
  ]..sort((a, b) {
    final count = b.count.compareTo(a.count);
    return count != 0
        ? count
        : '${a.target}/${a.chosen}'.compareTo('${b.target}/${b.chosen}');
  });
}

class ConfusionBars extends StatelessWidget {
  const ConfusionBars(this.confusions, {super.key});
  final List<Confusion> confusions;
  @override
  Widget build(BuildContext context) {
    if (confusions.isEmpty) return const Text('Nu sunt confuzii înregistrate.');
    final max = confusions.fold<int>(1, (v, c) => c.count > v ? c.count : v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in confusions)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.target} → ${c.chosen} · ${c.count} ori'),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: c.count / max,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                  semanticsLabel: '${c.target} ales ${c.chosen}',
                  semanticsValue: percent(c.count / max),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
