class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => 'AppException: $message';
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message, code: 'network_error');
}

class ValidationException extends AppException {
  final Map<String, List<String>> errors;

  ValidationException(String message, this.errors)
      : super(message, code: 'validation_error');
}

class AuthException extends AppException {
  AuthException(String message) : super(message, code: 'auth_error');
}

class PermissionException extends AppException {
  PermissionException(String message)
      : super(message, code: 'permission_denied');
}

