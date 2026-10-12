import 'package:equatable/equatable.dart';

sealed class SiteEvent extends Equatable {
  const SiteEvent();

  @override
  List<Object?> get props => [];
}

class SitesLoaded extends SiteEvent {
  const SitesLoaded();
}

/// Filter the list by customer (null = all customers).
class SiteCustomerFilterChanged extends SiteEvent {
  const SiteCustomerFilterChanged(this.customerId);

  final String? customerId;

  @override
  List<Object?> get props => [customerId];
}

class SiteSaved extends SiteEvent {
  const SiteSaved({
    this.id,
    required this.customerId,
    required this.siteName,
    this.address,
  });

  final String? id; // null = create
  final String customerId;
  final String siteName;
  final String? address;

  @override
  List<Object?> get props => [id, customerId, siteName, address];
}

class SiteDeleted extends SiteEvent {
  const SiteDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}