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
    host: 'localhost', // ou 'localhost'
    port: 3306,
    user: 'root', // Seu usuário
    password: '296q', // Sua senha
    db: 'powerkeeper', // O nome do seu schema (pela imagem)
  );
  // ----------------------------------------

  Future<void> connect() async {
    try {
      _conn = await MySqlConnection.connect(_settings);
      _conectado = true;
      print("Conectado ao MySQL (DatabaseService) com sucesso!");
    } catch (e) {
      print("ERRO FATAL ao conectar ao MySQL:");
      print(e);
      exit(1);
    }
  }

  Future<void> close() async {
    await _conn?.close();
    _conectado = false;
    print("Conexão MySQL fechada.");
  }

  // --- FUNÇÕES DE SINCRONIZAÇÃO (Firebase -> MySQL) ---

  /// Insere uma Leitura vinda do Firebase no MySQL
  /// Retorna uma string de status para o gestao.dart
  // lib/database_service.dart (Substitua a função insertLeitura)

  Future<String> insertLeitura(Leitura leitura) async {
  if (!_conectado || _conn == null || leitura.firebaseDocId == null) {
    return "Erro: MySQL não conectado ou leitura sem ID Firebase.";
  }

  final sql = '''
    INSERT INTO leitura 
      (timeStamp, corrente, tensao, dispositivo_idDispositivo)
    VALUES (?, ?, ?, ?);
  ''';

  try {
    // --- ESTA É A MUDANÇA ---
    // Se leitura.dispositivoId for nulo (porque não veio do Firebase),
    // nós forçamos o valor '1'.
    // MUDE O '1' se quiser que o padrão seja outro ID.
    final idDispositivoParaSalvar = leitura.dispositivoId ?? 1; 
    // -----------------------

    final params = [
      // Garante que seja UTC e nunca nulo
      (leitura.timeStamp ?? DateTime.now()).toUtc(), 
      leitura.corrente,
      leitura.tensao,
      idDispositivoParaSalvar,
    ];



    await _conn!.query(sql, params);
    return "sucesso";

  } on MySqlException catch (e) {
    if (e.errorNumber == 1452) {
      // Este erro agora vai acontecer se o ID '1' (ou o seu padrão)
      // não existir na sua tabela 'dispositivo'.
      print("Erro FK: O dispositivo padrão (ID 1) não existe no MySQL. Leitura ${leitura.firebaseDocId} falhou.");
      return "Erro FK: O dispositivoId padrão (ex: 1) não existe na tabela 'dispositivo'.";
    }
    // ... outros 'catch' ...
    print("Erro MySQL ao inserir leitura ${leitura.firebaseDocId}: $e");
    return "Erro MySQL: ${e.message}";
  } catch (e) {
    print("Erro inesperado ao inserir leitura ${leitura.firebaseDocId}: $e");
    return "Erro inesperado: $e";
  }
}

  // --- FUNÇÕES DE EMPRESA (para gestao.dart) ---

  Future<void> addEmpresa(String nome, String cnpj) async {
    await _conn?.query(
        'INSERT INTO empresa (nome, cnpj) VALUES (?, ?)', [nome, cnpj]);
  }

  Future<List<String>> getEmpresas() async {
    final results = await _conn!.query('SELECT * FROM empresa');
    return results
        .map((row) =>
            "ID: ${row['idEmpresa']}, Nome: ${row['nome']}, CNPJ: ${row['cnpj']}")
        .toList();
  }

  Future<void> deleteEmpresa(int id) async {
    await _conn!
        .query('DELETE FROM empresa WHERE idEmpresa = ?', [id]);
  }

  // --- FUNÇÕES DE FUNCIONÁRIO (para gestao.dart) ---

  Future<String> addFuncionario(
      String nome, String email, String senha, int idEmpresa) async {
    try {
      await _conn!.query(
          'INSERT INTO funcionario (nome, email, senhaLogin, empresa_idEmpresa) VALUES (?, ?, ?, ?)',
          [nome, email, senha, idEmpresa]);
      return "Funcionário adicionado com sucesso.";
    } on MySqlException catch (e) {
      if (e.errorNumber == 1452) { // Erro de Foreign Key
        return "Erro: Empresa com ID $idEmpresa não existe.";
      }
      return "Erro MySQL: ${e.message}";
    }
  }

  Future<List<String>> getFuncionarios() async {
    final results = await _conn!.query(
        'SELECT f.*, e.nome as nomeEmpresa FROM funcionario f JOIN empresa e ON f.empresa_idEmpresa = e.idEmpresa');
    return results
        .map((row) =>
            "ID: ${row['idFuncionario']}, Nome: ${row['nome']}, Email: ${row['email']}, Empresa: ${row['nomeEmpresa']}")
        .toList();
  }

  Future<void> deleteFuncionario(int id) async {
    await _conn!
        .query('DELETE FROM funcionario WHERE idFuncionario = ?', [id]);
  }

  // --- FUNÇÕES DE LOCAL (para gestao.dart) ---

  Future<String> addLocal(
      String nome, String referencia, int idEmpresa) async {
    try {
      await _conn!.query(
          'INSERT INTO local (nome, referencia, empresa_idEmpresa) VALUES (?, ?, ?)',
          [nome, referencia, idEmpresa]);
      return "Local adicionado com sucesso.";
    } on MySqlException catch (e) {
      if (e.errorNumber == 1452) { // Erro de Foreign Key
        return "Erro: Empresa com ID $idEmpresa não existe.";
      }
      return "Erro MySQL: ${e.message}";
    }
  }

  Future<List<String>> getLocais() async {
    final results = await _conn!.query(
        'SELECT l.*, e.nome as nomeEmpresa FROM local l JOIN empresa e ON l.empresa_idEmpresa = e.idEmpresa');
    return results
        .map((row) =>
            "ID: ${row['idLocal']}, Nome: ${row['nome']}, Ref: ${row['referencia']}, Empresa: ${row['nomeEmpresa']}")
        .toList();
  }

  Future<void> deleteLocal(int id) async {
    await _conn!.query('DELETE FROM local WHERE idLocal = ?', [id]);
  }

  // --- FUNÇÕES DE DISPOSITIVO (para gestao.dart) ---

  Future<String> addDispositivo(
      String modelo, String status, int idLocal) async {
    try {
      await _conn!.query(
          'INSERT INTO dispositivo (modelo, status, local_idLocal) VALUES (?, ?, ?)',
          [modelo, status, idLocal]);
      return "Dispositivo adicionado com sucesso.";
    } on MySqlException catch (e) {
      if (e.errorNumber == 1452) { // Erro de Foreign Key
        return "Erro: Local com ID $idLocal não existe.";
      }
      return "Erro MySQL: ${e.message}";
    }
  }

  Future<List<String>> getDispositivos() async {
    final results = await _conn!.query(
        'SELECT d.*, l.nome as nomeLocal FROM dispositivo d JOIN local l ON d.local_idLocal = l.idLocal');
    return results
        .map((row) =>
            "ID: ${row['idDispositivo']}, Modelo: ${row['modelo']}, Status: ${row['status']}, Local: ${row['nomeLocal']}")
        .toList();
  }

  Future<void> deleteDispositivo(int id) async {
    await _conn!
        .query('DELETE FROM dispositivo WHERE idDispositivo = ?', [id]);
  }
}