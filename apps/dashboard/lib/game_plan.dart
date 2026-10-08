import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:licurici_core/licurici_core.dart';

import 'api.dart';
import 'shared.dart';

/// Planul de jocuri al copilului (plan §5.1): specialistul (sau părintele) alege, pe arii, ce
/// jocuri vede copilul pe tabletă. Tableta preia alegerea la următoarea sincronizare.
/// Funcționează doar pentru copiii de pe server (cei demo sau importați nu au tabletă legată).
class GamePlanPanel extends ConsumerStatefulWidget {
  const GamePlanPanel({super.key, required this.history});

  final ChildHistory history;

  @override
  ConsumerState<GamePlanPanel> createState() => _GamePlanPanelState();
}

class _GamePlanPanelState extends ConsumerState<GamePlanPanel> {
  Set<String>? _hidden;
  Set<String> _saved = const {};
  Map<String, int> _levels = {};
  Map<String, int> _savedLevels = const {};
  String? _info;
  String? _error;
  bool _busy = false;

  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final fromServer = ref.watch(serverChildrenProvider).any((h) => h.child.id == widget.history.child.id);
    // Copiii de pe server pot sosi după deschiderea paginii: încărcăm planul atunci.
    if (fromServer && _hidden == null && !_loading) {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    return _body(context, fromServer);
  }

  Future<void> _load() async {
    try {
      final plan = await ref.read(apiClientProvider).plan(widget.history.child.id);
      if (!mounted) return;
      setState(() {
        _hidden = {...plan.hidden};
        _saved = {...plan.hidden};
        _levels = {...plan.levels};
        _savedLevels = {...plan.levels};
        _info = plan.updatedAt == null
            ? 'Copilul vede toate jocurile.'
            : 'Ultima schimbare: ${plan.updatedAt!.toLocal().toString().substring(0, 16)}'
                  '${plan.updatedBy == 'THERAPIST' ? ' (specialist)' : ' (părinte)'}.';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final plan = await ref.read(apiClientProvider).setPlan(widget.history.child.id, _hidden!, levels: _levels);
      if (!mounted) return;
      setState(() {
        _saved = {...plan.hidden};
        _savedLevels = {...plan.levels};
        _info = 'Salvat. Tableta preia lista la următoarea sincronizare.';
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
  static bool _sameMap(Map<String, int> a, Map<String, int> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  void _toggle(Iterable<String> ids, bool visible) {
    final next = {..._hidden!};
    visible ? next.removeAll(ids) : next.addAll(ids);
    if (next.length >= catalog.length) return; // cel puțin un joc rămâne
    setState(() => _hidden = next);
  }

  Widget _body(BuildContext context, bool fromServer) {
    if (!fromServer) {
      return const Section(
        'Jocurile copilului',
        child: Text(
          'Alegerea jocurilor e disponibilă pentru copiii sincronizați de pe tabletă (după autentificare). '
          'Pe tabletă, părintele o poate face și din „Pentru părinți” → „Jocurile copilului”.',
        ),
      );
    }
    final hidden = _hidden;
    final text = Theme.of(context).textTheme;
    return Section(
      'Jocurile copilului',
      child: hidden == null
          ? (_error == null ? const LinearProgressIndicator() : Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copilul vede doar jocurile bifate (pe ecranul principal și în „Drumul de azi”). '
                  'Scoate jocurile care nu îi folosesc acum sau care îl agită; datele lor rămân. '
                  'Nivelul de pornire e opțional: implicit, jocul continuă adaptiv de unde a rămas copilul. '
                  'Fiecare schimbare apare în jurnal.',
                  style: text.bodyMedium,
                ),
                if (_info != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_info!, style: text.bodySmall)),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                const SizedBox(height: 12),
                for (final MapEntry(key: domain, value: games) in catalogByDomain().entries)
                  ExpansionTile(
                    key: ValueKey('plan-${domain.code}'),
                    tilePadding: EdgeInsets.zero,
                    title: Text('${domain.code} · ${domain.label}', style: text.titleSmall),
                    subtitle: Text('${games.where((g) => !hidden.contains(g.id)).length} din ${games.length} jocuri'),
                    leading: Checkbox(
                      key: ValueKey('plan-domain-${domain.code}'),
                      tristate: true,
                      value: games.every((g) => !hidden.contains(g.id))
                          ? true
                          : (games.every((g) => hidden.contains(g.id)) ? false : null),
                      onChanged: (v) => _toggle(games.map((g) => g.id), v ?? false),
                    ),
                    children: [
                      for (final g in games)
                        CheckboxListTile(
                          key: ValueKey('plan-game-${g.id}'),
                          dense: true,
                          title: Text(g.name),
                          subtitle: Text('${g.description} · ${stepsForGame(g.id).map((s) => s.id).join(', ')}'),
                          value: !hidden.contains(g.id),
                          onChanged: (v) => _toggle([g.id], v ?? true),
                          secondary: DropdownButton<int?>(
                            key: ValueKey('plan-level-${g.id}'),
                            value: _levels[g.id],
                            hint: const Text('nivel: adaptiv'),
                            underline: const SizedBox.shrink(),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('nivel: adaptiv')),
                              for (var l = 1; l <= 15; l++) DropdownMenuItem<int?>(value: l, child: Text('pornește de la $l')),
                            ],
                            onChanged: (l) => setState(() => l == null ? _levels.remove(g.id) : _levels[g.id] = l),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('plan-save'),
                  onPressed: _busy || (_sameSet(hidden, _saved) && _sameMap(_levels, _savedLevels)) ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Salvează lista'),
                ),
              ],
            ),
    );
  }
}
