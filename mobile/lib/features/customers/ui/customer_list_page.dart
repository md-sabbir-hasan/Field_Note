import 'package:field_notes/features/customers/bloc/customer_bloc.dart';
import 'package:field_notes/features/customers/bloc/customer_event.dart';
import 'package:field_notes/features/customers/bloc/customer_state.dart';
import 'package:field_notes/features/customers/data/customer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'customer_form_page.dart';

class CustomerListPage extends StatelessWidget {
  const CustomerListPage({super.key});

  Future<bool> _confirmDelete(BuildContext context, Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text(
            '"${c.name}" and all its sites and notes will be deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }

  void _openForm(BuildContext context, {Customer? customer}) {
    // The form reuses the same bloc instance through the route.
    final bloc = context.read<CustomerBloc>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: CustomerFormPage(customer: customer),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerBloc, CustomerState>(
      listenWhen: (p, c) => c.message != null && c.message != p.message,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Customers')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Customer'),
          ),
          body: switch (state.status) {
            CustomerStatus.loading => const Center(child: CircularProgressIndicator()),
            CustomerStatus.failure => const Center(child: Text('Could not load customers')),
            CustomerStatus.ready => state.customers.isEmpty
                ? const _EmptyView()
                : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: state.customers.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = state.customers[i];
                return Dismissible(
                  key: ValueKey(c.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context, c),
                  onDismissed: (_) =>
                      context.read<CustomerBloc>().add(CustomerDeleted(c.id)),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase()),
                    ),
                    title: Text(c.name),
                    subtitle: (c.contactInfo == null) ? null : Text(c.contactInfo!),
                    trailing: c.isPending
                        ? const Icon(Icons.cloud_upload_outlined, size: 18)
                        : null,
                    onTap: () => _openForm(context, customer: c),
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No customers yet.\nTap "Customer" to add your first one.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}