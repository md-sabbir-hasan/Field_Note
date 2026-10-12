import 'package:field_notes/features/sites/data/site_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'site_event.dart';
import 'site_state.dart';

class SiteBloc extends Bloc<SiteEvent, SiteState> {
  SiteBloc(this._repository, {required this.userId}) : super(const SiteState()) {
    on<SitesLoaded>(_onLoaded);
    on<SiteCustomerFilterChanged>(_onFilterChanged);
    on<SiteSaved>(_onSaved);
    on<SiteDeleted>(_onDeleted);
  }

  final SiteRepository _repository;
  final int userId;

  Future<void> _onLoaded(SitesLoaded event, Emitter<SiteState> emit) async {
    try {
      final list = await _repository.list(userId, customerId: state.customerFilter);
      emit(state.copyWith(status: SiteStatus.ready, sites: list, clearMessage: true));
    } catch (_) {
      emit(state.copyWith(status: SiteStatus.failure));
    }
  }

  Future<void> _onFilterChanged(
      SiteCustomerFilterChanged event, Emitter<SiteState> emit) async {
    try {
      final list = await _repository.list(userId, customerId: event.customerId);
      emit(SiteState(
        status: SiteStatus.ready,
        sites: list,
        customerFilter: event.customerId,
      ));
    } catch (_) {
      emit(state.copyWith(status: SiteStatus.failure));
    }
  }

  Future<void> _onSaved(SiteSaved event, Emitter<SiteState> emit) async {
    try {
      await _repository.save(
        userId: userId,
        id: event.id,
        customerId: event.customerId,
        siteName: event.siteName,
        address: event.address,
      );
      final list = await _repository.list(userId, customerId: state.customerFilter);
      emit(state.copyWith(
        status: SiteStatus.ready,
        sites: list,
        message: event.id == null ? 'Site created' : 'Site updated',
      ));
    } catch (_) {
      emit(state.copyWith(message: 'Could not save site'));
    }
  }

  Future<void> _onDeleted(SiteDeleted event, Emitter<SiteState> emit) async {
    try {
      await _repository.delete(userId, event.id);
      final list = await _repository.list(userId, customerId: state.customerFilter);
      emit(state.copyWith(status: SiteStatus.ready, sites: list, message: 'Site deleted'));
    } catch (_) {
      emit(state.copyWith(message: 'Could not delete site'));
    }
  }
}