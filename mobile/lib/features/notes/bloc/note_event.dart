import 'package:equatable/equatable.dart';
import 'package:field_notes/features/notes/data/note_status.dart';


sealed class NoteEvent extends Equatable {
  const NoteEvent();

  @override
  List<Object?> get props => [];
}

class NotesLoaded extends NoteEvent {
  const NotesLoaded();
}

class NoteSearchChanged extends NoteEvent {
  const NoteSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class NoteStatusFilterChanged extends NoteEvent {
  const NoteStatusFilterChanged(this.status);

  final NoteStatus? status; // null = all

  @override
  List<Object?> get props => [status];
}

class NoteSiteFilterChanged extends NoteEvent {
  const NoteSiteFilterChanged(this.siteId);

  final String? siteId; // null = all

  @override
  List<Object?> get props => [siteId];
}

class NoteFiltersCleared extends NoteEvent {
  const NoteFiltersCleared();
}

class NoteSaved extends NoteEvent {
  const NoteSaved({
    this.id,
    required this.siteId,
    required this.title,
    this.description,
    this.latitude,
    this.longitude,
    required this.notedAt,
    required this.status,
    required this.photoChanged,
    this.photoSourcePath,
  });

  final String? id; // null = create
  final String siteId;
  final String title;
  final String? description;
  final double? latitude;
  final double? longitude;
  final DateTime notedAt;
  final NoteStatus status;
  final bool photoChanged;
  final String? photoSourcePath;

  @override
  List<Object?> get props => [
    id, siteId, title, description, latitude, longitude,
    notedAt, status, photoChanged, photoSourcePath,
  ];
}

class NoteDeleted extends NoteEvent {
  const NoteDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}