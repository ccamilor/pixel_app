/// Fallos de dominio tipados para Clean Architecture.
sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class LocalDatabaseFailure extends Failure {
  const LocalDatabaseFailure(super.message);
}

final class RemoteSyncFailure extends Failure {
  const RemoteSyncFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
