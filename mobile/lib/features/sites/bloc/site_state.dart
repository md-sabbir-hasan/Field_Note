import 'package:equatable/equatable.dart';
import 'package:field_notes/features/sites/data/site.dart';


enum SiteStatus { loading, ready, failure }

class SiteState extends Equatable {
  const SiteState({
    this.status = SiteStatus.loading,
    this.sites = const [],
    this.customerFilter,
    this.message,
  });

  final SiteStatus status;
  final List<Site> sites;
  final String? customerFilter;
  final String? message;

  SiteState copyWith({
    SiteStatus? status,
    List<Site>? sites,
    String? customerFilter,
    bool clearFilter = false,
    String? message,
    bool clearMessage = false,
  }) {
    return SiteState(
      status: status ?? this.status,
      sites: sites ?? this.sites,
      customerFilter: clearFilter ? null : (customerFilter ?? this.customerFilter),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props => [status, sites, customerFilter, message];
}