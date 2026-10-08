/// Zilele și lunile (catalog #24 `calendar`, treapta PAC-T0): săptămâna și anul ca șiruri care
/// se repetă. Stimulul e o bandă de cartonașe colorate ([StripVisual]) cu un loc gol.
/// Tier 1–2: ce zi urmează (trei zile la rând); tier 3–4: ce zi lipsește din săptămână;
/// tier 5: ieri / mâine („Azi e marți. Ce zi a fost ieri?”); tier 6–7: lunile (ce lună
/// lipsește); de la tier 8: în ce anotimp e luna.
library;

import '../game.dart';
import '../grades.dart';

const weekDays = ['luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică'];
const months = [
  'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie', //
  'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
];

/// Culorile zilelor (curcubeul săptămânii) și ale anotimpurilor lunilor.
const dayColors = [0xFFF28B82, 0xFFF6B26B, 0xFFF2CF6B, 0xFF8FD18A, 0xFF7FC8E8, 0xFF9AA8F0, 0xFFC79AE8];
const _seasonColors = [0xFF8FC6EE, 0xFF9ED68B, 0xFFF4C95D, 0xFFE89B5C]; // iarnă, primăvară, vară, toamnă

/// Anotimpul lunii (0 = iarnă, 1 = primăvară, 2 = vară, 3 = toamnă).
int seasonOf(int month) => ((month + 1) % 12) ~/ 3;

const seasons = [('iarna', '❄️'), ('primăvara', '🌸'), ('vara', '☀️'), ('toamna', '🍂')];

int monthColor(int month) => _seasonColors[seasonOf(month)];

class CalendarGame extends ChoiceGame {
  const CalendarGame()
      : super(
          id: 'calendar',
          name: 'Zilele și lunile',
          emoji: '🗓️',
          description: 'Săptămâna și anul',
          subject: Subject.timpBani,
          gradeCodes: 'G12',
        );

  @override
  Lesson generate(GameContext ctx) {
    final tier = ctx.difficulty.tier;
    return Lesson(
      title: name,
      instruction: 'Ascultă și alege.',
      rounds: [
        for (var i = 0; i < 8; i++)
          switch (tier) {
            <= 2 => _nextDay(ctx),
            <= 4 => i.isEven ? _missingDay(ctx) : _nextDay(ctx),
            5 => i.isEven ? _yesterdayTomorrow(ctx) : _missingDay(ctx),
            <= 7 => i % 3 == 2 ? _yesterdayTomorrow(ctx) : _missingMonth(ctx),
            _ => i.isEven ? _season(ctx) : _missingMonth(ctx),
          },
      ],
    );
  }

  List<Choice> _options(GameContext ctx, List<String> pool, String answer, {int Function(String)? color}) {
    final others = ctx.sample([for (final p in pool) if (p != answer) p], 4);
    return [
      for (final o in [answer, ...others]..shuffle(ctx.random))
        Choice(label: o, id: o, speak: o, correct: o == answer, color: color?.call(o)),
    ];
  }

  ChoiceRound _nextDay(GameContext ctx) {
    final start = ctx.random.nextInt(7);
    final strip = [for (var k = 0; k < 3; k++) weekDays[(start + k) % 7]];
    final answer = weekDays[(start + 3) % 7];
    return ChoiceRound(
      prompt: 'Ce zi vine după ${strip.last}?',
      speak: ['Ce zi vine după ${strip.last}?'],
      hint: 'După ${strip.last} vine $answer.',
      stimulusId: answer,
      visuals: [
        StripVisual(
          [...strip, answer],
          [for (var k = 0; k <= 3; k++) dayColors[(start + k) % 7]],
          missing: 3,
        ),
      ],
      choices: _options(ctx, weekDays, answer),
    );
  }

  ChoiceRound _missingDay(GameContext ctx) {
    final gap = 1 + ctx.random.nextInt(5); // nu prima, nu ultima: se vede între ce zile e
    final answer = weekDays[gap];
    return ChoiceRound(
      prompt: 'Ce zi lipsește?',
      speak: ['Ce zi lipsește?'],
      hint: 'Între ${weekDays[gap - 1]} și ${weekDays[gap + 1]} e $answer.',
      stimulusId: answer,
      visuals: [StripVisual(weekDays, dayColors, missing: gap)],
      choices: _options(ctx, weekDays, answer),
    );
  }

  ChoiceRound _yesterdayTomorrow(GameContext ctx) {
    final today = ctx.random.nextInt(7);
    final past = ctx.random.nextBool();
    final answer = weekDays[(today + (past ? 6 : 1)) % 7];
    final q = past ? 'Ce zi a fost ieri?' : 'Ce zi va fi mâine?';
    // Banda: ieri – azi – mâine, cu „azi” știut și locul întrebat gol.
    final days = [(today + 6) % 7, today, (today + 1) % 7];
    return ChoiceRound(
      prompt: 'Azi e ${weekDays[today]}. $q',
      speak: ['Azi e ${weekDays[today]}.', q],
      hint: past ? 'Ieri a fost $answer.' : 'Mâine va fi $answer.',
      stimulusId: past ? 'ieri' : 'maine',
      visuals: [
        StripVisual(
          [for (final d in days) weekDays[d]],
          [for (final d in days) dayColors[d]],
          missing: past ? 0 : 2,
          captions: const ['ieri', 'azi', 'mâine'],
        ),
      ],
      choices: _options(ctx, weekDays, answer),
    );
  }

  ChoiceRound _missingMonth(GameContext ctx) {
    final start = ctx.random.nextInt(12);
    final gap = 1 + ctx.random.nextInt(2);
    final shown = [for (var k = 0; k < 4; k++) (start + k) % 12];
    final answer = months[shown[gap]];
    return ChoiceRound(
      prompt: 'Ce lună lipsește?',
      speak: ['Ce lună lipsește?'],
      hint: 'După ${months[shown[gap - 1]]} vine $answer.',
      stimulusId: answer,
      visuals: [
        StripVisual([for (final m in shown) months[m]], [for (final m in shown) monthColor(m)], missing: gap),
      ],
      choices: _options(ctx, months, answer),
    );
  }

  ChoiceRound _season(GameContext ctx) {
    final m = ctx.random.nextInt(12);
    final (name, art) = seasons[seasonOf(m)];
    return ChoiceRound(
      prompt: 'În ce anotimp e luna ${months[m]}?',
      speak: ['În ce anotimp e luna ${months[m]}?'],
      hint: 'Luna ${months[m]} e $name.',
      stimulusId: months[m],
      fixedChoices: true,
      visuals: [StripVisual([months[m]], [monthColor(m)])],
      choices: [
        for (final (n, a) in seasons) Choice(label: n, art: a, id: n, speak: n, correct: n == name),
      ],
    );
  }
}
