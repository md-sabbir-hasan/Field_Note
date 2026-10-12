import 'package:equatable/equatable.dart';
import 'package:field_notes/features/notes/data/note_status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState extends Equatable {
  const SettingsState({required this.defaultStatus});

  final NoteStatus defaultStatus;

  @override
  List<Object?> get props => [defaultStatus];
}

/// Local-only preferences. Never synced with the backend (task requirement).
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(SharedPreferences prefs)
      : _prefs = prefs,
        super(SettingsState(defaultStatus: _read(prefs)));

  static const _defaultStatusKey = 'default_note_status';

  final SharedPreferences _prefs;

  // Falls back to Open on first launch.
  static NoteStatus _read(SharedPreferences prefs) =>
      NoteStatus.fromApi(prefs.getString(_defaultStatusKey));

  Future<void> setDefaultStatus(NoteStatus status) async {
    await _prefs.setString(_defaultStatusKey, status.apiValue);
    emit(SettingsState(defaultStatus: status));
  }
}