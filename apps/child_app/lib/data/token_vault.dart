import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Locul refresh tokenului pentru sincronizarea automată (ADR-011, ADR-004): doar dacă
/// părintele a ales „trimite automat”. Parola nu se păstrează niciodată; tokenul se rotește la
/// fiecare folosire și se poate anula din tabletă sau schimbând parola contului.
abstract class TokenVault {
  Future<String?> read();

  /// null = șterge (sincronizarea automată oprită).
  Future<void> write(String? token);
}

class MemoryTokenVault implements TokenVault {
  MemoryTokenVault([this._token]);
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String? token) async => _token = token;
}

/// Keystore (Android) / Keychain (iOS) / DPAPI (Windows).
class SecureTokenVault implements TokenVault {
  static const _key = 'licurici.sync.refresh';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? token) =>
      token == null ? _storage.delete(key: _key) : _storage.write(key: _key, value: token);
}

/// Implicit în memorie (teste, web); pe dispozitiv `main.dart` pune `SecureTokenVault`.
final tokenVaultProvider = Provider<TokenVault>((ref) => MemoryTokenVault());
