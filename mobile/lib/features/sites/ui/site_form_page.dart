import 'package:field_notes/features/customers/data/customer.dart';
import 'package:field_notes/features/sites/bloc/site_bloc.dart';
import 'package:field_notes/features/sites/bloc/site_event.dart';
import 'package:field_notes/features/sites/data/site.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';



class SiteFormPage extends StatefulWidget {
  const SiteFormPage({super.key, this.site, required this.customers});

  final Site? site;
  final List<Customer> customers;

  @override
  State<SiteFormPage> createState() => _SiteFormPageState();
}

class _SiteFormPageState extends State<SiteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  String? _customerId;

  bool get _isEdit => widget.site != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.site?.siteName);
    _addressController = TextEditingController(text: widget.site?.address);
    // Keep the old customer only if it is still in the list.
    final current = widget.site?.customerId;
    _customerId = widget.customers.any((c) => c.id == current) ? current : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SiteBloc>().add(SiteSaved(
      id: widget.site?.id,
      customerId: _customerId!,
      siteName: _nameController.text,
      address: _addressController.text,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit site' : 'New site')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _customerId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Customer',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in widget.customers)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _customerId = v),
                  validator: (v) => v == null ? 'Select a customer' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Site name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Site name is required';
                    if (value.length > 150) return 'Site name is too long';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  keyboardType: TextInputType.multiline,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: Text(_isEdit ? 'Update' : 'Save')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}