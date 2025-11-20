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

  // ⚡ FUNÇÃO CORRIGIDA ⚡
  Future<List<Map<String, dynamic>>> getConsumosDiarios() async {
    print("🔍 Buscando todos os Consumos Diários no banco local...");

    final List<Map<String, dynamic>> consumos = [];

    try {
      final conn = await _getValidConnection();

      // ⬅️ CORREÇÃO NA CONSULTA: Usando 'idLeitura', 'consumoKWh' e 'dispositivo_idDispositivo'
      // O campo 'firebaseKey' não aparece na sua tabela, então vamos removê-lo do SELECT
      // e do mapeamento, e usar a chave primária 'idLeitura' no lugar.
      final results = await conn.query(
          'SELECT idLeitura, dispositivo_idDispositivo, consumoKWh, timeStamp FROM consumoDiario ORDER BY timeStamp DESC');

      for (final row in results) {
        consumos.add({
          // ⬅️ CORREÇÃO NO MAPEAMENTO: A ordem dos índices (0, 1, 2, 3) deve seguir o SELECT acima
          'idLeitura': row[0], // Corresponde a idLeitura
          'dispositivoId': row[1], // Corresponde a dispositivo_idDispositivo
          'consumoKwh': row[2], // Corresponde a consumoKWh
          'timeStamp': row[3].toString(), // Corresponde a timeStamp
          // 'firebaseKey': row[4], // Removido, pois não está no SELECT
        });
      }

      print("✅ ${consumos.length} registros de Consumo Diário encontrados.");
      return consumos;
    } catch (e) {
      print("❌ ERRO ao listar Consumos Diários: $e");
      return [];
    }
  }

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
        INSERT INTO consumoDiario (timeStamp, consumoKwh, dispositivo_idDispositivo, firebaseKey)
        VALUES (?, ?, ?, ?)
      ''', [
        c.timeStamp.toUtc(),
        c.consumoKwh,
        c.dispositivoId,
        c.firebaseKey, // Adicionei o firebaseKey aqui para ser inserido junto
      ]);
      print("Rows inseridas em consumoDiario: ${result.affectedRows}");
      return "sucesso";
    } catch (e) {
      // Tentativa de lidar com duplicidade de forma mais específica, se houver constraint
      if (e.toString().contains('Duplicate entry')) {
        return "aviso: Duplicate entry";
      }
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
    final conn = await _getValidConnection();

    // Usando uma transação para garantir que TODAS as deleções sejam feitas ou nenhuma
    try {
      await conn.transaction((conn) async {
        // 1. Deleta registros dependentes em 'funcionario' (necessário pelo erro 1451)
        final deleteFuncionario = await conn
            .query('DELETE FROM funcionario WHERE empresa_idEmpresa = ?', [id]);
        print(
            "Rows deletadas em funcionario (dependentes da Empresa $id): ${deleteFuncionario.affectedRows}");

        // 2. Deleta registros dependentes em 'local' (assumindo a dependência da sua mensagem de aviso)
        // *AVISO: Se 'local' tiver dependências (como 'dispositivo'), esta deleção pode falhar
        // e você precisará deletar as dependências de 'local' primeiro.*
        final deleteLocal = await conn
            .query('DELETE FROM local WHERE empresa_idEmpresa = ?', [id]);
        print(
            "Rows deletadas em local (dependentes da Empresa $id): ${deleteLocal.affectedRows}");

        // 3. Deleta o registro principal em 'empresa'
        final deleteEmpresaResult =
            await conn.query('DELETE FROM empresa WHERE idEmpresa = ?', [id]);

        if (deleteEmpresaResult.affectedRows == 0) {
          throw Exception("Empresa com ID $id não encontrada para deleção.");
        }

        print("Rows deletadas em empresa: ${deleteEmpresaResult.affectedRows}");
      });

      return "ok";
    } catch (e) {
      // Captura qualquer erro na transação
      return "Erro ao deletar empresa: $e";
    }
  }

  Future<String> deleteConsumoDiario(int idLeitura) async {
    try {
      final conn = await _getValidConnection();
      final result = await conn
          .query('DELETE FROM consumoDiario WHERE idLeitura=?', [idLeitura]);
      print("Rows deletadas em consumoDiario: ${result.affectedRows}");
      return "ok";
    } catch (e) {
      return "Erro ao deletar consumoDiario: $e";
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
    final conn = await _getValidConnection();

    // Usando uma transação para garantir que ambas as deleções sejam feitas ou nenhuma
    try {
      await conn.transaction((conn) async {
        // 1. Deleta registros dependentes em 'analisa' (para resolver o Erro 1451)
        final deleteAnalisa = await conn
            .query('DELETE FROM analisa WHERE usuario_idUsuario = ?', [id]);
        print(
            "Rows deletadas em analisa (dependentes do Funcionario $id): ${deleteAnalisa.affectedRows}");

        // 2. Deleta o registro principal em 'funcionario'
        final deleteFuncionario = await conn
            .query('DELETE FROM funcionario WHERE idFuncionario = ?', [id]);

        if (deleteFuncionario.affectedRows == 0) {
          // Se a deleção do funcionário não afetou linhas, a transação será abortada se for lançado um erro.
          // Neste caso, retornamos uma mensagem de aviso.
          throw Exception(
              "Funcionário com ID $id não encontrado para deleção.");
        }

        print(
            "Rows deletadas em funcionario: ${deleteFuncionario.affectedRows}");
      });

      return "ok";
    } catch (e) {
      // Captura qualquer erro na transação (incluindo o que jogamos acima)
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
    final conn = await _getValidConnection();

    // Usando uma transação para garantir que TODAS as deleções sejam feitas ou nenhuma
    try {
      await conn.transaction((conn) async {
        // 1. Deleta registros dependentes em 'consumodiario'
        final deleteConsumo = await conn.query(
            'DELETE FROM consumodiario WHERE dispositivo_idDispositivo = ?',
            [id]);
        print(
            "Rows deletadas em consumodiario (dependentes do Dispositivo $id): ${deleteConsumo.affectedRows}");

        // 2. NOVO PASSO: Deleta registros dependentes em 'analisa' (resolve o Erro 1451 atual)
        final deleteAnalisa = await conn.query(
            'DELETE FROM analisa WHERE dispositivo_idDispositivo = ?', [id]);
        print(
            "Rows deletadas em analisa (dependentes do Dispositivo $id): ${deleteAnalisa.affectedRows}");

        // 3. Deleta o registro principal em 'dispositivo'
        final deleteDispositivoResult = await conn
            .query("DELETE FROM dispositivo WHERE idDispositivo=?", [id]);

        if (deleteDispositivoResult.affectedRows == 0) {
          throw Exception(
              "Dispositivo com ID $id não encontrado para deleção.");
        }

        print(
            "Rows deletadas em dispositivo: ${deleteDispositivoResult.affectedRows}");
      });

      return "ok";
    } catch (e) {
      // Captura qualquer erro na transação
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
          "ID: ${e['idEmpresa']}  |  Nome: ${e['nome']}  |  CNPJ: ${e['cnpj']}");
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
