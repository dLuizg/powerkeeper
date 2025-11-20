import 'package:mysql1/mysql1.dart';
import '../../core/exceptions/database_exceptions.dart';
import '../../core/interfaces/repository_interface.dart';
import '../../domain/entities/domain_entities.dart';
import '../../domain/repositories/abstract_repositories.dart';
import '../datasources/local_datasource.dart';
import '../models/entities.dart';

abstract class BaseRepository<T extends Entity> implements IRepository<T> {
  final ILocalDataSource dataSource;

  BaseRepository(this.dataSource);

  String get tableName;
  String get idColumnName;
  T fromDTO(dynamic dto);
  dynamic toDTO(T entity);
  Map<String, dynamic> entityToMap(T entity);

  @override
  Future<T> create(T entity) async {
    final conn = await dataSource.connection;
    try {
      final map = entityToMap(entity);
      map.remove(idColumnName); // Remove ID para INSERT

      final columns = map.keys.join(', ');
      final placeholders = List.filled(map.length, '?').join(', ');

      final result = await conn.query(
        'INSERT INTO $tableName ($columns) VALUES ($placeholders)',
        map.values.toList(),
      );

      if (result.insertId == null) {
        throw QueryException(
          'INSERT $tableName',
          'Failed to get insert ID',
          StackTrace.current,
        );
      }

      final createdEntity = await findById(result.insertId);
      if (createdEntity == null) {
        throw EntityNotFoundException(tableName, result.insertId);
      }
      return createdEntity;
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw QueryException(
        'INSERT $tableName',
        'Failed to create entity: $e',
        StackTrace.current,
      );
    }
  }

  @override
  Future<List<T>> findAll() async {
    final conn = await dataSource.connection;
    try {
      final results = await conn
          .query('SELECT * FROM $tableName ORDER BY $idColumnName DESC');
      return results.map((row) => fromDTO(row)).toList();
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw QueryException(
        'SELECT * FROM $tableName',
        'Failed to find all entities: $e',
        StackTrace.current,
      );
    }
  }

  @override
  Future<T?> findById(dynamic id) async {
    final conn = await dataSource.connection;
    try {
      final results = await conn.query(
        'SELECT * FROM $tableName WHERE $idColumnName = ?',
        [id],
      );

      if (results.isEmpty) return null;
      return fromDTO(results.first);
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw QueryException(
        'SELECT * FROM $tableName WHERE $idColumnName = ?',
        'Failed to find entity by ID: $e',
        StackTrace.current,
      );
    }
  }

  @override
  Future<T> update(T entity) async {
    if (entity.id == null) {
      throw QueryException(
        'UPDATE $tableName',
        'Entity must have an ID to update',
        StackTrace.current,
      );
    }

    final conn = await dataSource.connection;
    try {
      final map = entityToMap(entity);
      final setClause = map.keys
          .where((key) => key != idColumnName)
          .map((key) => '$key = ?')
          .join(', ');
      final values = map.keys
          .where((key) => key != idColumnName)
          .map((key) => map[key])
          .toList();
      values.add(entity.id);

      final result = await conn.query(
        'UPDATE $tableName SET $setClause WHERE $idColumnName = ?',
        values,
      );

      if (result.affectedRows == 0) {
        throw EntityNotFoundException(tableName, entity.id);
      }

      final updatedEntity = await findById(entity.id);
      if (updatedEntity == null) {
        throw EntityNotFoundException(tableName, entity.id);
      }
      return updatedEntity;
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw QueryException(
        'UPDATE $tableName',
        'Failed to update entity: $e',
        StackTrace.current,
      );
    }
  }

  @override
  Future<void> delete(dynamic id) async {
    final conn = await dataSource.connection;
    try {
      final result = await conn.query(
        'DELETE FROM $tableName WHERE $idColumnName = ?',
        [id],
      );

      if (result.affectedRows == 0) {
        throw EntityNotFoundException(tableName, id);
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw QueryException(
        'DELETE FROM $tableName',
        'Failed to delete entity: $e',
        StackTrace.current,
      );
    }
  }
}

class EmpresaRepository extends BaseRepository<Empresa>
    implements IEmpresaRepository {
  EmpresaRepository(super.dataSource);

  @override
  String get tableName => 'empresa';

  @override
  String get idColumnName => 'idEmpresa';

  @override
  Empresa fromDTO(dynamic dto) {
    if (dto is ResultRow) {
      return EmpresaDTO.fromRow(dto).toEntity();
    }
    throw ArgumentError('Invalid DTO type for Empresa');
  }

  @override
  EmpresaDTO toDTO(Empresa entity) => EmpresaDTO.fromEntity(entity);

  @override
  Map<String, dynamic> entityToMap(Empresa entity) => toDTO(entity).toMap();

  @override
  Future<List<Empresa>> findWithPagination(int page, int limit) async {
    final conn = await dataSource.connection;
    final offset = (page - 1) * limit;
    final results = await conn.query(
      'SELECT * FROM $tableName ORDER BY $idColumnName DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return results.map((row) => fromDTO(row)).toList();
  }

  @override
  Future<int> count() async {
    final conn = await dataSource.connection;
    final result = await conn.query('SELECT COUNT(*) as count FROM $tableName');
    return (result.first['count'] as int?) ?? 0;
  }

  @override
  Future<Empresa?> findByCnpj(String cnpj) async {
    final conn = await dataSource.connection;
    final results = await conn.query(
      'SELECT * FROM $tableName WHERE cnpj = ?',
      [cnpj],
    );
    if (results.isEmpty) return null;
    return fromDTO(results.first);
  }
}

class FuncionarioRepository extends BaseRepository<Funcionario>
    implements IFuncionarioRepository {
  FuncionarioRepository(super.dataSource);

  @override
  String get tableName => 'funcionario';

  @override
  String get idColumnName => 'idFuncionario';

  @override
  Funcionario fromDTO(dynamic dto) {
    if (dto is ResultRow) {
      return FuncionarioDTO.fromRow(dto).toEntity();
    }
    throw ArgumentError('Invalid DTO type for Funcionario');
  }

  @override
  FuncionarioDTO toDTO(Funcionario entity) => FuncionarioDTO.fromEntity(entity);

  @override
  Map<String, dynamic> entityToMap(Funcionario entity) => toDTO(entity).toMap();

  @override
  Future<List<Funcionario>> findWithPagination(int page, int limit) async {
    final conn = await dataSource.connection;
    final offset = (page - 1) * limit;
    final results = await conn.query(
      'SELECT * FROM $tableName ORDER BY $idColumnName DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return results.map((row) => fromDTO(row)).toList();
  }

  @override
  Future<int> count() async {
    final conn = await dataSource.connection;
    final result = await conn.query('SELECT COUNT(*) as count FROM $tableName');
    return (result.first['count'] as int?) ?? 0;
  }

  @override
  Future<List<Funcionario>> findByEmpresaId(int empresaId) async {
    final conn = await dataSource.connection;
    final results = await conn.query(
      'SELECT * FROM $tableName WHERE empresa_idEmpresa = ? ORDER BY $idColumnName DESC',
      [empresaId],
    );
    return results.map((row) => fromDTO(row)).toList();
  }

  @override
  Future<Funcionario?> findByEmail(String email) async {
    final conn = await dataSource.connection;
    final results = await conn.query(
      'SELECT * FROM $tableName WHERE email = ?',
      [email],
    );
    if (results.isEmpty) return null;
    return fromDTO(results.first);
  }
}

class LocalRepository extends BaseRepository<Local>
    implements ILocalRepository {
  LocalRepository(super.dataSource);

  @override
  String get tableName => 'local';

  @override
  String get idColumnName => 'idLocal';

  @override
  Local fromDTO(dynamic dto) {
    if (dto is ResultRow) {
      return LocalDTO.fromRow(dto).toEntity();
    }
    throw ArgumentError('Invalid DTO type for Local');
  }

  @override
  LocalDTO toDTO(Local entity) => LocalDTO.fromEntity(entity);

  @override
  Map<String, dynamic> entityToMap(Local entity) => toDTO(entity).toMap();

  @override
  Future<List<Local>> findWithPagination(int page, int limit) async {
    final conn = await dataSource.connection;
    final offset = (page - 1) * limit;
    final results = await conn.query(
      'SELECT * FROM $tableName ORDER BY $idColumnName DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return results.map((row) => fromDTO(row)).toList();
  }

  @override
  Future<int> count() async {
    final conn = await dataSource.connection;
    final result = await conn.query('SELECT COUNT(*) as count FROM $tableName');
    return (result.first['count'] as int?) ?? 0;
  }

  @override
  Future<List<Local>> findByEmpresaId(int empresaId) async {
    final conn = await dataSource.connection;
    final results = await conn.query(
      'SELECT * FROM $tableName WHERE empresa_idEmpresa = ? ORDER BY $idColumnName DESC',
      [empresaId],
    );
    return results.map((row) => fromDTO(row)).toList();
  }
}

class DispositivoRepository extends BaseRepository<Dispositivo>
    implements IDispositivoRepository {
  DispositivoRepository(super.dataSource);

  @override
  String get tableName => 'dispositivo';

  @override
  String get idColumnName => 'idDispositivo';

  @override
  Dispositivo fromDTO(dynamic dto) {
    if (dto is ResultRow) {
      return DispositivoDTO.fromRow(dto).toEntity();
    }
    throw ArgumentError('Invalid DTO type for Dispositivo');
  }

  @override
  DispositivoDTO toDTO(Dispositivo entity) => DispositivoDTO.fromEntity(entity);

  @override
  Map<String, dynamic> entityToMap(Dispositivo entity) => toDTO(entity).toMap();

  @override
  Future<List<Dispositivo>> findWithPagination(int page, int limit) async {
    final conn = await dataSource.connection;
    final offset = (page - 1) * limit;
    final results = await conn.query(
      'SELECT * FROM $tableName ORDER BY $idColumnName DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return results.map((row) => fromDTO(row)).toList();
  }

  @override
  Future<int> count() async {
    final conn = await dataSource.connection;
    final result = await conn.query('SELECT COUNT(*) as count FROM $tableName');
    return (result.first['count'] as int?) ?? 0;
  }

  @override
  Future<List<Dispositivo>> findByLocalId(int localId) async {
    final conn = await dataSource.connection;
    final results = await conn.query(
      'SELECT * FROM $tableName WHERE local_idLocal = ? ORDER BY $idColumnName DESC',
      [localId],
    );
    return results.map((row) => fromDTO(row)).toList();
  }

  @override
  Future<List<Dispositivo>> findByStatus(String status) async {
    final conn = await dataSource.connection;
    final results = await conn.query(
      'SELECT * FROM $tableName WHERE status = ? ORDER BY $idColumnName DESC',
      [status],
    );
    return results.map((row) => fromDTO(row)).toList();
  }
}

class ConsumoDiarioRepository extends BaseRepository<ConsumoDiario>
    implements IConsumoDiarioRepository {
  ConsumoDiarioRepository(super.dataSource);

  @override
  String get tableName => 'consumoDiario';

  @override
  String get idColumnName => 'idLeitura';

  @override
  ConsumoDiario fromDTO(dynamic dto) {
    if (dto is ResultRow) {
      return ConsumoDiarioDTO.fromRow(dto).toEntity();
    }
    throw ArgumentError('Invalid DTO type for ConsumoDiario');
  }

  @override
  ConsumoDiarioDTO toDTO(ConsumoDiario entity) =>
      ConsumoDiarioDTO.fromEntity(entity);

  @override
  Map<String, dynamic> entityToMap(ConsumoDiario entity) =>
      toDTO(entity).toMap();

  @override
  Future<List<ConsumoDiario>> findWithPagination(int page, int limit) async {
    final conn = await dataSource.connection;
    final offset = (page - 1) * limit;
    final results = await conn.query(
      'SELECT * FROM $tableName ORDER BY $idColumnName DESC LIMIT ? OFFSET ?',
      [limit, offset],
    );
    return results.map((row) => fromDTO(row)).toList();
  }

  @override
  Future<int> count() async {
    final conn = await dataSource.connection;
    final result = await conn.query('SELECT COUNT(*) as count FROM $tableName');
    return (result.first['count'] as int?) ?? 0;
  }

  @override
  Future<List<ConsumoDiario>> findByDispositivoId(int dispositivoId) async {
    final conn = await dataSource.connection;
    final results = await conn.query(
      'SELECT * FROM $tableName WHERE dispositivo_idDispositivo = ? ORDER BY timeStamp DESC',
      [dispositivoId],
    );
    return results.map((row) => fromDTO(row)).toList();
  }

  @override
  Future<List<ConsumoDiario>> findByPeriodo(
      DateTime inicio, DateTime fim) async {
    final conn = await dataSource.connection;
    final results = await conn.query(
      'SELECT * FROM $tableName WHERE timeStamp BETWEEN ? AND ? ORDER BY timeStamp DESC',
      [inicio.toUtc(), fim.toUtc()],
    );
    return results.map((row) => fromDTO(row)).toList();
  }

  @override
  Future<ConsumoDiario?> findByFirebaseKey(String firebaseKey) async {
    final conn = await dataSource.connection;
    final results = await conn.query(
      'SELECT * FROM $tableName WHERE firebaseKey = ?',
      [firebaseKey],
    );
    if (results.isEmpty) return null;
    return fromDTO(results.first);
  }
}
