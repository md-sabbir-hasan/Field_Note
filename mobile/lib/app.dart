import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/ui/login_page.dart';

class FieldNotesApp extends StatelessWidget {
  const FieldNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          switch (state.status) {
            case AuthStatus.unknown:
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            case AuthStatus.authenticated:
              return const _HomePlaceholder();
            case AuthStatus.unauthenticated:
              return const LoginPage();
          }
        },
      ),
    );
  }
}

/// Temporary screen, replaced by the real Home (customers / notes) in the next step.
class _HomePlaceholder extends StatelessWidget {
  const _HomePlaceholder();

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    return Scaffold(
      appBar: AppBar(title: const Text('Field Notes')),
      body: Center(child: Text('Logged in as ${user?.email}')),
    );
  }
}