import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api.dart';

/// Canalul live al panoului (ADR-010): Socket.IO pe `/api/v1/live`. Panoul urmărește copiii pe
/// care îi vede și primește `session.synced` / `plan.changed` (doar id-uri și numere).
abstract class LiveChannel {
  void open({
    required Future<String?> Function() token,
    required Iterable<String> childIds,
    required void Function(String type, Map<String, dynamic> data) onEvent,
  });

  void close();
}

class SocketLiveChannel implements LiveChannel {
  SocketLiveChannel({this.baseUrl = apiUrl});

  final String baseUrl;
  io.Socket? _socket;

  @override
  void open({
    required Future<String?> Function() token,
    required Iterable<String> childIds,
    required void Function(String type, Map<String, dynamic> data) onEvent,
  }) {
    close();
    final ids = childIds.toList();
    if (ids.isEmpty) return;
    final origin = Uri.parse(baseUrl).replace(path: '').toString();
    final socket = io.io(
      origin,
      io.OptionBuilder().setPath('/api/v1/live').setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket = socket;
    Future<void> connect() async {
      final t = await token();
      if (t == null || !identical(_socket, socket)) return;
      socket
        ..auth = {'token': t}
        ..connect();
    }

    socket.onConnect((_) {
      for (final id in ids) {
        // Răspunsul spune și dacă copilul se joacă chiar acum.
        socket.emitWithAck(
          'watch',
          {'childId': id},
          ack: (res) {
            if (res is Map && res['ok'] == true) onEvent('presence', {'childId': id, 'playing': res['playing'] == true});
          },
        );
      }
    });
    // Serverul închide conexiunea când tokenul de acces (15 min) a expirat: luăm unul nou.
    socket.onDisconnect((reason) {
      if (reason == 'io server disconnect') Future<void>.delayed(const Duration(seconds: 2), connect);
    });
    for (final type in ['session.synced', 'plan.changed', 'presence']) {
      socket.on(type, (data) {
        if (data is Map) onEvent(type, data.cast<String, dynamic>());
      });
    }
    connect();
  }

  @override
  void close() {
    _socket?.dispose();
    _socket = null;
  }
}

/// Pe Vercel (versiunea de test) nu există WebSocket: panoul întreabă la 30 s lista copiilor și
/// anunță singur o sincronizare nouă sau „Se joacă acum” (`--dart-define=LIVE_POLL=true`).
const livePolling = bool.fromEnvironment('LIVE_POLL');

class PollingLiveChannel implements LiveChannel {
  PollingLiveChannel(this.api, {this.every = const Duration(seconds: 30)});

  final ApiClient api;
  final Duration every;
  Timer? _timer;
  final _lastSync = <String, String?>{};
  final _playing = <String, bool>{};

  @override
  void open({
    required Future<String?> Function() token,
    required Iterable<String> childIds,
    required void Function(String type, Map<String, dynamic> data) onEvent,
  }) {
    close();
    var first = true;
    Future<void> poll() async {
      try {
        final kids = await api.rawChildren();
        for (final k in kids) {
          final id = k['id'] as String;
          final sync = k['lastSyncAt'] as String?;
          final playing = k['playingSince'] != null;
          if (!first && sync != null && sync != _lastSync[id]) onEvent('session.synced', {'childId': id, 'count': 1});
          if (_playing[id] != playing) onEvent('presence', {'childId': id, 'playing': playing});
          _lastSync[id] = sync;
          _playing[id] = playing;
        }
        first = false;
      } on Object {
        // Fără rețea sau deconectat: încercăm la următorul pas.
      }
    }

    unawaited(poll());
    _timer = Timer.periodic(every, (_) => poll());
  }

  @override
  void close() {
    _timer?.cancel();
    _timer = null;
  }
}

final liveChannelProvider = Provider<LiveChannel>((ref) {
  final LiveChannel channel = livePolling ? PollingLiveChannel(ref.read(apiClientProvider)) : SocketLiveChannel();
  ref.onDispose(channel.close);
  return channel;
});

/// Ultima veste live pentru adult (ex. „Sesiune nouă: Ilinca”); panoul o arată ca notificare.
/// Numărul face fiecare veste nouă, chiar dacă textul se repetă.
class LiveNotice extends Notifier<({String text, int n})?> {
  @override
  ({String text, int n})? build() => null;

  void show(String text) => state = (text: text, n: (state?.n ?? 0) + 1);
}

final liveNoticeProvider = NotifierProvider<LiveNotice, ({String text, int n})?>(LiveNotice.new);

/// Copiii care se joacă acum (după canalul live).
class Playing extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void set(String childId, bool playing) =>
      state = playing ? {...state, childId} : ({...state}..remove(childId));
}

final playingProvider = NotifierProvider<Playing, Set<String>>(Playing.new);

/// Insigna „Se joacă acum”.
class PlayingBadge extends ConsumerWidget {
  const PlayingBadge({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(playingProvider).contains(childId)) return const SizedBox.shrink();
    return Chip(
      key: ValueKey('playing-$childId'),
      avatar: const Icon(Icons.sports_esports_rounded, size: 18, color: Color(0xFF2E7D4F)),
      label: const Text('Se joacă acum'),
      backgroundColor: const Color(0xFFE2F3E8),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
