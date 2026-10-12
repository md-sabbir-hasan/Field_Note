import 'package:equatable/equatable.dart';
import 'package:field_notes/features/customers/data/customer.dart';


enum CustomerStatus { loading, ready, failure }

class CustomerState extends Equatable {
  const CustomerState({
    this.status = CustomerStatus.loading,
    this.customers = const [],
    this.message,
  });

  final CustomerStatus status;
  final List<Customer> customers;

  /// One-shot message for a snackbar (e.g. "Customer deleted").
  final String? message;

  CustomerState copyWith({
    CustomerStatus? status,
    List<Customer>? customers,
    String? message,
    bool clearMessage = false,
  }) {
    return CustomerState(
      status: status ?? this.status,
      customers: customers ?? this.customers,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, customers, message];
}