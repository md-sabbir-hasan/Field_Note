import 'package:field_notes/features/auth/bloc/auth_bloc.dart';
import 'package:field_notes/features/auth/bloc/auth_event.dart';
import 'package:field_notes/features/notes/data/note_status.dart';
import 'package:field_notes/features/settings/bloc/settings_cubit.dart';
import 'package:field_notes/features/sync/bloc/sync_cubit.dart';
import 'package:field_notes/features/sync/bloc/sync_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final sync = context.read<SyncCubit>();
    final auth = context.read<AuthBloc>();
    final navigator = Navigator.of(context, rootNavigator: true);

    // Push everything first so nothing is lost. Offline, this just fails fast.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 16),
              Expanded(child: Text('Syncing before log out...')),
            ],
          ),
        ),
      ),
    );
    await sync.syncNow();
    final pending = await sync.pendingCount();
    navigator.pop(); // close the progress dialog
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(pending > 0
            ? '$pending change${pending == 1 ? '' : 's'} could not be synced and will be lost if you log out.'
            : 'All your data is synced. You can sign in again to restore it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(pending > 0 ? 'Log out anyway' : 'Log out')),
        ],
      ),
    );
    if (ok == true) auth.add(const AuthLogoutRequested());
  }

  String _syncSubtitle(SyncState s) {
    final parts = <String>[
      switch (s.phase) {
        SyncPhase.syncing => 'Syncing...',
        SyncPhase.offline => 'Offline',
        SyncPhase.failed => s.errorMessage ?? 'Last sync failed',
        _ => s.lastSyncedAt == null
            ? 'Not synced yet'
            : 'Last synced ${DateFormat('d MMM, h:mm a').format(s.lastSyncedAt!)}',
      },
      if (s.pendingCount > 0) '${s.pendingCount} waiting',
      if (s.problemCount > 0) '${s.problemCount} could not be synced',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    final selected = context.watch<SettingsCubit>().state.defaultStatus;
    final sync = context.watch<SyncCubit>().state;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(user.name),
              subtitle: Text(user.email),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync now'),
            subtitle: Text(_syncSubtitle(sync)),
            onTap: sync.phase == SyncPhase.syncing
                ? null
                : () => context.read<SyncCubit>().syncNow(),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Default note status', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Used when you create a new field note.'),
          ),
          for (final s in NoteStatus.values)
            ListTile(
              title: Text(s.label),
              trailing: s == selected
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              selected: s == selected,
              onTap: () => context.read<SettingsCubit>().setDefaultStatus(s),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Log out'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}