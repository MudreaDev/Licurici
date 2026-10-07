import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:licurici_core/licurici_core.dart';

/// Adresa API-ului (`--dart-define=API_URL=…`); implicit backend-ul local (README §18).
const apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000/api/v1',
);

/// Versiunea politicii de confidențialitate acceptate (dovada consimțământului, GDPR art. 7).
const privacyPolicyVersion = '2026-10';

class ApiException implements Exception {
  const ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}

/// Clientul REST al panoului (README §12). Tokenurile stau doar în memorie (fără
/// localStorage: un XSS nu le poate fura după reîncărcare); la 401 încearcă o dată refresh.
class ApiClient {
  ApiClient({http.Client? client, this.baseUrl = apiUrl})
    : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  String? _access;
  String? _refresh;

  bool get signedIn => _access != null;

  Future<void> login(String email, String password) async {
    final r = await _send(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );
    _store(r as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final refresh = _refresh;
    _access = _refresh = null;
    if (refresh != null) {
      await _send(
        'POST',
        '/auth/logout',
        body: {'refreshToken': refresh},
        auth: false,
      ).catchError((_) => null);
    }
  }

  /// Copiii (ai părintelui sau partajați cu specialistul), fiecare cu sesiunile sincronizate.
  Future<List<ChildHistory>> children() async {
    final kids = (await _send('GET', '/children')) as List;
    return [
      for (final k in kids.cast<Map<String, dynamic>>())
        _history(
          k,
          (await _send('GET', '/children/${k['id']}/sessions')) as List,
        ),
    ];
  }

  /// Consimțămintele părintelui: scop → acordat (README §13).
  Future<Map<String, bool>> consents() async =>
      ((await _send('GET', '/consents')) as Map).cast<String, bool>();

  Future<Map<String, bool>> setConsent(String purpose, bool granted) async =>
      ((await _send(
                'POST',
                '/consents',
                body: {
                  'purpose': purpose,
                  'granted': granted,
                  'policyVersion': privacyPolicyVersion,
                },
              ))
              as Map)
          .cast<String, bool>();

  /// Copiii părintelui (fără sesiuni), pentru pagina de cont.
  Future<List<Map<String, dynamic>>> ownChildren() async =>
      ((await _send('GET', '/children')) as List).cast<Map<String, dynamic>>();

  Future<List<Map<String, dynamic>>> shares(String childId) async =>
      ((await _send('GET', '/children/$childId/share')) as List)
          .cast<Map<String, dynamic>>();

  Future<void> share(String childId, String email, {int days = 90}) => _send(
    'POST',
    '/children/$childId/share',
    body: {'email': email, 'days': days},
  );

  /// Exportul complet al datelor (GDPR art. 15, 20), ca text JSON.
  Future<String> exportData() async => const JsonEncoder.withIndent(
    '  ',
  ).convert(await _send('GET', '/me/export'));

  /// Ștergerea contului (GDPR art. 17): cere parola; întoarce data ștergerii definitive.
  Future<String> deleteAccount(String password) async =>
      ((await _send('POST', '/me/delete', body: {'password': password}))
              as Map)['purgeAt']
          as String;

  /// Ștergerea profilului copilului; întoarce data ștergerii definitive.
  Future<String> deleteChild(String childId) async =>
      ((await _send('DELETE', '/children/$childId')) as Map)['purgeAt']
          as String;

  Future<void> unshare(String childId, String therapistId) =>
      _send('DELETE', '/children/$childId/share/$therapistId');

  Future<Map<String, dynamic>> summary(
    String childId,
    String sessionId,
  ) async =>
      ((await _send('POST', '/children/$childId/sessions/$sessionId/summary'))
              as Map<String, dynamic>)['summary']
          as Map<String, dynamic>;

  ChildHistory _history(Map<String, dynamic> child, List sessions) {
    final records = [
      for (final s in sessions.cast<Map<String, dynamic>>())
        SessionRecord.fromJson((s['record'] as Map).cast<String, Object?>()),
    ];
    final base = importedChild(records, nickname: child['nickname'] as String);
    final birthYear = child['birthYear'] as int?;
    return ChildHistory(
      ChildProfile(
        id: child['id'] as String,
        nickname: base.child.nickname,
        ageYears: birthYear == null ? 0 : DateTime.now().year - birthYear,
        activeSteps: base.child.activeSteps,
        masteredSteps: base.child.masteredSteps,
      ),
      records,
    );
  }

  void _store(Map<String, dynamic> pair) {
    _access = pair['accessToken'] as String;
    _refresh = pair['refreshToken'] as String;
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
    bool retried = false,
  }) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['content-type'] = 'application/json';
    if (auth && _access != null) {
      req.headers['authorization'] = 'Bearer $_access';
    }
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _http.send(req));
    if (res.statusCode == 401 && auth && !retried && _refresh != null) {
      try {
        _store(
          (await _send(
                'POST',
                '/auth/refresh',
                body: {'refreshToken': _refresh},
                auth: false,
              ))
              as Map<String, dynamic>,
        );
      } on ApiException {
        _access = _refresh = null;
        rethrow;
      }
      return _send(method, path, body: body, retried: true);
    }
    final data = res.body.isEmpty
        ? null
        : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 400) {
      final msg = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Eroare ${res.statusCode}.';
      throw ApiException(res.statusCode, msg);
    }
    return data;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

/// Copiii de pe server după autentificare (gol = mod demo).
class ServerChildren extends Notifier<List<ChildHistory>> {
  @override
  List<ChildHistory> build() => const [];

  Future<void> signIn(String email, String password) async {
    final api = ref.read(apiClientProvider);
    await api.login(email, password);
    state = await api.children();
  }

  Future<void> signOut() async {
    await ref.read(apiClientProvider).logout();
    state = const [];
  }
}

final serverChildrenProvider =
    NotifierProvider<ServerChildren, List<ChildHistory>>(ServerChildren.new);

/// „Generează rezumat cu AI” (ADR-029): activ doar pentru copiii de pe server. Serverul verifică
/// accesul, consimțământul părintelui și limita zilnică; mesajele lui se arată ca atare.
class AiSummaryButton extends ConsumerWidget {
  const AiSummaryButton({super.key, required this.history});
  final ChildHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromServer = ref
        .watch(serverChildrenProvider)
        .any((h) => h.child.id == history.child.id);
    final latest = history.sessions.isEmpty ? null : history.sessions.last;
    if (!fromServer || latest == null) {
      return const Tooltip(
        message:
            'disponibil pentru copiii sincronizați, după autentificare și consimțământ',
        child: OutlinedButton(
          onPressed: null,
          child: Text('Generează rezumat cu AI'),
        ),
      );
    }
    return OutlinedButton(
      key: const ValueKey('ai-summary'),
      onPressed: () async {
        String title = 'Rezumat AI · ultima sesiune';
        Widget content;
        try {
          final s = await ref
              .read(apiClientProvider)
              .summary(history.child.id, latest.id);
          content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s['parent'] as String),
              const SizedBox(height: 8),
              Text('Idee pentru acasă: ${s['homeIdea']}'),
              const SizedBox(height: 12),
              for (final n in (s['specialist'] as List).cast<String>())
                Text('• $n'),
              for (final n in (s['planSuggestions'] as List).cast<String>())
                Text('→ $n'),
            ],
          );
        } on ApiException catch (e) {
          title = 'Rezumatul AI nu e disponibil';
          content = Text(
            '${e.message}\n\nRezumatul calculat din date rămâne mai jos.',
          );
        }
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(child: content),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Închide'),
              ),
            ],
          ),
        );
      },
      child: const Text('Generează rezumat cu AI'),
    );
  }
}
