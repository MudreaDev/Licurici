import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:licurici_core/licurici_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'data.dart';
import 'shared.dart';

const _lineColors = [
  Color(0xFF527D79),
  Color(0xFF84709A),
  Color(0xFFAA713C),
  Color(0xFF4F789E),
];

class ProgressPanel extends ConsumerWidget {
  const ProgressPanel(this.history, {super.key});
  final ChildHistory history;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changes = ref.watch(planChangesProvider(history.child.id)).value ?? const <DateTime>[];
    final steps = history.child.activeSteps;
    if (history.reports.isEmpty || steps.isEmpty) {
      return const Text(
        'Graficul va apărea după exersarea obiectivelor active.',
      );
    }
    final reports = history.reports;
    return Section(
      'Independență pe sesiuni',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Răspuns corect din prima, fără ajutor. Fiecare punct reprezintă o sesiune.',
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 320,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: reports.length > 1 ? reports.length.toDouble() : 2,
                minY: 0,
                maxY: 100,
                clipData: const FlClipData.all(),
                gridData: const FlGridData(
                  horizontalInterval: 20,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: 20,
                      getTitlesWidget: (v, _) => Text(
                        '${v.round()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text('Sesiunea (ordine cronologică)'),
                    axisNameSize: 28,
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: reports.length > 8 ? 2 : 1,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${v.round()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  // Schimbările planului de jocuri: linii de fază între sesiuni (plan §5.1).
                  verticalLines: [
                    for (final at in changes)
                      if (phaseX(reports, at) case final x?)
                        VerticalLine(
                          x: x,
                          color: const Color(0xFF9A6A3A),
                          strokeWidth: 1.5,
                          dashArray: [3, 4],
                          label: VerticalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9A6A3A)),
                            labelResolver: (_) => 'plan',
                          ),
                        ),
                  ],
                  horizontalLines: [
                    HorizontalLine(
                      y: 80,
                      color: const Color(0xFF746C5B),
                      strokeWidth: 1.5,
                      dashArray: [6, 5],
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => [
                      for (final spot in spots)
                        LineTooltipItem(
                          '${steps[spot.barIndex]} · ${dateLabel(reports[spot.x.round() - 1].record.start)}\n${spot.y.round()}% independent',
                          const TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  for (final (index, id) in steps.indexed)
                    LineChartBarData(
                      color: _lineColors[index % _lineColors.length],
                      barWidth: 3,
                      isCurved: false,
                      dashArray: index == 1
                          ? [8, 4]
                          : index == 2
                          ? [3, 3]
                          : null,
                      dotData: const FlDotData(show: true),
                      // Null spots preserve gaps: no measurement is not zero independence.
                      spots: [
                        for (final (i, r) in reports.indexed)
                          if (r.steps.any((s) => s.stepId == id))
                            FlSpot(
                              i + 1.0,
                              r.steps
                                      .firstWhere((s) => s.stepId == id)
                                      .stats
                                      .independence *
                                  100,
                            )
                          else
                            FlSpot.nullSpot,
                      ],
                    ),
                ],
              ),
              duration: Duration.zero,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Linie punctată la 80% · prag de independență al criteriului de stăpânire. Confirmarea depinde și de repetare, numărul de încercări și seturile de stimuli. '
            'Liniile verticale „plan” arată când s-a schimbat lista de jocuri a copilului.',
          ),
          const SizedBox(height: 20),
          for (final (i, id) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, right: 12),
                    color: _lineColors[i % _lineColors.length],
                  ),
                  Expanded(
                    child: Text(
                      '$id · ${stepById(id)?.objective ?? 'Obiectiv în curs de definire'}',
                    ),
                  ),
                ],
              ),
            ),
          ExpansionTile(
            title: const Text('Valorile graficului'),
            children: [
              for (final (i, r) in reports.indexed)
                ListTile(
                  title: Text(
                    'Sesiunea ${i + 1} · ${dateLabel(r.record.start)}',
                  ),
                  subtitle: Text(
                    [
                      for (final id in steps)
                        '$id: ${r.steps.where((s) => s.stepId == id).firstOrNull == null ? 'neexersat' : percent(r.steps.firstWhere((s) => s.stepId == id).stats.independence)}',
                    ].join(' · '),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Unde cade pe axa sesiunilor o schimbare făcută la [at]: între ultima sesiune de dinainte și
/// prima de după (x = 1 … n). Null dacă e înaintea primei sesiuni sau după ultima.
double? phaseX(List<SessionReport> reports, DateTime at) {
  final after = reports.indexWhere((r) => r.record.start.isAfter(at));
  if (after <= 0) return null;
  return after + 0.5;
}
