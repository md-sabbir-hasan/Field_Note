import 'package:dio/dio.dart';
import 'package:field_notes/core/database/app_database.dart';
import 'package:field_notes/core/network/api_client.dart';
import 'package:field_notes/core/network/api_exception.dart';
import 'package:field_notes/core/network/token_storage.dart';
import 'auth_user.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokenStorage, this._database);

  final ApiClient _api;
  final TokenStorage _tokenStorage;
  final AppDatabase _database;

  /// Returns the stored user if a token exists. Works offline: no server call.
  Future<AuthUser?> restoreSession() async {
    final token = await _tokenStorage.token;
    final id = await _tokenStorage.userId;
    final name = await _tokenStorage.name;
    final email = await _tokenStorage.email;
    if (token == null || id == null || name == null || email == null) return null;
    return AuthUser(id: id, name: name, email: email);
  }

  Future<AuthUser> login({required String email, required String password}) {
    return _authenticate('/api/auth/login', {'email': email, 'password': password});
  }

  Future<AuthUser> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _authenticate(
        '/api/auth/register', {'name': name, 'email': email, 'password': password});
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    await _database.clearAll();
  }

  /// Drops only the token. Local data stays so offline work is not lost.
  Future<void> expireSession() async {
    await _tokenStorage.clearToken();
  }

  Future<AuthUser> _authenticate(String path, Map<String, dynamic> body) async {
    try {
      final response = await _api.dio.post(path, data: body);
      final data = response.data as Map<String, dynamic>;

      final user = AuthUser(
        id: (data['userId'] as num).toInt(),
        name: data['name'] as String,
        email: data['email'] as String,
      );

      // A different account on the same phone must never see the previous user's data.
      final previousId = await _tokenStorage.userId;
      if (previousId != null && previousId != user.id) {
        await _database.clearAll();
      }

      await _tokenStorage.save(
        token: data['token'] as String,
        userId: user.id,
        name: user.name,
        email: user.email,
      );
      return user;
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }
}