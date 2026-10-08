import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import '../../app/theme.dart';
import '../../shared/top_bar.dart';
import '../settings/settings.dart';

/// „Primii pași”: câteva întrebări pentru părinte despre ce face copilul acum, din care
/// aplicația propune ce jocuri vede copilul și de la ce nivel pornesc. Nu e o evaluare;
/// răspunsurile nu se păstrează, doar propunerea aplicată (care se poate schimba oricând).
class FirstStepsScreen extends ConsumerStatefulWidget {
  const FirstStepsScreen({super.key});

  @override
  ConsumerState<FirstStepsScreen> createState() => _FirstStepsScreenState();
}

class _FirstStepsScreenState extends ConsumerState<FirstStepsScreen> {
  final _answers = <String, FirstStepAnswer>{};

  static const _labels = {
    FirstStepAnswer.notYet: 'Încă nu',
    FirstStepAnswer.sometimes: 'Uneori',
    FirstStepAnswer.yes: 'Da, singur',
  };

  void _apply() {
    final plan = firstStepsPlan(_answers);
    final settings = ref.read(settingsProvider);
    // Nivelul propus doar ridică pornirea; nu coboară ce a câștigat deja copilul.
    final levels = {
      for (final MapEntry(:key, :value) in plan.levels.entries)
        if ((settings.levels[key] ?? 1) < value) key: value,
    };
    ref.read(settingsProvider.notifier).applyPlan(plan.hidden, levels, DateTime.now().toUtc());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          plan.hidden.isEmpty
              ? 'Gata: copilul vede toate jocurile.'
              : 'Gata: ${plan.hidden.length} jocuri mai grele așteaptă deocamdată. Le poți bifa oricând.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plan = firstStepsPlan(_answers);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  BarButton(
                    key: const ValueKey('first-steps-back'),
                    icon: Icons.arrow_back_rounded,
                    color: Tokens.primary,
                    label: 'Înapoi',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Primii pași', style: text.titleLarge!.copyWith(color: Tokens.ink)),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('first-steps-apply'),
                    onPressed: _answers.isEmpty ? null : _apply,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _answers.isEmpty ? 'Aplică' : 'Aplică (${plan.hidden.length} ascunse, ${plan.levels.length} mai sus)',
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Răspunde doar la ce știi; întrebările sărite nu schimbă nimic. Nu e o evaluare: aplicația '
                'doar propune de unde să pornească. „Încă nu” ascunde deocamdată jocurile mai grele ale ariei, '
                '„Da, singur” pornește primele jocuri de la un nivel mai sus.',
                style: text.bodyMedium!.copyWith(color: Tokens.inkSoft),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  for (final q in firstStepQuestions)
                    Card(
                      key: ValueKey('first-step-${q.id}'),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text(q.text, style: text.titleSmall!.copyWith(color: Tokens.ink)),
                            SegmentedButton<FirstStepAnswer>(
                              key: ValueKey('first-step-answer-${q.id}'),
                              emptySelectionAllowed: true,
                              showSelectedIcon: false,
                              segments: [
                                for (final MapEntry(:key, :value) in _labels.entries)
                                  ButtonSegment(value: key, label: Text(value)),
                              ],
                              selected: {?_answers[q.id]},
                              onSelectionChanged: (s) => setState(
                                () => s.isEmpty ? _answers.remove(q.id) : _answers[q.id] = s.first,
                              ),
                            ),
                          ],
                        ),
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
