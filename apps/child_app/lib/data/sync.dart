import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:licurici_core/licurici_core.dart';

import 'session.dart';

/// Adresa API-ului (`--dart-define=API_URL=…`, README §18).
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000/api/v1',
);

/// Versiunea politicii de confidențialitate acceptate la sincronizare (dovada consimțământului).
const privacyPolicyVersion = '2026-10';

class SyncException implements Exception {
  const SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Trimiterea sesiunilor de pe tabletă pe server (ADR-011, outbox): doar cu contul părintelui și
/// cu consimțământul lui; doar sesiunile netrimise; marcate trimise abia după confirmarea
/// serverului (o cădere de rețea nu pierde nimic — se reîncearcă data viitoare, idempotent).
/// Tokenurile nu se salvează pe dispozitiv: părintele se autentifică la fiecare sincronizare.
class SyncClient {
  SyncClient({http.Client? client, this.baseUrl = apiUrl})
    : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  String? _token;

  static const batchSize = 50;

  /// Rulează toată sincronizarea; întoarce câte sesiuni au fost trimise.
  Future<int> run({
    required SessionStore store,
    required String email,
    required String password,
    required bool consent,
  }) async {
    if (!consent) {
      throw const SyncException(
        'Bifează acordul pentru trimiterea sesiunilor.',
      );
    }
    final login =
        await _call('POST', '/auth/login', {
              'email': email,
              'password': password,
            })
            as Map;
    _token = login['accessToken'] as String;
    await _call('POST', '/consents', {
      'purpose': 'SYNC',
      'granted': true,
      'policyVersion': privacyPolicyVersion,
    });
    final childId = await _childId();

    final all = await store.all();
    final pending = (await store.unsyncedIds()).toSet();
    // Faptele (KPI) se calculează aici, cu sesiunea anterioară pentru comparație — aceeași
    // implementare ca în panou și în rapoarte (licurici_core).
    final payload = <Map<String, Object?>>[];
    SessionReport? previous;
    for (final r in all) {
      final report = SessionReport.from(r, previous: previous);
      previous = report;
      if (pending.contains(r.id)) {
        payload.add({'record': r.toJson(), 'facts': report.toAiJson()});
      }
    }
    for (var i = 0; i < payload.length; i += batchSize) {
      final batch = payload.sublist(
        i,
        (i + batchSize).clamp(0, payload.length),
      );
      await _call('POST', '/children/$childId/sessions', {'sessions': batch});
      await store.markSynced([
        for (final p in batch) (p['record']! as Map)['id'] as String,
      ]);
    }
    return payload.length;
  }

  /// Primul copil al părintelui; dacă nu are, se creează profilul (doar o poreclă implicită).
  Future<String> _childId() async {
    final kids = await _call('GET', '/children') as List;
    if (kids.isNotEmpty) return (kids.first as Map)['id'] as String;
    final created =
        await _call('POST', '/children', {'nickname': 'Copilul meu'}) as Map;
    return created['id'] as String;
  }

  Future<Object?> _call(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['content-type'] = 'application/json';
    if (_token != null) req.headers['authorization'] = 'Bearer $_token';
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req));
    } on Object {
      throw const SyncException(
        'Serverul nu răspunde. Verifică internetul și încearcă din nou.',
      );
    }
    final data = res.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      throw SyncException(
        data is Map && data['message'] is String
            ? data['message'] as String
            : 'Eroare ${res.statusCode}.',
      );
    }
    return data;
  }
}
