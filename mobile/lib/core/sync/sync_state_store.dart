import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the server time of the last successful pull, for one user.
/// It must be cleared whenever local data is wiped, otherwise a fresh login
/// would skip the restore.
class SyncStateStore {
  SyncStateStore(this._prefs);

  final SharedPreferences _prefs;

  static const _userKey = 'sync_user_id';
  static const _timeKey = 'sync_server_time';

  /// The raw ISO string from the server, or null when a full pull is needed.
  String? read(int userId) {
    if (_prefs.getInt(_userKey) != userId) return null;
    return _prefs.getString(_timeKey);
  }

  Future<void> write(int userId, String serverTime) async {
    await _prefs.setInt(_userKey, userId);
    await _prefs.setString(_timeKey, serverTime);
  }

  Future<void> clear() async {
    await _prefs.remove(_userKey);
    await _prefs.remove(_timeKey);
  }
}