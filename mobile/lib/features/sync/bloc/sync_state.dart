import 'package:equatable/equatable.dart';

enum SyncPhase { idle, syncing, synced, offline, failed }

class SyncState extends Equatable {
  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.problemCount = 0,
    this.runs = 0,
    this.errorMessage,
  });

  final SyncPhase phase;
  final DateTime? lastSyncedAt;

  /// Local changes (and photos) that are not on the server yet.
  final int pendingCount;

  /// Records the server refused in the last run.
  final int problemCount;

  /// Counts finished runs, so the UI can reload lists after every run.
  final int runs;

  final String? errorMessage;

  SyncState copyWith({
    SyncPhase? phase,
    DateTime? lastSyncedAt,
    int? pendingCount,
    int? problemCount,
    int? runs,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncState(
      phase: phase ?? this.phase,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingCount: pendingCount ?? this.pendingCount,
      problemCount: problemCount ?? this.problemCount,
      runs: runs ?? this.runs,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [phase, lastSyncedAt, pendingCount, problemCount, runs, errorMessage];
}