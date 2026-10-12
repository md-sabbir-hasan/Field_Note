import 'package:field_notes/features/customers/data/customer.dart';
import 'package:field_notes/features/customers/data/customer_repository.dart';
import 'package:field_notes/features/sites/bloc/site_bloc.dart';
import 'package:field_notes/features/sites/bloc/site_event.dart';
import 'package:field_notes/features/sites/bloc/site_state.dart';
import 'package:field_notes/features/sites/data/site.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'site_form_page.dart';

class SiteListPage extends StatelessWidget {
  const SiteListPage({super.key, required this.customerRepository, required this.userId});

  final CustomerRepository customerRepository;
  final int userId;

  Future<bool> _confirmDelete(BuildContext context, Site s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete site?'),
        content: Text('"${s.siteName}" and all its notes will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _openForm(BuildContext context, {Site? site}) async {
    final bloc = context.read<SiteBloc>();
    final customers = await customerRepository.list(userId);
    if (!context.mounted) return;

    if (customers.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Add a customer first')));
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: SiteFormPage(site: site, customers: customers),
      ),
    ));
  }

  Future<void> _pickFilter(BuildContext context) async {
    final bloc = context.read<SiteBloc>();
    final customers = await customerRepository.list(userId);
    if (!context.mounted) return;

    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('All customers'),
              selected: bloc.state.customerFilter == null,
              onTap: () => Navigator.pop(ctx, const _FilterResult(null)),
            ),
            for (final Customer c in customers)
              ListTile(
                title: Text(c.name),
                selected: bloc.state.customerFilter == c.id,
                onTap: () => Navigator.pop(ctx, _FilterResult(c.id)),
              ),
          ],
        ),
      ),
    );

    if (result != null) bloc.add(SiteCustomerFilterChanged(result.customerId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SiteBloc, SiteState>(
      listenWhen: (p, c) => c.message != null && c.message != p.message,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sites'),
            actions: [
              IconButton(
                tooltip: 'Filter by customer',
                icon: Icon(state.customerFilter == null
                    ? Icons.filter_list
                    : Icons.filter_list_alt),
                onPressed: () => _pickFilter(context),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Site'),
          ),
          body: switch (state.status) {
            SiteStatus.loading => const Center(child: CircularProgressIndicator()),
            SiteStatus.failure => const Center(child: Text('Could not load sites')),
            SiteStatus.ready => state.sites.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No sites yet.\nTap "Site" to add one.',
                    textAlign: TextAlign.center),
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: state.sites.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = state.sites[i];
                return Dismissible(
                  key: ValueKey(s.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context, s),
                  onDismissed: (_) => context.read<SiteBloc>().add(SiteDeleted(s.id)),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.location_city)),
                    title: Text(s.siteName),
                    subtitle: Text(
                      s.address == null || s.address!.isEmpty
                          ? s.customerName
                          : '${s.customerName} · ${s.address}',
                    ),
                    trailing: s.isPending
                        ? const Icon(Icons.cloud_upload_outlined, size: 18)
                        : null,
                    onTap: () => _openForm(context, site: s),
                  ),
                );
              },
            ),
          },
        );
      },
    );
  }
}

/// Wrapper so "All customers" (null) can be told apart from "dialog dismissed" (null).
class _FilterResult {
  const _FilterResult(this.customerId);
  final String? customerId;
}