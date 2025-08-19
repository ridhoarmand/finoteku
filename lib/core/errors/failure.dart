/// Unified domain/application failure representation.
/// Extend this for specific failure types if needed.
sealed class Failure implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;
  const Failure(this.message, {this.cause, this.stackTrace});
  @override
  String toString() => '$runtimeType: $message';
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause, super.stackTrace});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause, super.stackTrace});
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message, {super.cause, super.stackTrace});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause, super.stackTrace});
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message, {super.cause, super.stackTrace});
}

/// Helper to map generic exceptions to Failure.
Failure mapException(Object e, [StackTrace? st]) {
  final msg = e.toString();
  if (msg.contains('permission') || msg.contains('Tidak berhak')) {
    return PermissionFailure(msg, cause: e, stackTrace: st);
  }
  if (msg.contains('not found') || msg.contains('tidak ditemukan')) {
    return NotFoundFailure(msg, cause: e, stackTrace: st);
  }
  return UnknownFailure(msg, cause: e, stackTrace: st);
}
