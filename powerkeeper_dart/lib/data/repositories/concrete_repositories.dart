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
    final conn = await dataSource.getConnection();
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
    final conn = await dataSource.getConnection();
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
    final conn = await dataSource.getConnection();
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

    final conn = await dataSource.getConnection();
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
    final conn = await dataSource.getConnection();
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
