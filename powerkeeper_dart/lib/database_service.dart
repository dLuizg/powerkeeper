// lib/database_service.dart

import 'package:mysql1/mysql1.dart';
import 'models.dart';
import 'dart:io';

class DatabaseService {
  MySqlConnection? _conn;
  bool _conectado = false;

  bool get conectado => _conectado;

  // -----------------------------
  // CONFIGURAÇÃO DO MYSQL
  // -----------------------------
  final _settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: '296q',
    db: 'powerkeeper',
  );

  // -----------------------------
  // CONECTAR
  // -----------------------------
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

  // Garante que a conexão sempre está ativa
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

  // -----------------------------
  // HELPERS
  // -----------------------------
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

  // -----------------------------
  // INSERT LEITURA
  // -----------------------------
  Future<String> insertLeitura(Leitura leitura) async {
    final conn = await _getValidConnection();
    try {
      final result = await conn.query('''
        INSERT INTO leitura (timeStamp, corrente, tensao, dispositivo_idDispositivo)
        VALUES (?, ?, ?, ?)
      ''', [
        leitura.timeStamp.toUtc(),
        leitura.corrente,
        leitura.tensao,
        leitura.dispositivoId
      ]);
      print("Rows inseridas em leitura: ${result.affectedRows}");
      return "sucesso";
    } catch (e) {
      return "Erro ao inserir leitura: $e";
    }
  }

  // -----------------------------
  // INSERT CONSUMO DIÁRIO
  // -----------------------------
  Future<String> insertConsumoDiario(ConsumoDiario c) async {
    final conn = await _getValidConnection();
    try {
      final result = await conn.query('''
        INSERT INTO consumoDiario (timeStamp, consumoKWh, dispositivo_idDispositivo)
        VALUES (?, ?, ?)
      ''', [
        c.timeStamp.toUtc(),
        c.consumoKwh,
        c.dispositivoId,
      ]);
      print("Rows inseridas em consumoDiario: ${result.affectedRows}");
      return "sucesso";
    } catch (e) {
      return "Erro ao inserir consumo diário: $e";
    }
  }

  // ============================================================
  // CRUD EMPRESA
  // ============================================================
  Future<String> addEmpresa(String nome, String cnpj) async {
    try {
      final conn = await _getValidConnection();
      final result = await conn.query(
          'INSERT INTO empresa (nome, cnpj) VALUES (?, ?)', [nome, cnpj]);
      print("Rows inseridas em empresa: ${result.affectedRows}");
      return "ok";
    } catch (e) {
      return "Erro ao inserir empresa: $e";
    }
  }

  Future<List<Map<String, dynamic>>> getEmpresas() async {
    final conn = await _getValidConnection();
    final r = await conn.query("SELECT * FROM empresa ORDER BY idEmpresa DESC");

    return r
        .map((row) => {
              'idEmpresa': _asInt(row['idEmpresa']),
              'nome': row['nome'],
              'cnpj': row['cnpj'],
            })
        .toList();
  }

  Future<String> deleteEmpresa(int id) async {
    try {
      final conn = await _getValidConnection();
      final result =
          await conn.query('DELETE FROM empresa WHERE idEmpresa=?', [id]);
      print("Rows deletadas em empresa: ${result.affectedRows}");
      return "ok";
    } catch (e) {
      return "Erro ao deletar empresa: $e";
    }
  }

  // ============================================================
  // CRUD FUNCIONÁRIO
  // ============================================================
  Future<String> addFuncionario(
      String nome, String email, String senha, int idEmpresa) async {
    try {
      final conn = await _getValidConnection();
      final result = await conn.query('''
        INSERT INTO funcionario (nome, email, senhaLogin, empresa_idEmpresa)
        VALUES (?, ?, ?, ?)
      ''', [nome, email, senha, idEmpresa]);
      print("Rows inseridas em funcionario: ${result.affectedRows}");
      return 'ok';
    } catch (e) {
      return 'Erro: $e';
    }
  }

  Future<List<Map<String, dynamic>>> getFuncionarios() async {
    final conn = await _getValidConnection();
    final r = await conn.query('''
      SELECT funcionario.idFuncionario, funcionario.nome, funcionario.email, empresa.nome AS empresa
      FROM funcionario
      JOIN empresa ON empresa.idEmpresa = funcionario.empresa_idEmpresa
      ORDER BY funcionario.idFuncionario DESC
    ''');
    return r
        .map((row) => {
              'idFuncionario': _asInt(row['idFuncionario']),
              'nome': row['nome'],
              'email': row['email'],
              'empresa': row['empresa'],
            })
        .toList();
  }

  Future<String> deleteFuncionario(int id) async {
    try {
      final conn = await _getValidConnection();
      final result = await conn
          .query('DELETE FROM funcionario WHERE idFuncionario = ?', [id]);
      print("Rows deletadas em funcionario: ${result.affectedRows}");
      return "ok";
    } catch (e) {
      return "Erro ao deletar funcionario: $e";
    }
  }

  // ============================================================
  // CRUD LOCAL
  // ============================================================
  Future<String> addLocal(String nome, String ref, int idEmpresa) async {
    try {
      final conn = await _getValidConnection();
      final result = await conn.query('''
        INSERT INTO local (nome, referencia, empresa_idEmpresa)
        VALUES (?, ?, ?)
      ''', [nome, ref, idEmpresa]);
      print("Rows inseridas em local: ${result.affectedRows}");
      return "ok";
    } catch (e) {
      return "Erro ao inserir local: $e";
    }
  }

  Future<List<Map<String, dynamic>>> getLocais() async {
    final conn = await _getValidConnection();
    final r = await conn.query('''
      SELECT local.idLocal, local.nome, local.referencia, empresa.nome AS empresa
      FROM local
      JOIN empresa ON local.empresa_idEmpresa = empresa.idEmpresa
      ORDER BY local.idLocal DESC
    ''');
    return r
        .map((row) => {
              'idLocal': _asInt(row['idLocal']),
              'nome': row['nome'],
              'referencia': row['referencia'],
              'empresa': row['empresa'],
            })
        .toList();
  }

  Future<String> deleteLocal(int id) async {
    try {
      final conn = await _getValidConnection();
      final result =
          await conn.query("DELETE FROM local WHERE idLocal=?", [id]);
      print("Rows deletadas em local: ${result.affectedRows}");
      return "ok";
    } catch (e) {
      return "Erro ao deletar local: $e";
    }
  }

  // ============================================================
  // CRUD DISPOSITIVO
  // ============================================================
  Future<String> addDispositivo(
      String modelo, String status, int idLocal) async {
    try {
      final conn = await _getValidConnection();
      final result = await conn.query('''
        INSERT INTO dispositivo (modelo, status, local_idLocal)
        VALUES (?, ?, ?)
      ''', [modelo, status, idLocal]);
      print("Rows inseridas em dispositivo: ${result.affectedRows}");
      return "ok";
    } catch (e) {
      return "Erro: $e";
    }
  }

  Future<List<Map<String, dynamic>>> getDispositivos() async {
    final conn = await _getValidConnection();
    final r = await conn.query('''
      SELECT dispositivo.idDispositivo, dispositivo.modelo, dispositivo.status,
             local.nome AS local, empresa.nome AS empresa
      FROM dispositivo
      JOIN local ON dispositivo.local_idLocal = local.idLocal
      JOIN empresa ON local.empresa_idEmpresa = empresa.idEmpresa
      ORDER BY dispositivo.idDispositivo DESC
    ''');
    return r
        .map((row) => {
              'idDispositivo': _asInt(row['idDispositivo']),
              'modelo': row['modelo'],
              'status': row['status'],
              'local': row['local'],
              'empresa': row['empresa'],
            })
        .toList();
  }

  Future<String> deleteDispositivo(int id) async {
    try {
      final conn = await _getValidConnection();
      final result = await conn
          .query("DELETE FROM dispositivo WHERE idDispositivo=?", [id]);
      print("Rows deletadas em dispositivo: ${result.affectedRows}");
      return "ok";
    } catch (e) {
      return "Erro ao deletar dispositivo: $e";
    }
  }

  // ============================================================
  // LISTAGENS FORMATADAS PARA MENU
  // ============================================================
  Future<void> listarEmpresas() async {
    final dados = await getEmpresas();
    print("\n📊 EMPRESAS:");
    print("=" * 50);
    for (var e in dados) {
      print(
          "ID: ${e['idEmpresa']}  |  Nome: ${e['nome']}  |  CNPJ: ${e['cnpj']}");
    }
  }

  Future<void> listarFuncionarios() async {
    final dados = await getFuncionarios();
    print("\n👥 FUNCIONÁRIOS:");
    print("=" * 50);
    for (var f in dados) {
      print(
          "${f['idFuncionario']} | ${f['nome']} | ${f['email']} | Empresa: ${f['empresa']}");
    }
  }

  Future<void> listarLocais() async {
    final dados = await getLocais();
    print("\n🏢 LOCAIS:");
    print("=" * 50);
    for (var l in dados) {
      print(
          "${l['idLocal']} | ${l['nome']} | ${l['referencia']} | Empresa: ${l['empresa']}");
    }
  }

  Future<void> listarDispositivos() async {
    final dados = await getDispositivos();
    print("\n🔌 DISPOSITIVOS:");
    print("=" * 50);
    for (var d in dados) {
      print(
          "${d['idDispositivo']} | ${d['modelo']} | Status: ${d['status']} | Local: ${d['local']} | Empresa: ${d['empresa']}");
    }
  }
}
