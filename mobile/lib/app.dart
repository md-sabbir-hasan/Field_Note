import 'package:field_notes/core/database/app_database.dart';
import 'package:field_notes/features/auth/bloc/auth_event.dart';
import 'package:field_notes/features/customers/bloc/customer_bloc.dart';
import 'package:field_notes/features/customers/bloc/customer_event.dart';
import 'package:field_notes/features/customers/data/customer_local_data_source.dart';
import 'package:field_notes/features/customers/data/customer_repository.dart';
import 'package:field_notes/features/customers/ui/customer_list_page.dart';
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
              return const _CustomersEntry();
            case AuthStatus.unauthenticated:
              return const LoginPage();
          }
        },
      ),
    );
  }
}

/// Temporary screen, replaced by the real Home (customers / notes) in the next step.
/// Temporary entry: customers screen plus a logout button for testing.
class _CustomersEntry extends StatelessWidget {
  const _CustomersEntry();

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user)!;
    final database = AppDatabase.instance;
    final repository = CustomerRepository(CustomerLocalDataSource(database));

    return BlocProvider(
      // New bloc per user, so one account never sees another's list.
      key: ValueKey(user.id),
      create: (_) => CustomerBloc(repository, userId: user.id)..add(const CustomersLoaded()),
      child: Stack(
        children: [
          const CustomerListPage(),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout),
                onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}