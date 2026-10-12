import 'package:field_notes/features/notes/data/note_filter.dart';
import 'package:field_notes/features/notes/data/note_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'note_event.dart';
import 'note_state.dart';

class NoteBloc extends Bloc<NoteEvent, NoteState> {
  NoteBloc(this._repository, {required this.userId}) : super(const NoteState()) {
    on<NotesLoaded>((e, emit) => _load(emit, state.filter));
    on<NoteSearchChanged>((e, emit) => _load(emit, state.filter.withQuery(e.query)));
    on<NoteStatusFilterChanged>((e, emit) => _load(emit, state.filter.withStatus(e.status)));
    on<NoteSiteFilterChanged>((e, emit) => _load(emit, state.filter.withSite(e.siteId)));
    on<NoteFiltersCleared>((e, emit) => _load(emit, const NoteFilter()));
    on<NoteSaved>(_onSaved);
    on<NoteDeleted>(_onDeleted);
  }

  final NoteRepository _repository;
  final int userId;

  /// Reads the list for [filter] from SQLite and emits it.
  Future<void> _load(Emitter<NoteState> emit, NoteFilter filter, {String? message}) async {
    try {
      final list = await _repository.list(
        userId,
        query: filter.query,
        status: filter.status,
        siteId: filter.siteId,
      );
      emit(NoteState(
        status: NoteLoadStatus.ready,
        notes: list,
        filter: filter,
        message: message,
      ));
    } catch (_) {
      emit(state.copyWith(status: NoteLoadStatus.failure, filter: filter));
    }
  }

  Future<void> _onSaved(NoteSaved event, Emitter<NoteState> emit) async {
    try {
      await _repository.save(
        userId: userId,
        id: event.id,
        siteId: event.siteId,
        title: event.title,
        description: event.description,
        latitude: event.latitude,
        longitude: event.longitude,
        notedAt: event.notedAt,
        status: event.status,
        photoChanged: event.photoChanged,
        photoSourcePath: event.photoSourcePath,
      );
    } catch (_) {
      emit(state.copyWith(message: 'Could not save note'));
      return;
    }
    await _load(emit, state.filter,
        message: event.id == null ? 'Note created' : 'Note updated');
  }

  Future<void> _onDeleted(NoteDeleted event, Emitter<NoteState> emit) async {
    try {
      await _repository.delete(userId, event.id);
    } catch (_) {
      emit(state.copyWith(message: 'Could not delete note'));
      return;
    }
    await _load(emit, state.filter, message: 'Note deleted');
  }
}