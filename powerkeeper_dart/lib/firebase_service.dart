// lib/firebase_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
// Importa ambas as classes (Leitura e ConsumoDiario)
import 'models.dart';

class FirebaseService {
  http.Client? _client;
  String? _projectId;
  String? _accessToken;

  // !!! CORREÇÃO APLICADA AQUI: O ID DO PROJETO FOI ATUALIZADO !!!
  final String _databaseUrl =
      'https://powerkeeper-synatec-default-rtdb.firebaseio.com';
  bool _conectado = false;

  bool get conectado => _conectado;

  Future<void> connect() async {
    try {
      final jsonCredentials =
          await File('serviceAccountKey.json').readAsString();
      final credentialsMap =
          jsonDecode(jsonCredentials) as Map<String, dynamic>;

      _projectId = credentialsMap['project_id'] as String?;

      if (_projectId == null) {
        throw Exception('project_id não encontrado no arquivo de credenciais');
      }

      final credentials = ServiceAccountCredentials.fromJson(credentialsMap);

      final baseClient = http.Client();
      final accessCredentials = await obtainAccessCredentialsViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.database'],
        baseClient,
      );

      _client = authenticatedClient(
        baseClient,
        accessCredentials,
      );

      _accessToken = accessCredentials.accessToken.data;
      _conectado = true;

      print("Conectado ao Firebase Realtime Database com sucesso!");
    } catch (e) {
      print("❌ ERRO FATAL ao conectar ao Firebase:");
      print("Verifique se o arquivo 'serviceAccountKey.json' está na raiz.");
      print(e);
      _client?.close();
      exit(1);
    }
  }

  // ------------------------- CONSUMOS DIÁRIOS (consumos_diarios) -------------------------

  /// Busca consumos diários no Realtime Database, ignorando temporariamente o filtro 'sincronizado'.
  Future<List<ConsumoDiario>> getConsumosDiariosNaoSincronizados() async {
    if (!_conectado || _client == null || _accessToken == null) return [];

    final consumosList = <ConsumoDiario>[];

    // Caminho para o nó de Consumos Diários
    final url =
        Uri.parse('$_databaseUrl/consumos_diarios.json?auth=$_accessToken');

    try {
      final response = await _client!.get(url);

      // --- ⚠️ CÓDIGO DE DEBUG (DIAGNÓSTICO) ⚠️ ---
      print('URL de Requisição: $url');
      print('Status Code da Resposta: ${response.statusCode}');
      // Mostra o início da resposta para verificar se há dados
      final body = response.body.length > 500
          ? response.body.substring(0, 500) + '...'
          : response.body;
      print('Corpo da Resposta: $body');
      // --- ⚠️ FIM DO CÓDIGO DE DEBUG ⚠️ ---

      if (response.statusCode == 200) {
        // Se a resposta for vazia, jsonDecode(response.body) retornará null.
        final data = jsonDecode(response.body) as Map<String, dynamic>?;

        // O nó 'consumos_diarios' contém sub-nós que são datas (ex: "2025-11-19")
        if (data != null) {
          data.forEach((dataKey, dataValue) {
            // dataKey é a chave do Firebase (a data)
            if (dataValue is Map<String, dynamic>) {
              final docData = dataValue;

              // 🚫 FILTRO DE SINCRONIZAÇÃO AINDA REMOVIDO PARA TESTE 🚫
              // final sincronizado = docData['sincronizado'];
              // if (sincronizado == null || sincronizado == false) {

              try {
                // Passa a dataKey (chave do Firebase) para o fromJson.
                consumosList.add(ConsumoDiario.fromJson(docData, dataKey));
              } catch (e) {
                print(
                    "❌ Erro ao converter Consumo Diário da data $dataKey: $e");
              }

              // } // FIM DO FILTRO REMOVIDO
            }
          });
        }
      } else {
        print(
            "❌ Erro ao buscar consumos diários: Status ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Erro FATAL ao buscar consumos diários no Realtime Database: $e");
    }

    print('Total de Consumos Diários encontrados: ${consumosList.length}');
    return consumosList;
  }

  /// Marca um Consumo Diário como 'sincronizado' no Realtime Database
  Future<void> marcarConsumoComoSincronizado(String dataKey) async {
    if (!_conectado || _client == null || _accessToken == null) return;

    try {
      // Caminho: /consumos_diarios/{dataKey}/sincronizado
      final url = Uri.parse(
          '$_databaseUrl/consumos_diarios/$dataKey/sincronizado.json?auth=$_accessToken');

      final response = await _client!.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(true),
      );

      if (response.statusCode != 200) {
        print(
            "❌ Erro ao marcar consumo $dataKey como sincronizado: Status ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Erro ao marcar consumo $dataKey como sincronizado: $e");
    }
  }

  // ------------------------- UTILITÁRIO -------------------------

  // Fecha o cliente HTTP ao sair do app
  void close() {
    _client?.close();
    print("Conexão Firebase (HTTP Client) fechada.");
  }
}
