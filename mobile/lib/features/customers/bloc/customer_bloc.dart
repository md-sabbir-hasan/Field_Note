import 'package:field_notes/features/customers/data/customer_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'customer_event.dart';
import 'customer_state.dart';

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  CustomerBloc(this._repository, {required this.userId}) : super(const CustomerState()) {
    on<CustomersLoaded>(_onLoaded);
    on<CustomerSaved>(_onSaved);
    on<CustomerDeleted>(_onDeleted);
  }

  final CustomerRepository _repository;
  final int userId;

  Future<void> _onLoaded(CustomersLoaded event, Emitter<CustomerState> emit) async {
    try {
      final list = await _repository.list(userId);
      emit(state.copyWith(status: CustomerStatus.ready, customers: list, clearMessage: true));
    } catch (_) {
      emit(state.copyWith(status: CustomerStatus.failure));
    }
  }

  Future<void> _onSaved(CustomerSaved event, Emitter<CustomerState> emit) async {
    try {
      await _repository.save(
        userId: userId,
        id: event.id,
        name: event.name,
        contactInfo: event.contactInfo,
      );
      final list = await _repository.list(userId);
      emit(state.copyWith(
        status: CustomerStatus.ready,
        customers: list,
        message: event.id == null ? 'Customer created' : 'Customer updated',
      ));
    } catch (_) {
      emit(state.copyWith(message: 'Could not save customer'));
    }
  }

  Future<void> _onDeleted(CustomerDeleted event, Emitter<CustomerState> emit) async {
    try {
      await _repository.delete(userId, event.id);
      final list = await _repository.list(userId);
      emit(state.copyWith(
        status: CustomerStatus.ready,
        customers: list,
        message: 'Customer deleted',
      ));
    } catch (_) {
      emit(state.copyWith(message: 'Could not delete customer'));
    }
  }
}