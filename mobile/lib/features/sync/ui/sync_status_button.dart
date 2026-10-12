import 'package:field_notes/features/sync/bloc/sync_cubit.dart';
import 'package:field_notes/features/sync/bloc/sync_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


/// AppBar icon that shows the sync state and syncs on tap.
class SyncStatusButton extends StatelessWidget {
  const SyncStatusButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SyncCubit>().state;

    if (state.phase == SyncPhase.syncing) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final waiting = state.pendingCount;
    final (icon, tooltip) = switch (state.phase) {
      SyncPhase.offline => (
      Icons.cloud_off_outlined,
      waiting > 0 ? 'Offline: $waiting waiting to sync' : 'Offline'
      ),
      SyncPhase.failed => (Icons.sync_problem_outlined, state.errorMessage ?? 'Sync failed'),
      _ when waiting > 0 => (Icons.cloud_upload_outlined, '$waiting waiting to sync'),
      _ => (Icons.cloud_done_outlined, 'All changes synced'),
    };

    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: () => context.read<SyncCubit>().syncNow(),
    );
  }
}