import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/sync/sync_service.dart';
import 'sync_state.dart';

/// Decides WHEN to sync. The actual work is in [SyncService].
class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required SyncService service,
    required int userId,
    required Stream<void> localChanges,
    Connectivity? connectivity,
  })  : _service = service,
        _userId = userId,
        _localChanges = localChanges,
        _connectivity = connectivity ?? Connectivity(),
        super(const SyncState());

  final SyncService _service;
  final int _userId;
  final Stream<void> _localChanges;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<void>? _changesSub;
  Timer? _debounce;
  Timer? _periodic;

  Future<void>? _current; // the run in progress, if any
  bool _rerun = false; // something changed while a run was going

  void start() {
    // Net came back: sync.
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) _schedule(const Duration(seconds: 2));
    });

    // The user changed something: show the pending count now, sync shortly after.
    _changesSub = _localChanges.listen((_) {
      _refreshPending();
      _schedule(const Duration(milliseconds: 1500));
    });

    // Pick up changes made on other devices.
    _periodic = Timer.periodic(const Duration(minutes: 2), (_) => syncNow());

    _refreshPending();
    _schedule(const Duration(milliseconds: 500));
  }

  void _schedule(Duration delay) {
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  /// Safe to call at any time. Returns when the run (current or new) is finished.
  Future<void> syncNow() {
    final running = _current;
    if (running != null) {
      _rerun = true;
      return running;
    }
    return _current = _run();
  }

  Future<int> pendingCount() => _service.pendingCount(_userId);

  Future<void> _run() async {
    try {
      do {
        _rerun = false;
        await _syncOnce();
      } while (_rerun && !isClosed);
    } finally {
      _current = null;
    }
  }

  Future<void> _syncOnce() async {
    _safeEmit(state.copyWith(phase: SyncPhase.syncing, clearError: true));

    try {
      final report = await _service.sync(_userId);
      final pending = await _service.pendingCount(_userId);
      _safeEmit(state.copyWith(
        phase: SyncPhase.synced,
        lastSyncedAt: DateTime.now(),
        pendingCount: pending,
        problemCount: report.problems,
        runs: state.runs + 1,
        clearError: true,
      ));
    } on ApiException catch (e) {
      _rerun = false; // do not retry in a tight loop
      final pending = await _service.pendingCount(_userId);
      _safeEmit(state.copyWith(
        phase: e.isOffline ? SyncPhase.offline : SyncPhase.failed,
        pendingCount: pending,
        runs: state.runs + 1, // part of the work may have succeeded
        errorMessage: e.isOffline ? null : e.message,
        clearError: e.isOffline,
      ));
    } catch (_) {
      _rerun = false;
      _safeEmit(state.copyWith(
        phase: SyncPhase.failed,
        runs: state.runs + 1,
        errorMessage: 'Sync failed',
      ));
    }
  }

  Future<void> _refreshPending() async {
    final pending = await _service.pendingCount(_userId);
    _safeEmit(state.copyWith(pendingCount: pending));
  }

  // The user can log out in the middle of a run; emitting after close would throw.
  void _safeEmit(SyncState s) {
    if (!isClosed) emit(s);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _periodic?.cancel();
    _connectivitySub?.cancel();
    _changesSub?.cancel();
    return super.close();
  }
}