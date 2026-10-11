import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the JWT and basic user info in the Android keystore backed storage.
class TokenStorage {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _nameKey = 'auth_name';
  static const _emailKey = 'auth_email';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> save({
    required String token,
    required int userId,
    required String name,
    required String email,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId.toString());
    await _storage.write(key: _nameKey, value: name);
    await _storage.write(key: _emailKey, value: email);
  }

  Future<String?> get token => _storage.read(key: _tokenKey);

  Future<int?> get userId async {
    final v = await _storage.read(key: _userIdKey);
    return v == null ? null : int.tryParse(v);
  }

  Future<String?> get name => _storage.read(key: _nameKey);
  Future<String?> get email => _storage.read(key: _emailKey);

  Future<void> clear() => _storage.deleteAll();

  /// Removes only the JWT; user id/name/email stay so the same user can log back in.
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}