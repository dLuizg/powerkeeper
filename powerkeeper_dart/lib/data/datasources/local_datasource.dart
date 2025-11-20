import 'package:mysql1/mysql1.dart';
import '../../core/exceptions/database_exceptions.dart';
import '../../domain/entities/domain_entities.dart';

abstract class ILocalDataSource {
  Future<MySqlConnection> get connection;
  Future<void> close();
}

class LocalDataSource implements ILocalDataSource {
  final ConnectionSettings _settings;
  MySqlConnection? _connection;
  bool _isConnected = false;

  LocalDataSource({
    required String host,
    required int port,
    required String user,
    required String password,
    required String database,
  }) : _settings = ConnectionSettings(
          host: host,
          port: port,
          user: user,
          password: password,
          db: database,
        );

  @override
  Future<MySqlConnection> get connection async {
    if (_connection == null || !_isConnected) {
      await _connect();
    } else {
      try {
        await _connection!.query('SELECT 1');
      } catch (_) {
        await _connect();
      }
    }
    return _connection!;
  }

  Future<void> _connect() async {
    try {
      await _connection?.close();
      _connection = await MySqlConnection.connect(_settings);
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
      throw ConnectionException(
        'Failed to connect to MySQL database: $e',
        StackTrace.current,
      );
    }
  }

  @override
  Future<void> close() async {
    await _connection?.close();
    _isConnected = false;
    _connection = null;
  }
}
