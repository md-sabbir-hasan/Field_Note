import 'package:field_notes/core/database/app_database.dart';
import 'package:field_notes/features/auth/bloc/auth_event.dart';
import 'package:field_notes/features/customers/bloc/customer_bloc.dart';
import 'package:field_notes/features/customers/bloc/customer_event.dart';
import 'package:field_notes/features/customers/data/customer_local_data_source.dart';
import 'package:field_notes/features/customers/data/customer_repository.dart';
import 'package:field_notes/features/customers/ui/customer_list_page.dart';
import 'package:field_notes/features/sites/bloc/site_bloc.dart';
import 'package:field_notes/features/sites/bloc/site_event.dart';
import 'package:field_notes/features/sites/data/site_local_data_source.dart';
import 'package:field_notes/features/sites/data/site_repository.dart';
import 'package:field_notes/features/sites/ui/site_list_page.dart';
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
class _CustomersEntry extends StatefulWidget {
  const _CustomersEntry();

  @override
  State<_CustomersEntry> createState() => _CustomersEntryState();
}

class _CustomersEntryState extends State<_CustomersEntry> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user)!;
    final database = AppDatabase.instance;
    final customerRepository = CustomerRepository(CustomerLocalDataSource(database));
    final siteRepository = SiteRepository(SiteLocalDataSource(database));

    return MultiBlocProvider(
      // New blocs per user, so one account never sees another's data.
      key: ValueKey(user.id),
      providers: [
        BlocProvider(
          create: (_) =>
          CustomerBloc(customerRepository, userId: user.id)..add(const CustomersLoaded()),
        ),
        BlocProvider(
          create: (_) => SiteBloc(siteRepository, userId: user.id)..add(const SitesLoaded()),
        ),
      ],
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            const CustomerListPage(),
            SiteListPage(customerRepository: customerRepository, userId: user.id),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.people_outline), label: 'Customers'),
            NavigationDestination(icon: Icon(Icons.location_city_outlined), label: 'Sites'),
          ],
        ),
      ),
    );
  }
}