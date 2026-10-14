/// Catalogul jocurilor grupat pe arii de dezvoltare (ADR-026), nu pe clase și materii.
/// Ecranul principal al copilului îl afișează așa cum e; aria unui joc = aria primei trepte
/// pe care o exersează.
library;

import 'development.dart';
import 'explore.dart';
import 'games/games.dart';
import 'puzzle.dart';
import 'reaction.dart';
import 'rhythm.dart';
import 'build_copy.dart';
import 'cause_effect.dart';
import 'coloring.dart';
import 'change.dart';
import 'feeding.dart';
import 'gaze.dart';
import 'imitation.dart';
import 'instructions.dart';
import 'maze.dart';
import 'memory.dart';
import 'ordering.dart';
import 'search.dart';
import 'sequence.dart';
import 'shop.dart';
import 'aac.dart';
import 'breathing.dart';
import 'shell.dart';
import 'sorting.dart';
import 'spot_diff.dart';
import 'switching.dart';
import 'dots.dart';
import 'fitts.dart';
import 'number_line.dart';
import 'stop_signal.dart';
import 'trace.dart';
import 'tracking.dart';
import 'turns.dart';
import 'writing.dart';
import 'waiting.dart';

/// Mecanica de care depinde ruta ecranului.
enum GameKind { choice, reaction, sequence, memory, sort, calm, shell, trace, order, imitation, wait, rules, search, gaze, aac, rhythm, feed, cause, change, puzzle, maze, diff, build, shop, explore, track, write, color, turns, listen, numberLine, fitts, stop }

/// Un joc din catalog, indiferent de mecanică.
class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.kind,
    required this.domain,
  });

  final String id;
  final String name;

  /// Ilustrația de rezervă (OpenMoji) cât timp jocul nu are o ilustrație proprie.
  final String emoji;
  final String description;
  final GameKind kind;
  final Domain domain;

  /// Ruta din aplicația copilului.
  String get route => switch (kind) {
        GameKind.choice => '/joc/$id',
        GameKind.reaction => '/reactie/$id',
        GameKind.sequence => '/secventa/$id',
        GameKind.memory => '/perechi',
        GameKind.sort => id == 'sortam' ? '/sortam' : '/sortam/$id',
        GameKind.calm => '/respira',
        GameKind.shell => '/cucu-bau',
        GameKind.trace => id == 'traseaza' ? '/traseaza' : '/traseaza/$id',
        GameKind.order => '/ordine/$id',
        GameKind.imitation => '/fa-ca-licuriciul',
        GameKind.wait => id == 'semaforul' ? '/semaforul' : '/asteapta/$id',
        GameKind.rules => '/regula-se-schimba',
        GameKind.search => '/cauta',
        GameKind.gaze => '/unde-se-uita',
        GameKind.aac => '/vorbeste',
        GameKind.rhythm => '/toba-magica',
        GameKind.feed => '/hraneste-pestii',
        GameKind.cause => '/atinge-si-vezi',
        GameKind.change => '/ce-s-a-schimbat',
        GameKind.puzzle => '/puzzle',
        GameKind.maze => '/labirint',
        GameKind.diff => '/diferente',
        GameKind.build => '/construieste',
        GameKind.shop => '/la-magazin',
        GameKind.explore => '/exploreaza/$id',
        GameKind.track => '/urmareste-pestele',
        GameKind.write => '/scrie/$id',
        GameKind.color => '/coloram',
        GameKind.turns => '/pe-rand',
        GameKind.listen => '/asculta-si-fa',
        GameKind.numberLine => '/linia-numerelor',
        GameKind.fitts => '/atinge-rapid',
        GameKind.stop => '/stop',
      };

  @override
  String toString() => 'CatalogEntry($id, ${domain.code})';
}

/// Numele ariei pe înțelesul copilului (eticheta din [Domain] e pentru specialist).
String childLabel(Domain d) => switch (d) {
      Domain.atn => 'Atenție',
      Domain.imi => 'Fac și eu',
      Domain.pot => 'Potrivim',
      Domain.lrc => 'Ascult și înțeleg',
      Domain.com => 'Vorbim',
      Domain.cog => 'Gândim',
      Domain.emo => 'Emoții și prieteni',
      Domain.fex => 'Memorie și răbdare',
      Domain.aut => 'Singur',
      Domain.mot => 'Mâini dibace',
      Domain.pac => 'Numere și litere',
    };

Domain _domainOf(String gameId, List<String> declaredSteps) {
  final steps = stepsForGame(gameId);
  if (steps.isNotEmpty) return steps.first.domain;
  if (declaredSteps.isNotEmpty) return Step(declaredSteps.first, '').domain;
  throw StateError('jocul $gameId nu exersează nicio treaptă');
}

/// Toate jocurile din aplicație.
List<CatalogEntry> get catalog => [
      for (final g in allGames)
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.choice,
          domain: _domainOf(g.id, const []),
        ),
      for (final g in reactionGames)
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.reaction,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const <SequenceGame>[SimonGame(), SpatialSpanGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.sequence,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in sortGames)
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.sort,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [ShellGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.shell,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [BreathingGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.calm,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final e in exploreEpisodes)
        CatalogEntry(
          id: e.id,
          name: e.name,
          emoji: e.emoji,
          description: e.description,
          kind: GameKind.explore,
          domain: _domainOf(e.id, const []),
        ),
      for (final g in const [NumberLineGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.numberLine,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [StopSignalGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.stop,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [FittsGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.fitts,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [ShopGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.shop,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [BuildGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.build,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [SpotDiffGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.diff,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [MazeGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.maze,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [PuzzleGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.puzzle,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [ChangeGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.change,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [CauseGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.cause,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [FeedGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.feed,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [RhythmGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.rhythm,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [AacGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.aac,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [GazeGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.gaze,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [SearchGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.search,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [SwitchGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.rules,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [InstructionGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.listen,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [TurnGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.turns,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [ColorPlayGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.color,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in writingGames)
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.write,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [TrackGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.track,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in waitGames)
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.wait,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [ImitationGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.imitation,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in orderGames)
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.order,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const <TraceGame>[TraceGame(), DotsGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.trace,
          domain: _domainOf(g.id, g.steps),
        ),
      for (final g in const [MemoryGame()])
        CatalogEntry(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          description: g.description,
          kind: GameKind.memory,
          domain: _domainOf(g.id, g.steps),
        ),
    ];

/// Jocurile grupate pe arii, în ordinea din [Domain]; doar ariile care au jocuri.
/// [only] restrânge la jocurile alocate copilului (plan §5.1); null = toate.
Map<Domain, List<CatalogEntry>> catalogByDomain({Set<String>? only}) {
  final entries = [
    for (final e in catalog)
      if (only == null || only.contains(e.id)) e,
  ];
  return {
    for (final d in Domain.values)
      if (entries.any((e) => e.domain == d)) d: entries.where((e) => e.domain == d).toList(),
  };
}

CatalogEntry? catalogEntry(String id) {
  for (final e in catalog) {
    if (e.id == id) return e;
  }
  return null;
}
