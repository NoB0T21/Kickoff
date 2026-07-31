/// Base API exception — thrown when the backend returns a standardized error envelope.
class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  const ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  factory ApiException.fromCode({
    required String code,
    required String message,
    required int statusCode,
  }) {
    switch (code) {
      case 'USERNAME_TAKEN':
        return UsernameTakenException(message: message);
      case 'SELF_FOLLOW':
        return SelfFollowException(message: message);
      case 'ALREADY_FOLLOWING':
        return AlreadyFollowingException(message: message);
      case 'NOT_FOLLOWING':
        return NotFollowingException(message: message);
      case 'PROFILE_NOT_FOUND':
        return ProfileNotFoundException(message: message);
      case 'UNAUTHENTICATED':
      case 'INVALID_TOKEN':
        return UnauthenticatedException(message: message);
      case 'VALIDATION_ERROR':
        return ValidationException(message: message);
      case 'RATE_LIMITED':
        return RateLimitedException(message: message);
      default:
        return ApiException(code: code, message: message, statusCode: statusCode);
    }
  }

  @override
  String toString() => 'ApiException($code): $message';
}

class UsernameTakenException extends ApiException {
  const UsernameTakenException({String message = 'That username is already in use.'})
      : super(code: 'USERNAME_TAKEN', message: message, statusCode: 409);
}

class SelfFollowException extends ApiException {
  const SelfFollowException({String message = 'You cannot follow yourself.'})
      : super(code: 'SELF_FOLLOW', message: message, statusCode: 400);
}

class AlreadyFollowingException extends ApiException {
  const AlreadyFollowingException({String message = 'You are already following this user.'})
      : super(code: 'ALREADY_FOLLOWING', message: message, statusCode: 409);
}

class NotFollowingException extends ApiException {
  const NotFollowingException({String message = 'You are not following this user.'})
      : super(code: 'NOT_FOLLOWING', message: message, statusCode: 404);
}

class ProfileNotFoundException extends ApiException {
  const ProfileNotFoundException({String message = 'Profile not found.'})
      : super(code: 'PROFILE_NOT_FOUND', message: message, statusCode: 404);
}

class UnauthenticatedException extends ApiException {
  const UnauthenticatedException({String message = 'Authentication required.'})
      : super(code: 'UNAUTHENTICATED', message: message, statusCode: 401);
}

class ValidationException extends ApiException {
  const ValidationException({String message = 'Validation failed.'})
      : super(code: 'VALIDATION_ERROR', message: message, statusCode: 400);
}

class RateLimitedException extends ApiException {
  const RateLimitedException({String message = 'Too many requests.'})
      : super(code: 'RATE_LIMITED', message: message, statusCode: 429);
}
