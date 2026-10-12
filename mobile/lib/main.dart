import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_event.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/settings/bloc/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loaded once so the saved default status is available instantly after a restart.
  final prefs = await SharedPreferences.getInstance();

  // Plain constructor wiring, no DI package needed at this size.
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage);
  final database = AppDatabase.instance;
  final authRepository = AuthRepository(apiClient, tokenStorage, database);

  final authBloc = AuthBloc(authRepository)..add(const AuthStarted());

  // An expired token sends the user back to the login screen.
  apiClient.onUnauthorized = () => authBloc.add(const AuthSessionExpired());

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authBloc),
        BlocProvider(create: (_) => SettingsCubit(prefs)),
      ],
      child: const FieldNotesApp(),
    ),
  );
}