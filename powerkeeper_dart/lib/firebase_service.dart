// lib/firebase_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'models.dart'; // Nosso arquivo de modelos (Leitura)

class FirebaseService {
  http.Client? _client;
  String? _projectId;
  String? _accessToken;

  // !!! VERIFIQUE SE ESTA É A URL DO SEU REALTIME DATABASE !!!
  final String _databaseUrl =
      'https://powerkeeper-33345-default-rtdb.firebaseio.com';
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
      print("ERRO FATAL ao conectar ao Firebase:");
      print("Verifique se o arquivo 'serviceAccountKey.json' está na raiz.");
      print(e);
      _client?.close();
      exit(1);
    }
  }

  // Busca leituras no Realtime Database que ainda não foram lidas
  Future<List<Leitura>> getNaoSincronizadas() async {
    if (!_conectado || _client == null || _accessToken == null) return [];

    final leiturasList = <Leitura>[];

    // --- CAMINHO NO FIREBASE ---
    // Certifique-se de que este é o nó que o seu ESP32 está usando
    // (ex: /historico_leituras ou /leituras)
    final url =
        Uri.parse('$_databaseUrl/historico_leituras.json?auth=$_accessToken');

    try {
      final response = await _client!.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;

        if (data != null) {
          data.forEach((docId, docData) {
            if (docData is Map<String, dynamic>) {
              final lida = docData['lida'];
              if (lida == null || lida == false) {
                try {
                  // Usa o 'models.dart' para converter os dados
                  leiturasList.add(Leitura.fromRtdb(docData, docId));
                } catch (e) {
                  print(
                      "Erro ao converter leitura $docId (formato inválido?): $e");
                }
              }
            }
          });
        }
      } else {
        print("Erro ao buscar leituras: Status ${response.statusCode}");
        print("Resposta: ${response.body}");
      }
    } catch (e) {
      print("Erro ao buscar leituras no Realtime Database: $e");
    }

    return leiturasList;
  }

  // Marca uma leitura como 'lida' no Realtime Database
  Future<void> marcarComoSincronizada(String docId) async {
    if (!_conectado || _client == null || _accessToken == null) return;

    try {
      // --- CAMINHO NO FIREBASE ---
      // Deve ser o mesmo caminho da função acima
      final url = Uri.parse(
          '$_databaseUrl/historico_leituras/$docId/lida.json?auth=$_accessToken');

      final response = await _client!.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(true),
      );

      if (response.statusCode != 200) {
        print(
            "Erro ao marcar leitura $docId como sincronizada: Status ${response.statusCode}");
      }
    } catch (e) {
      print("Erro ao marcar leitura $docId como sincronizada: $e");
    }
  }

  // Fecha o cliente HTTP ao sair do app
  void close() {
    _client?.close();
    print("Conexão Firebase (HTTP Client) fechada.");
  }
}
