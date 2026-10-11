import 'package:equatable/equatable.dart';

/// The signed-in user. The token itself lives in secure storage, not here.
class AuthUser extends Equatable {
  const AuthUser({required this.id, required this.name, required this.email});

  final int id;
  final String name;
  final String email;

  @override
  List<Object?> get props => [id, name, email];
}