abstract class DatabaseException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  DatabaseException(this.message, [this.stackTrace]);

  @override
  String toString() => 'DatabaseException: $message';
}

class ConnectionException extends DatabaseException {
  ConnectionException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class QueryException extends DatabaseException {
  final String query;

  QueryException(this.query, String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

class EntityNotFoundException extends DatabaseException {
  final String entityName;
  final dynamic entityId;

  EntityNotFoundException(this.entityName, this.entityId,
      [StackTrace? stackTrace])
      : super('$entityName with ID $entityId not found', stackTrace);
}
