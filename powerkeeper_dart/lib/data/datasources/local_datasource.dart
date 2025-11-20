import 'package:mysql1/mysql1.dart';
import '../../core/exceptions/database_exceptions.dart';

abstract class ILocalDataSource {
  Future<MySqlConnection> getConnection();
  Future<void> closeConnection();
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
  Future<MySqlConnection> getConnection() async {
    if (_connection == null || !_isConnected) {
      await _connect();
    } else {
      try {
        // Testa se a conexão ainda está válida
        await _connection!.query('SELECT 1');
      } catch (_) {
        // Reconecta se a conexão foi fechada
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
      print('✅ Conectado ao MySQL com sucesso!');
    } catch (e) {
      _isConnected = false;
      throw ConnectionException(
        'Failed to connect to MySQL database: $e',
        StackTrace.current,
      );
    }
  }

  @override
  Future<void> closeConnection() async {
    await _connection?.close();
    _isConnected = false;
    _connection = null;
    print('🔌 Conexão MySQL fechada.');
  }
}
