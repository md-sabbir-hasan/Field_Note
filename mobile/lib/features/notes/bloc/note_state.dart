import 'package:equatable/equatable.dart';
import 'package:field_notes/features/notes/data/note.dart';
import 'package:field_notes/features/notes/data/note_filter.dart';


enum NoteLoadStatus { loading, ready, failure }

class NoteState extends Equatable {
  const NoteState({
    this.status = NoteLoadStatus.loading,
    this.notes = const [],
    this.filter = const NoteFilter(),
    this.message,
  });

  final NoteLoadStatus status;
  final List<Note> notes;
  final NoteFilter filter;

  /// One-shot snackbar text. Every copyWith resets it unless a new one is given.
  final String? message;

  NoteState copyWith({
    NoteLoadStatus? status,
    List<Note>? notes,
    NoteFilter? filter,
    String? message,
  }) {
    return NoteState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      filter: filter ?? this.filter,
      message: message,
    );
  }

  @override
  List<Object?> get props => [status, notes, filter, message];
}