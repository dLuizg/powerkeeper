// lib/database_service.dart

import 'package:mysql1/mysql1.dart';
import 'models.dart'; // Importa nossa classe 'Leitura'
import 'dart:io';

class DatabaseService {
  MySqlConnection? _conn;
  bool _conectado = false;

  bool get conectado => _conectado;

  // --- CONFIGURE AQUI SEU BANCO MYSQL ---
  final _settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: '296q',
    db: 'powerkeeper',
  );
  // ----------------------------------------

  Future<void> connect() async {
    await _conn?.close().catchError((_) {});

    try {
      _conn = await MySqlConnection.connect(_settings);
      _conectado = true;
      print("Conectado ao MySQL (DatabaseService) com sucesso!");
    } catch (e) {
      print("ERRO FATAL ao conectar ao MySQL:");
      print(e);
      _conectado = false;
      exit(1);
    }
  }

  /// Verifica se a conexão está viva e reconecta se necessário.
  Future<MySqlConnection> _getValidConnection() async {
    if (_conn == null || !_conectado) {
      print('🔌 Conexão MySQL não iniciada. Conectando...');
      await connect();
    }
    try {
      await _conn!.query('SELECT 1');
    } catch (e) {
      print('⚠️ Conexão MySQL perdida. Reconectando...');
      await connect();
    }
    return _conn!;
  }

  Future<void> close() async {
    await _conn?.close();
    _conectado = false;
    print("Conexão MySQL fechada.");
  }

  // --- FUNÇÕES DE SINCRONIZAÇÃO (Firebase -> MySQL) ---

  Future<String> insertLeitura(Leitura leitura) async {
    final conn = await _getValidConnection();

    // Usa transação para garantir o COMMIT (salvar)
    try {
      await conn.transaction((txn) async {
        final sql = '''
        INSERT INTO leitura 
          (timeStamp, corrente, tensao, dispositivo_idDispositivo)
        VALUES (?, ?, ?, ?);
      ''';
        final params = [
          leitura.timeStamp,
          leitura.corrente,
          leitura.tensao,
          leitura.dispositivoId,
        ];
        await txn.query(sql, params);
      });

      return "sucesso";
    } on MySqlException catch (e) {
      if (e.errorNumber == 1452) {
        print(
            "Erro FK: Dispositivo com ID ${leitura.dispositivoId} (do ESP32) não existe no MySQL. Leitura ${leitura.firebaseDocId} falhou.");
        return "Erro FK: O dispositivoId ${leitura.dispositivoId} não existe na tabela 'dispositivo'.";
      }
      print("Erro MySQL ao inserir leitura ${leitura.firebaseDocId}: $e");
      return "Erro MySQL: ${e.message}";
    } catch (e) {
      print("Erro inesperado ao inserir leitura ${leitura.firebaseDocId}: $e");
      return "Erro inesperado: $e";
    }
  }

  // --- FUNÇÕES DE LEITURA (Usadas pelo menu antigo) ---
  // (Deixamos aqui caso precise)
  Future<List<String>> getLeiturasRecentes(int limite) async {
    final conn = await _getValidConnection();
    final leiturasList = <String>[];
    try {
      final results = await conn.query('''
            SELECT l.*, d.modelo as nomeDispositivo 
            FROM leitura l
            LEFT JOIN dispositivo d ON l.dispositivo_idDispositivo = d.idDispositivo
            ORDER BY l.timeStamp DESC 
            LIMIT ?
          ''', [limite]);

      for (final row in results) {
        String ts = (row['timeStamp'] as DateTime)
            .toLocal()
            .toString()
            .substring(0, 19);
        final dispositivo =
            row['nomeDispositivo'] ?? 'ID ${row['dispositivo_idDispositivo']}';
        leiturasList.add(
            "ID: ${row['idLeitura']}, TS: $ts, A: ${row['corrente']}, V: ${row['tensao']}, Disp: $dispositivo");
      }
    } catch (e) {
      leiturasList.add("Erro ao buscar leituras: $e");
    }
    return leiturasList;
  }

  // --- FUNÇÕES DE EMPRESA ---

  Future<void> addEmpresa(String nome, String cnpj) async {
    final conn = await _getValidConnection();
    await conn
        .query('INSERT INTO empresa (nome, cnpj) VALUES (?, ?)', [nome, cnpj]);
  }

  Future<List<String>> getEmpresas() async {
    final conn = await _getValidConnection();
    final results = await conn.query('SELECT * FROM empresa');
    return results
        .map((row) =>
            "ID: ${row['idEmpresa']}, Nome: ${row['nome']}, CNPJ: ${row['cnpj']}")
        .toList();
  }

  Future<void> deleteEmpresa(int id) async {
    final conn = await _getValidConnection();
    await conn.query('DELETE FROM empresa WHERE idEmpresa = ?', [id]);
  }

  // --- FUNÇÕES DE FUNCIONÁRIO ---

  Future<String> addFuncionario(
      String nome, String email, String senha, int idEmpresa) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
          'INSERT INTO funcionario (nome, email, senhaLogin, empresa_idEmpresa) VALUES (?, ?, ?, ?)',
          [nome, email, senha, idEmpresa]);
      return "Funcionário adicionado com sucesso.";
    } on MySqlException catch (e) {
      if (e.errorNumber == 1452) {
        return "Erro: Empresa com ID $idEmpresa não existe.";
      }
      return "Erro MySQL: ${e.message}";
    }
  }

  Future<List<String>> getFuncionarios() async {
    final conn = await _getValidConnection();
    final results = await conn.query(
        'SELECT f.*, e.nome as nomeEmpresa FROM funcionario f JOIN empresa e ON f.empresa_idEmpresa = e.idEmpresa');
    return results
        .map((row) =>
            "ID: ${row['idFuncionario']}, Nome: ${row['nome']}, Email: ${row['email']}, Empresa: ${row['nomeEmpresa']}")
        .toList();
  }

  Future<void> deleteFuncionario(int id) async {
    final conn = await _getValidConnection();
    await conn.query('DELETE FROM funcionario WHERE idFuncionario = ?', [id]);
  }

  // --- FUNÇÕES DE LOCAL ---

  Future<String> addLocal(String nome, String referencia, int idEmpresa) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
          'INSERT INTO local (nome, referencia, empresa_idEmpresa) VALUES (?, ?, ?)',
          [nome, referencia, idEmpresa]);
      return "Local adicionado com sucesso.";
    } on MySqlException catch (e) {
      if (e.errorNumber == 1452) {
        return "Erro: Empresa com ID $idEmpresa não existe.";
      }
      return "Erro MySQL: ${e.message}";
    }
  }

  Future<List<String>> getLocais() async {
    final conn = await _getValidConnection();
    final results = await conn.query(
        'SELECT l.*, e.nome as nomeEmpresa FROM local l JOIN empresa e ON l.empresa_idEmpresa = e.idEmpresa');
    return results
        .map((row) =>
            "ID: ${row['idLocal']}, Nome: ${row['nome']}, Ref: ${row['referencia']}, Empresa: ${row['nomeEmpresa']}")
        .toList();
  }

  Future<void> deleteLocal(int id) async {
    final conn = await _getValidConnection();
    await conn.query('DELETE FROM local WHERE idLocal = ?', [id]);
  }

  // --- FUNÇÕES DE DISPOSITIVO ---

  Future<String> addDispositivo(
      String modelo, String status, int idLocal) async {
    try {
      final conn = await _getValidConnection();
      await conn.query(
          'INSERT INTO dispositivo (modelo, status, local_idLocal) VALUES (?, ?, ?)',
          [modelo, status, idLocal]);
      return "Dispositivo adicionado com sucesso.";
    } on MySqlException catch (e) {
      if (e.errorNumber == 1452) {
        return "Erro: Local com ID $idLocal não existe.";
      }
      return "Erro MySQL: ${e.message}";
    }
  }

  Future<List<String>> getDispositivos() async {
    final conn = await _getValidConnection();
    final results = await conn.query(
        'SELECT d.*, l.nome as nomeLocal FROM dispositivo d JOIN local l ON d.local_idLocal = l.idLocal');
    return results
        .map((row) =>
            "ID: ${row['idDispositivo']}, Modelo: ${row['modelo']}, Status: ${row['status']}, Local: ${row['nomeLocal']}")
        .toList();
  }

  Future<void> deleteDispositivo(int id) async {
    final conn = await _getValidConnection();
    await conn.query('DELETE FROM dispositivo WHERE idDispositivo = ?', [id]);
  }

  // --- FUNÇÕES NOVAS PARA A TABELA PROFISSIONAL ---

  Future<List<Map<String, dynamic>>> getEmpresasForTable() async {
    final conn = await _getValidConnection();
    final results =
        await conn.query('SELECT idEmpresa, nome, cnpj FROM empresa');
    return results.map((row) => row.fields).toList();
  }

  Future<List<Map<String, dynamic>>> getFuncionariosForTable() async {
    final conn = await _getValidConnection();
    final results = await conn.query(
        'SELECT f.idFuncionario, f.nome, f.email, e.nome as empresa FROM funcionario f JOIN empresa e ON f.empresa_idEmpresa = e.idEmpresa');
    return results.map((row) => row.fields).toList();
  }

  Future<List<Map<String, dynamic>>> getLocaisForTable() async {
    final conn = await _getValidConnection();
    final results = await conn.query(
        'SELECT l.idLocal, l.nome, l.referencia, e.nome as empresa FROM local l JOIN empresa e ON l.empresa_idEmpresa = e.idEmpresa');
    return results.map((row) => row.fields).toList();
  }

  Future<List<Map<String, dynamic>>> getDispositivosForTable() async {
    final conn = await _getValidConnection();
    final results = await conn.query(
        'SELECT d.idDispositivo, d.modelo, d.status, l.nome as local FROM dispositivo d JOIN local l ON d.local_idLocal = l.idLocal');
    return results.map((row) => row.fields).toList();
  }

  Future<List<Map<String, dynamic>>> getLeiturasForTable(int limite) async {
    final conn = await _getValidConnection();
    final results = await conn.query('''
          SELECT 
            l.idLeitura, 
            DATE_FORMAT(CONVERT_TZ(l.timeStamp, '+00:00', 'SYSTEM'), '%Y-%m-%d %H:%i:%s') as timeStamp, 
            l.corrente, 
            l.tensao, 
            d.modelo as dispositivo
          FROM leitura l
          LEFT JOIN dispositivo d ON l.dispositivo_idDispositivo = d.idDispositivo
          ORDER BY l.idLeitura DESC 
          LIMIT ?
        ''', [limite]);
    // Converte os resultados para Mapas
    return results.map((row) {
      // Converte campos 'double' que vêm como 'String'
      var fields = row.fields;
      fields['corrente'] =
          double.tryParse(fields['corrente'].toString()) ?? 0.0;
      fields['tensao'] = double.tryParse(fields['tensao'].toString()) ?? 0.0;
      return fields;
    }).toList();
  }
}
