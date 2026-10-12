import 'package:equatable/equatable.dart';

sealed class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load, and also fired after a sync finishes.
class CustomersLoaded extends CustomerEvent {
  const CustomersLoaded();
}

class CustomerSaved extends CustomerEvent {
  const CustomerSaved({this.id, required this.name, this.contactInfo});

  final String? id; // null = create
  final String name;
  final String? contactInfo;

  @override
  List<Object?> get props => [id, name, contactInfo];
}

class CustomerDeleted extends CustomerEvent {
  const CustomerDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}