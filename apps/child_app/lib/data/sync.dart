import 'dart:async';
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
  const SyncException(this.message, [this.status, this.needsTotp = false]);
  final String message;

  /// Parola e bună, dar contul are autentificarea în doi pași: trebuie și codul.
  final bool needsTotp;

  /// Codul HTTP (null = fără răspuns de la server).
  final int? status;

  /// Sesiunea păstrată nu mai e valabilă (parolă schimbată, cont șters, token expirat).
  bool get signedOut => status == 401;
  @override
  String toString() => message;
}

/// Trimiterea sesiunilor de pe tabletă pe server (ADR-011, outbox): doar cu contul părintelui și
/// cu consimțământul lui; doar sesiunile netrimise; marcate trimise abia după confirmarea
/// serverului (o cădere de rețea nu pierde nimic — se reîncearcă data viitoare, idempotent).
/// Implicit tokenurile nu se salvează pe dispozitiv: părintele se autentifică la fiecare
/// sincronizare. Dacă alege „trimite automat”, se păstrează doar refresh tokenul (rotit la
/// fiecare folosire, `onRefreshToken`), niciodată parola.
class SyncClient {
  SyncClient({http.Client? client, this.baseUrl = apiUrl})
    : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  String? _token;

  static const batchSize = 50;

  /// Rulează toată sincronizarea; întoarce câte sesiuni au fost trimise.
  ///
  /// Apoi planul de jocuri (plan §5.1): dacă pe server e o alegere mai nouă decât [plan]
  /// (făcută în panou de părinte sau de specialist), vine pe tabletă prin [onPlan]; dacă cea
  /// de pe tabletă e mai nouă, pleacă pe server. „Ultimul câștigă”, după dată (ADR-011).
  Future<int> run({
    required SessionStore store,
    String? email,
    String? password,
    String? code,
    String? refreshToken,
    FutureOr<void> Function(String refreshToken)? onRefreshToken,
    required bool consent,
    ({Set<String> hidden, DateTime? at})? plan,
    void Function(Set<String> hidden, Map<String, int> levels, DateTime at, Map<String, int> maxLevels)? onPlan,
  }) async {
    if (!consent) {
      throw const SyncException(
        'Bifează acordul pentru trimiterea sesiunilor.',
      );
    }
    _token = null;
    final pair = refreshToken != null
        ? await _call('POST', '/auth/refresh', {'refreshToken': refreshToken}) as Map
        : await _call('POST', '/auth/login', {'email': email, 'password': password, 'code': ?code}) as Map;
    _token = pair['accessToken'] as String;
    // Tokenul vechi nu mai merge: cel nou se salvează înainte de orice altă cerere.
    await onRefreshToken?.call(pair['refreshToken'] as String);
    // Acordul se dă (o dată, explicit) din fereastra „Trimite pe server”; la trimiterea
    // automată serverul verifică în continuare că nu a fost retras.
    if (refreshToken == null) {
      await _call('POST', '/consents', {
        'purpose': 'SYNC',
        'granted': true,
        'policyVersion': privacyPolicyVersion,
      });
    }
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
    if (plan != null) {
      try {
        await _syncPlan(childId, plan, onPlan);
      } on SyncException {
        // Planul e un bonus: sesiunile au plecat deja; încercăm iar la următoarea sincronizare.
      }
    }
    return payload.length;
  }

  /// „Se joacă acum”: anunță serverul că a început o sesiune (doar cu trimiterea automată).
  Future<void> announcePlaying({
    required String refreshToken,
    required FutureOr<void> Function(String) onRefreshToken,
  }) async {
    _token = null;
    final pair = await _call('POST', '/auth/refresh', {'refreshToken': refreshToken}) as Map;
    _token = pair['accessToken'] as String;
    await onRefreshToken(pair['refreshToken'] as String);
    final kids = await _call('GET', '/children') as List;
    if (kids.isEmpty) return;
    await _call('POST', '/children/${(kids.first as Map)['id']}/presence');
  }

  Future<void> _syncPlan(
    String childId,
    ({Set<String> hidden, DateTime? at}) local,
    void Function(Set<String> hidden, Map<String, int> levels, DateTime at, Map<String, int> maxLevels)? onPlan,
  ) async {
    final server = await _call('GET', '/children/$childId/plan') as Map;
    final at = DateTime.tryParse(server['updatedAt'] as String? ?? '');
    final hidden = {for (final g in (server['hiddenGames'] as List? ?? const [])) g as String};
    Map<String, int> numbers(Object? raw) => {
      for (final MapEntry(:key, :value) in ((raw as Map?) ?? const {}).entries)
        if (key is String && value is num) key: value.toInt(),
    };
    final levels = numbers(server['levels']);
    final maxLevels = numbers(server['maxLevels']);
    if (at != null && (local.at == null || at.isAfter(local.at!))) {
      onPlan?.call(hidden, levels, at, maxLevels);
    } else if (local.at != null && (at == null || local.at!.isAfter(at))) {
      // Nivelurile de pornire și plafoanele le alege specialistul în panou: rămân cele de pe server.
      await _call('PUT', '/children/$childId/plan', {
        'hiddenGames': (local.hidden.toList()..sort()),
        'levels': levels,
        'maxLevels': maxLevels,
      });
    }
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
        res.statusCode,
        res.statusCode == 401 && data is Map && (data['details'] as List?)?.contains('totp') == true,
      );
    }
    return data;
  }
}
