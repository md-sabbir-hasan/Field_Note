enum NoteStatus {
  open('OPEN', 'Open'),
  inProgress('IN_PROGRESS', 'In progress'),
  done('DONE', 'Done');

  const NoteStatus(this.apiValue, this.label);

  /// The exact string the backend and SQLite use.
  final String apiValue;
  final String label;

  static NoteStatus fromApi(String? value) => NoteStatus.values
      .firstWhere((s) => s.apiValue == value, orElse: () => NoteStatus.open);
}