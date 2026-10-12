import 'package:equatable/equatable.dart';

import 'note_status.dart';

/// Search text plus the two filters, kept together so they combine.
class NoteFilter extends Equatable {
  const NoteFilter({this.query = '', this.status, this.siteId});

  final String query;
  final NoteStatus? status;
  final String? siteId;

  bool get isActive => query.trim().isNotEmpty || status != null || siteId != null;

  NoteFilter withQuery(String q) => NoteFilter(query: q, status: status, siteId: siteId);
  NoteFilter withStatus(NoteStatus? s) => NoteFilter(query: query, status: s, siteId: siteId);
  NoteFilter withSite(String? id) => NoteFilter(query: query, status: status, siteId: id);

  @override
  List<Object?> get props => [query, status, siteId];
}