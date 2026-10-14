import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_content/game_content.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/settings.dart';
import 'voice.dart';

/// Unde muzica tace: jocurile în care sunetul e chiar sarcina (notele felinarelor, toba,
/// instrucțiunile de ascultat, sunetele de recunoscut) și acvariul, care are apa lui.
bool musicPausedOn(String path) =>
    path.startsWith('/acvariu') ||
    path.startsWith('/secventa/') ||
    path == '/toba-magica' ||
    path == '/asculta-si-fa' ||
    path == '/joc/ce-se-aude' ||
    path == '/joc/primul-sunet' ||
    path == '/joc/ce-ai-auzit';

/// Cât de tare cântă muzica (0…1). Mereu în spatele vocii: când vorbește Licurici, coboară.
double musicVolume({required bool calm, required bool speaking}) {
  final base = calm ? 0.12 : 0.2;
  return speaking ? base * 0.35 : base;
}

/// Muzica liniștită de fundal (generată din cod: `tools/audio/gen_music.py`). Piesele se
/// cântă pe rând, cu câteva secunde de liniște între ele; volumul se schimbă lin, niciodată
/// brusc. Tace când aplicația nu e în față, în locurile din [musicPausedOn] și când adultul
/// a oprit-o (`AppSettings.music`).
class MusicDirector extends ConsumerStatefulWidget {
  const MusicDirector({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<MusicDirector> createState() => _MusicDirectorState();
}

class _MusicDirectorState extends ConsumerState<MusicDirector> with WidgetsBindingObserver {
  /// În testele de widget nu există pluginul audio.
  static final _available = kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

  AudioPlayer? _player;
  ValueNotifier<bool>? _speaking;
  bool _foreground = true;
  bool _playing = false;
  int _next = 0;
  MusicTrack? _queueFor;
  Timer? _gap;
  Timer? _fade;
  double _volume = 0;

  @override
  void initState() {
    super.initState();
    if (!_available) return;
    WidgetsBinding.instance.addObserver(this);
    widget.router.routerDelegate.addListener(_update);
    _speaking = ref.read(voiceActivityProvider);
    _speaking!.addListener(_update);
    // Prima piesă după ce s-a așezat ecranul de pornire.
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    if (_available) {
      WidgetsBinding.instance.removeObserver(this);
      widget.router.routerDelegate.removeListener(_update);
      _speaking?.removeListener(_update);
    }
    _gap?.cancel();
    _fade?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _update();
  }

  List<MusicTrack> _tracks(MusicTrack choice) =>
      choice == MusicTrack.all ? [MusicTrack.lumini, MusicTrack.valuri, MusicTrack.gradina] : [choice];

  void _update() {
    if (!mounted || !_available) return;
    final settings = ref.read(settingsProvider);
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    final want = settings.music && _foreground && !musicPausedOn(path);
    if (_queueFor != settings.musicTrack) {
      // Altă piesă aleasă: o luăm de la capăt, cu ea.
      _queueFor = settings.musicTrack;
      _next = 0;
      if (_playing) {
        _stop(then: _update);
        return;
      }
    }
    if (want && !_playing) {
      _start();
    } else if (!want && _playing) {
      _stop();
    } else if (_playing) {
      _fadeTo(musicVolume(calm: settings.calm, speaking: _speaking?.value ?? false));
    }
  }

  Future<void> _start() async {
    _playing = true;
    _gap?.cancel();
    final tracks = _tracks(ref.read(settingsProvider).musicTrack);
    final track = tracks[_next % tracks.length];
    _next++;
    try {
      final p = _player ??= AudioPlayer()..audioCache = AudioCache(prefix: '');
      await p.setReleaseMode(ReleaseMode.stop);
      _volume = 0;
      await p.setVolume(0);
      p.onPlayerComplete.first.then((_) {
        if (!mounted || !_playing) return;
        // Câteva secunde de liniște, apoi piesa următoare.
        _playing = false;
        _gap = Timer(const Duration(seconds: 4), _update);
      });
      await p.play(AssetSource('packages/$contentPackage/audio/music/${track.name}.mp3'));
      if (!mounted || !_playing) return;
      final s = ref.read(settingsProvider);
      _fadeTo(musicVolume(calm: s.calm, speaking: _speaking?.value ?? false), seconds: 3);
    } on Object catch (e) {
      // Fără audio (ex. browser înainte de prima atingere): reîncercăm la următoarea schimbare.
      debugPrint('muzică: $e');
      _playing = false;
    }
  }

  void _stop({VoidCallback? then}) {
    _playing = false;
    _gap?.cancel();
    _fadeTo(0, seconds: 0.8, done: () {
      _player?.stop().catchError((_) {});
      then?.call();
    });
  }

  /// Volumul se schimbă lin (pași de 50 ms), ca să nu tresară copilul.
  void _fadeTo(double target, {double seconds = 0.6, VoidCallback? done}) {
    _fade?.cancel();
    final p = _player;
    if (p == null) {
      done?.call();
      return;
    }
    final from = _volume;
    final steps = (seconds * 20).ceil().clamp(1, 200);
    var i = 0;
    _fade = Timer.periodic(const Duration(milliseconds: 50), (t) {
      i++;
      _volume = from + (target - from) * (i / steps);
      p.setVolume(_volume.clamp(0.0, 1.0)).catchError((_) {});
      if (i >= steps) {
        t.cancel();
        done?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pornirea/oprirea din setări (de pe tabletă sau venită prin plan) și modul calm.
    ref.listen(settingsProvider.select((s) => (s.music, s.musicTrack, s.calm)), (_, _) => _update());
    return widget.child;
  }
}
