import 'package:equatable/equatable.dart';

class Failure extends Equatable {
  final String message;
  final String codes;

  const Failure({required this.message, required this.codes});

  @override
  List<Object> get props => [message, codes];
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message)
      : super(message: message, codes: 'network_failure');
}

class ValidationFailure extends Failure {
  const ValidationFailure(String message)
      : super(message: message, codes: 'validation_failure');
}

class AuthFailure extends Failure {
  const AuthFailure(String message)
      : super(message: message, codes: 'auth_failure');
}

class PermissionFailure extends Failure {
  const PermissionFailure(String message)
      : super(message: message, codes: 'permission_failure');
}