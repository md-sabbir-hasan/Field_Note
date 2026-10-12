import 'package:field_notes/features/auth/bloc/auth_bloc.dart';
import 'package:field_notes/features/auth/bloc/auth_event.dart';
import 'package:field_notes/features/notes/data/note_status.dart';
import 'package:field_notes/features/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'Data on this phone that is not synced yet will be lost. You can sign in again to restore synced data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<AuthBloc>().add(const AuthLogoutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc b) => b.state.user);
    final selected = context.watch<SettingsCubit>().state.defaultStatus;

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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Default note status',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}