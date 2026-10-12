import 'package:field_notes/core/database/app_database.dart';
import 'package:field_notes/core/network/api_client.dart';
import 'package:field_notes/core/storage/photo_store.dart';
import 'package:field_notes/core/sync/local_change_notifier.dart';
import 'package:field_notes/core/sync/sync_local_data_source.dart';
import 'package:field_notes/core/sync/sync_service.dart';
import 'package:field_notes/core/sync/sync_state_store.dart';
import 'package:field_notes/features/auth/data/auth_user.dart';
import 'package:field_notes/features/customers/bloc/customer_bloc.dart';
import 'package:field_notes/features/customers/bloc/customer_event.dart';
import 'package:field_notes/features/customers/data/customer_local_data_source.dart';
import 'package:field_notes/features/customers/data/customer_repository.dart';
import 'package:field_notes/features/customers/ui/customer_list_page.dart';
import 'package:field_notes/features/notes/bloc/note_bloc.dart';
import 'package:field_notes/features/notes/bloc/note_event.dart';
import 'package:field_notes/features/notes/data/note_local_data_source.dart';
import 'package:field_notes/features/notes/data/note_repository.dart';
import 'package:field_notes/features/notes/ui/note_list_page.dart';
import 'package:field_notes/features/settings/ui/settings_page.dart';
import 'package:field_notes/features/sites/bloc/site_bloc.dart';
import 'package:field_notes/features/sites/bloc/site_event.dart';
import 'package:field_notes/features/sites/data/site_local_data_source.dart';
import 'package:field_notes/features/sites/data/site_repository.dart';
import 'package:field_notes/features/sites/ui/site_list_page.dart';
import 'package:field_notes/features/sync/bloc/sync_cubit.dart';
import 'package:field_notes/features/sync/bloc/sync_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.user});

  final AuthUser user;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final LocalChangeNotifier _changes;
  late final CustomerRepository _customers;
  late final SiteRepository _sites;
  late final NoteRepository _notes;
  late final SyncCubit _sync;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    final db = AppDatabase.instance;
    final photos = PhotoStore();

    _changes = LocalChangeNotifier();
    _customers = CustomerRepository(CustomerLocalDataSource(db), _changes);
    _sites = SiteRepository(SiteLocalDataSource(db), _changes);
    _notes = NoteRepository(NoteLocalDataSource(db), photos, _changes);

    _sync = SyncCubit(
      service: SyncService(
        api: context.read<ApiClient>(),
        local: SyncLocalDataSource(db),
        state: context.read<SyncStateStore>(),
        photos: photos,
      ),
      userId: widget.user.id,
      localChanges: _changes.stream,
    )..start();
  }

  @override
  void dispose() {
    _sync.close();
    _changes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.user.id;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (_) => CustomerBloc(_customers, userId: userId)..add(const CustomersLoaded())),
        BlocProvider(create: (_) => SiteBloc(_sites, userId: userId)..add(const SitesLoaded())),
        BlocProvider(create: (_) => NoteBloc(_notes, userId: userId)..add(const NotesLoaded())),
        BlocProvider.value(value: _sync),
      ],
      child: BlocListener<SyncCubit, SyncState>(
        // After every sync run the lists are read again from SQLite.
        listenWhen: (p, c) => p.runs != c.runs,
        listener: (context, _) {
          context.read<CustomerBloc>().add(const CustomersLoaded());
          context.read<SiteBloc>().add(const SitesLoaded());
          context.read<NoteBloc>().add(const NotesLoaded());
        },
        child: Builder(
          builder: (context) => Scaffold(
            body: IndexedStack(
              index: _index,
              children: [
                NoteListPage(siteRepository: _sites, userId: userId),
                SiteListPage(customerRepository: _customers, userId: userId),
                const CustomerListPage(),
                const SettingsPage(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) {
                setState(() => _index = i);
                // Parents may have been renamed or deleted: refresh dependent lists.
                if (i == 0) context.read<NoteBloc>().add(const NotesLoaded());
                if (i == 1) context.read<SiteBloc>().add(const SitesLoaded());
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.note_alt_outlined), label: 'Notes'),
                NavigationDestination(icon: Icon(Icons.location_city_outlined), label: 'Sites'),
                NavigationDestination(icon: Icon(Icons.people_outline), label: 'Customers'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}