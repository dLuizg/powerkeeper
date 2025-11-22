// lib/database_service.dart

import 'package:mysql1/mysql1.dart';
import 'models.dart';
import 'dart:io';

class DatabaseService {
  MySqlConnection? _conn;
  bool _conectado = false;

  bool get conectado => _conectado;

  // ---------------------------------------------------------
  // CONFIGURAÇÃO MYSQL
  // ---------------------------------------------------------
  final _settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: '296q',
    db: 'powerkeeper',
  );

  // ---------------------------------------------------------
  // CONEXÃO
  // ---------------------------------------------------------
  Future<void> connect() async {
    await _conn?.close().catchError((_) {});
    try {
      _conn = await MySqlConnection.connect(_settings);
      _conectado = true;
      print("🔌 Conectado ao MySQL com sucesso!");
    } catch (e) {
      print("❌ ERRO ao conectar ao MySQL:");
      print(e);
      exit(1);
    }
  }

  Future<MySqlConnection> _getValidConnection() async {
    if (_conn == null || !_conectado) {
      print("Reconectando ao MySQL...");
      await connect();
    } else {
      try {
        await _conn!.query('SELECT 1');
      } catch (_) {
        await connect();
      }
    }
    return _conn!;
  }

  Future<void> close() async {
    await _conn?.close();
    _conectado = false;
    print("🔌 Conexão MySQL fechada.");
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  // ---------------------------------------------------------
  // CORREÇÃO FK (1452)
  // ---------------------------------------------------------

  Future<bool> _dispositivoExiste(int idDispositivo) async {
    final conn = await _getValidConnection();
    final results = await conn.query(
      'SELECT idDispositivo FROM dispositivo WHERE idDispositivo = ?',
      [idDispositivo],
    );
    return results.isNotEmpty;
  }

  Future<void> _garantirDispositivoPadrao(int idDispositivo) async {
    print('-> Criando dependências padrão para dispositivo $idDispositivo...');

    await _addEmpresaForcaId(1, 'Empresa Padrao Sinc', '00000000000000');
    await _addLocalForcaId(1, 'Local Padrao Sinc', 'N/A', 1);
    await _addDispositivoForcaId(
        idDispositivo, 'Sincronizacao Padrao', 'Ativo', 1);

    print('-> Finalizado.');
  }

  Future<void> _addEmpresaForcaId(int id, String nome, String cnpj) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
        '''
        INSERT INTO empresa (idEmpresa, nome, cnpj)
        VALUES (?, ?, ?)
        ''',
        [id, nome, cnpj],
      );
    } on MySqlException catch (e) {
      if (e.errorNumber != 1062) throw e;
    }
  }

  Future<void> _addLocalForcaId(
      int id, String nome, String ref, int idEmpresa) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
        '''
        INSERT INTO local (idLocal, nome, referencia, empresa_idEmpresa)
        VALUES (?, ?, ?, ?)
        ''',
        [id, nome, ref, idEmpresa],
      );
    } on MySqlException catch (e) {
      if (e.errorNumber != 1062) throw e;
    }
  }

  Future<void> _addDispositivoForcaId(
      int id, String modelo, String status, int idLocal) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
        '''
        INSERT INTO dispositivo (idDispositivo, modelo, status, local_idLocal)
        VALUES (?, ?, ?, ?)
        ''',
        [id, modelo, status, idLocal],
      );
    } on MySqlException catch (e) {
      if (e.errorNumber != 1062) throw e;
    }
  }

  // ---------------------------------------------------------
  // CONSUMO DIÁRIO
  // ---------------------------------------------------------
  Future<String> insertConsumoDiario(ConsumoDiario c) async {
    final conn = await _getValidConnection();

    try {
      await conn.query(
        '''
        INSERT INTO consumodiario 
        (timeStamp, consumoKwh, dispositivo_idDispositivo, firebaseKey)
        VALUES (?, ?, ?, ?)
        ''',
        [
          c.timeStamp.toUtc(),
          c.consumoKwh,
          c.dispositivoId,
          c.firebaseKey,
        ],
      );

      return "sucesso: Novo registro inserido";
    } on MySqlException catch (e) {
      if (e.errorNumber == 1062) {
        return "sucesso: Duplicate entry - já existe no banco";
      }

      if (e.errorNumber == 1452) {
        final dispositivoId = c.dispositivoId;

        if (await _dispositivoExiste(dispositivoId) == false) {
          await _garantirDispositivoPadrao(dispositivoId);
          return await insertConsumoDiario(c);
        }

        return "❌ Falha FK: Dispositivo $dispositivoId não existe.";
      }

      return "❌ Erro MySQL (${e.errorNumber}): ${e.message}";
    } catch (e) {
      return "❌ Erro ao inserir consumo diário: $e";
    }
  }

  Future<List<Map<String, dynamic>>> getConsumosDiarios() async {
    print("🔍 Buscando consumos...");

    final List<Map<String, dynamic>> lista = [];

    try {
      final conn = await _getValidConnection();
      final results = await conn.query(
        '''
        SELECT idLeitura, dispositivo_idDispositivo, consumoKWh, timeStamp, firebaseKey
        FROM consumodiario
        ORDER BY timeStamp DESC
        ''',
      );

      for (final row in results) {
        lista.add({
          'idLeitura': row[0],
          'dispositivoId': row[1],
          'consumoKwh': row[2],
          'timeStamp': row[3].toString(),
          'firebaseKey': row[4],
        });
      }

      print("✅ ${lista.length} registros encontrados.");
      return lista;
    } catch (e) {
      print("❌ ERRO ao listar consumos: $e");
      return [];
    }
  }

  Future<String> deleteConsumoDiario(int idLeitura) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
        'DELETE FROM consumodiario WHERE idLeitura = ?',
        [idLeitura],
      );
      return "ok";
    } catch (e) {
      return "Erro ao deletar leitura: $e";
    }
  }

  // ---------------------------------------------------------
  // CRUD EMPRESAS
  // ---------------------------------------------------------
  Future<String> addEmpresa(String nome, String cnpj) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
        'INSERT INTO empresa (nome, cnpj) VALUES (?, ?)',
        [nome, cnpj],
      );
      return "ok";
    } catch (e) {
      return "Erro ao inserir empresa: $e";
    }
  }

  // -----------------------------------------------------------
// LISTAR EMPRESAS (CORRIGIDO)
// -----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getEmpresas() async {
    final conn = await _getValidConnection();
    final results = await conn.query("""
    SELECT idEmpresa, nome, cnpj 
    FROM empresa
    ORDER BY idEmpresa ASC
  """);

    return results.map((row) {
      return {
        "id": row[0],
        "nome": row[1],
        "cnpj": row[2],
      };
    }).toList();
  }

  Future<String> deleteEmpresa(int id) async {
    try {
      final conn = await _getValidConnection();
      await conn.query("DELETE FROM empresa WHERE idEmpresa = ?", [id]);
      return "ok";
    } catch (e) {
      return "Erro ao deletar empresa: $e";
    }
  }

  // ---------------------------------------------------------
  // CRUD FUNCIONÁRIOS
  // ---------------------------------------------------------
  Future<String> addFuncionario(
      String nome, String email, String senha, int idEmpresa) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
        '''
        INSERT INTO funcionario (nome, email, senhaLogin, empresa_idEmpresa)
        VALUES (?, ?, ?, ?)
        ''',
        [nome, email, senha, idEmpresa],
      );
      return "ok";
    } catch (e) {
      return "Erro: $e";
    }
  }

  Future<List<Map<String, dynamic>>> getFuncionarios() async {
    final conn = await _getValidConnection();
    final results = await conn.query("""
      SELECT idFuncionario, nome, email, empresa_idEmpresa
      FROM funcionario
      ORDER BY idFuncionario ASC
    """);

    return results.map((row) {
      return {
        "id": row[0],
        "nome": row[1],
        "email": row[2],
        "empresaId": row[3],
      };
    }).toList();
  }

  Future<String> deleteFuncionario(int id) async {
    try {
      final conn = await _getValidConnection();
      await conn.query("DELETE FROM funcionario WHERE idFuncionario = ?", [id]);
      return "ok";
    } catch (e) {
      return "Erro ao deletar funcionário: $e";
    }
  }

  // ---------------------------------------------------------
  // CRUD LOCAIS
  // ---------------------------------------------------------
  Future<String> addLocal(String nome, String ref, int idEmpresa) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
        '''
        INSERT INTO local (nome, referencia, empresa_idEmpresa)
        VALUES (?, ?, ?)
        ''',
        [nome, ref, idEmpresa],
      );
      return "ok";
    } catch (e) {
      return "Erro ao inserir local: $e";
    }
  }

  Future<List<Map<String, dynamic>>> getLocais() async {
    final conn = await _getValidConnection();
    final results = await conn.query("""
      SELECT idLocal, nome, referencia, empresa_idEmpresa
      FROM local
      ORDER BY idLocal ASC
    """);

    return results.map((row) {
      return {
        "id": row[0],
        "nome": row[1],
        "referencia": row[2],
        "empresaId": row[3],
      };
    }).toList();
  }

  Future<String> deleteLocal(int id) async {
    try {
      final conn = await _getValidConnection();
      await conn.query("DELETE FROM local WHERE idLocal = ?", [id]);
      return "ok";
    } catch (e) {
      return "Erro ao deletar local: $e";
    }
  }

  // ---------------------------------------------------------
  // CRUD DISPOSITIVOS
  // ---------------------------------------------------------
  Future<String> addDispositivo(
      String modelo, String status, int idLocal) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
        '''
        INSERT INTO dispositivo (modelo, status, local_idLocal)
        VALUES (?, ?, ?)
        ''',
        [modelo, status, idLocal],
      );
      return "ok";
    } catch (e) {
      return "Erro: $e";
    }
  }

  Future<List<Map<String, dynamic>>> getDispositivos() async {
    final conn = await _getValidConnection();
    final results = await conn.query("""
      SELECT idDispositivo, modelo, status, local_idLocal
      FROM dispositivo
      ORDER BY idDispositivo ASC
    """);

    return results.map((row) {
      return {
        "id": row[0],
        "modelo": row[1],
        "status": row[2],
        "localId": row[3],
      };
    }).toList();
  }

  Future<String> deleteDispositivo(int id) async {
    try {
      final conn = await _getValidConnection();
      await conn.query("DELETE FROM dispositivo WHERE idDispositivo = ?", [id]);
      return "ok";
    } catch (e) {
      return "Erro ao deletar dispositivo: $e";
    }
  }
}
