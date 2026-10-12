import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../settings/bloc/settings_cubit.dart';
import '../../sites/data/site.dart';
import '../../sites/data/site_repository.dart';
import '../bloc/note_bloc.dart';
import '../bloc/note_event.dart';
import '../bloc/note_state.dart';
import '../data/note.dart';
import '../data/note_status.dart';
import 'note_form_page.dart';

extension on NoteStatus {
  Color get color => switch (this) {
    NoteStatus.open => Colors.orange,
    NoteStatus.inProgress => Colors.blue,
    NoteStatus.done => Colors.green,
  };

  IconData get icon => switch (this) {
    NoteStatus.open => Icons.radio_button_unchecked,
    NoteStatus.inProgress => Icons.timelapse,
    NoteStatus.done => Icons.check_circle,
  };
}

class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key, required this.siteRepository, required this.userId});

  final SiteRepository siteRepository;
  final int userId;

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  static final _dateFormat = DateFormat('d MMM y, h:mm a');

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Wait until the user stops typing so we do not query on every key.
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<NoteBloc>().add(NoteSearchChanged(text));
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    context.read<NoteBloc>().add(const NoteFiltersCleared());
  }

  Future<bool> _confirmDelete(BuildContext context, Note n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('"${n.title}" will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _openForm(BuildContext context, {Note? note}) async {
    final bloc = context.read<NoteBloc>();
    final defaultStatus = context.read<SettingsCubit>().state.defaultStatus;
    final sites = await widget.siteRepository.list(widget.userId);
    if (!context.mounted) return;

    if (sites.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Add a site first')));
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: NoteFormPage(note: note, sites: sites, defaultStatus: defaultStatus),
      ),
    ));
  }

  Future<void> _pickSiteFilter(BuildContext context) async {
    final bloc = context.read<NoteBloc>();
    final sites = await widget.siteRepository.list(widget.userId);
    if (!context.mounted) return;

    final result = await showModalBottomSheet<_SiteFilterResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('All sites'),
              selected: bloc.state.filter.siteId == null,
              onTap: () => Navigator.pop(ctx, const _SiteFilterResult(null)),
            ),
            for (final Site s in sites)
              ListTile(
                title: Text(s.siteName),
                subtitle: Text(s.customerName),
                selected: bloc.state.filter.siteId == s.id,
                onTap: () => Navigator.pop(ctx, _SiteFilterResult(s.id)),
              ),
          ],
        ),
      ),
    );

    if (result != null) bloc.add(NoteSiteFilterChanged(result.siteId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NoteBloc, NoteState>(
      listenWhen: (p, c) => c.message != null && c.message != p.message,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
      },
      builder: (context, state) {
        final filter = state.filter;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Field Notes'),
            actions: [
              IconButton(
                tooltip: 'Filter by site',
                icon: Icon(filter.siteId == null ? Icons.filter_list : Icons.filter_list_alt),
                onPressed: () => _pickSiteFilter(context),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Note'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search title, description, site or customer',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: filter.status == null,
                      onSelected: (_) =>
                          context.read<NoteBloc>().add(const NoteStatusFilterChanged(null)),
                    ),
                    for (final s in NoteStatus.values) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(s.label),
                        selected: filter.status == s,
                        onSelected: (_) =>
                            context.read<NoteBloc>().add(NoteStatusFilterChanged(s)),
                      ),
                    ],
                    if (filter.isActive) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.close, size: 16),
                        label: const Text('Clear'),
                        onPressed: _clearFilters,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(child: _buildList(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context, NoteState state) {
    switch (state.status) {
      case NoteLoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case NoteLoadStatus.failure:
        return const Center(child: Text('Could not load notes'));
      case NoteLoadStatus.ready:
        if (state.notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                state.filter.isActive
                    ? 'No notes match your search or filters.'
                    : 'No notes yet.\nTap "Note" to add your first one.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: state.notes.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final n = state.notes[i];
            return Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Theme.of(context).colorScheme.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (_) => _confirmDelete(context, n),
              onDismissed: (_) => context.read<NoteBloc>().add(NoteDeleted(n.id)),
              child: ListTile(
                leading: Icon(n.status.icon, color: n.status.color),
                title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${n.siteName} · ${n.customerName}\n${_dateFormat.format(n.notedAt.toLocal())}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (n.hasLocation) const Icon(Icons.place_outlined, size: 18),
                    if (n.hasPhoto) const Icon(Icons.photo_outlined, size: 18),
                    if (n.isPending) const Icon(Icons.cloud_upload_outlined, size: 18),
                  ],
                ),
                onTap: () => _openForm(context, note: n),
              ),
            );
          },
        );
    }
  }
}

/// Lets "All sites" (null) be told apart from "sheet dismissed" (null).
class _SiteFilterResult {
  const _SiteFilterResult(this.siteId);
  final String? siteId;
}