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
        socket.emit('watch', {'childId': id});
      }
    });
    // Serverul închide conexiunea când tokenul de acces (15 min) a expirat: luăm unul nou.
    socket.onDisconnect((reason) {
      if (reason == 'io server disconnect') Future<void>.delayed(const Duration(seconds: 2), connect);
    });
    for (final type in ['session.synced', 'plan.changed']) {
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

final liveChannelProvider = Provider<LiveChannel>((ref) {
  final channel = SocketLiveChannel();
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
