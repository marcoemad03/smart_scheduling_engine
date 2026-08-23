import 'package:equatable/equatable.dart';

class Failure extends Equatable {
  final String message;
  final String code;

  const Failure({required this.message, required this.code});

  @override
  List<Object> get props => [message, code];
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message) : super(message: message, code: 'network_failure');
}

class ValidationFailure extends Failure {
  const ValidationFailure(String message) : super(message: message, code: 'validation_failure');
}

class AuthFailure extends Failure {
  const AuthFailure(String message) : super(message: message, code: 'auth_failure');
}

class PermissionFailure extends Failure {
  const PermissionFailure(String message) : super(message: message, code: 'permission_failure');
}

