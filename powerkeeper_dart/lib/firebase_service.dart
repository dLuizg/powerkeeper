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

  // !!! IMPORTANTE: Cole a URL do seu Realtime Database aqui !!!
  final String _databaseUrl = 'https://powerkeeper-33345-default-rtdb.firebaseio.com/';
  bool _conectado = false;
  
  bool get conectado => _conectado;

  Future<void> connect() async {
    try {
      // 1. Carregar as credenciais do JSON
      final jsonCredentials = await File('serviceAccountKey.json').readAsString();
      final credentialsMap = jsonDecode(jsonCredentials) as Map<String, dynamic>;
      
      _projectId = credentialsMap['project_id'] as String?;

      if (_projectId == null) {
        throw Exception('project_id não encontrado no arquivo de credenciais');
      }

      // 2. Criar credenciais da conta de serviço
      final credentials = ServiceAccountCredentials.fromJson(credentialsMap);

      // 3. Obter token de acesso para Firebase Realtime Database
      final baseClient = http.Client();
      final accessCredentials = await obtainAccessCredentialsViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/firebase.database'],
        baseClient,
      );

      // 4. Criar cliente autenticado
      _client = authenticatedClient(
        baseClient,
        accessCredentials,
      );

      // 5. Obter o token de acesso
      _accessToken = accessCredentials.accessToken.data;

      _conectado = true;

      print("Conectado ao Firebase Realtime Database com sucesso!");
    } catch (e) {
      print("ERRO FATAL ao conectar ao Firebase:");
      print("Verifique se o arquivo 'serviceAccountKey.json' está na raiz do projeto.");
      print(e);
      _client?.close(); // Fecha o cliente se a conexão falhar
      exit(1);
    }
  }

  // Busca leituras no Realtime Database que ainda não foram lidas
  Future<List<Leitura>> getNaoSincronizadas() async {
    if (!_conectado || _client == null || _accessToken == null) return [];

    final leiturasList = <Leitura>[];
    // Adiciona 'orderBy="lida"&equalTo=false' para filtrar no servidor
    // (Isso requer que 'lida' seja false. Se for null, a query abaixo é melhor)
    // final url = Uri.parse('$_databaseUrl/leituras.json?orderBy="lida"&equalTo=false&auth=$_accessToken');
    
    // Query para buscar TUDO de /leituras
    final url = Uri.parse('$_databaseUrl/historico_leituras.json?auth=$_accessToken');

    try {
      final response = await _client!.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        
        if (data != null) {
          // Processar cada leitura
          data.forEach((docId, docData) {
            if (docData is Map<String, dynamic>) {
              // Filtrar apenas leituras onde 'lida' == false ou não existe
              final lida = docData['lida'];
              if (lida == null || lida == false) {
                try {
                  // *** AQUI USAMOS O 'models.dart' ***
                  leiturasList.add(Leitura.fromRtdb(docData, docId));
                } catch (e) {
                  print("Erro ao processar leitura $docId (formato inválido?): $e");
                  // Não adiciona à lista se o formato estiver errado
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
      // Usando PATCH em vez de PUT para não apagar outros campos em /leituras/$docId
      // final url = Uri.parse('$_databaseUrl/leituras/$docId.json?auth=$_accessToken');
      // final response = await _client!.patch(
      //   url,
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonEncode({'lida': true}), // Atualiza apenas o campo 'lida'
      // );

      // O seu método original (PUT em /lida) também funciona perfeitamente
      final url = Uri.parse('$_databaseUrl/leituras/$docId/lida.json?auth=$_accessToken');
      final response = await _client!.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(true),
      );

      if (response.statusCode != 200) {
        print("Erro ao marcar leitura $docId como sincronizada: Status ${response.statusCode}");
        print("Resposta: ${response.body}");
      }
    } catch (e) {
      print("Erro ao marcar leitura $docId como sincronizada: $e");
    }
  }

  // Adicionado para fechar o cliente HTTP ao sair do app
  void close() {
    _client?.close();
    print("Conexão Firebase (HTTP Client) fechada.");
  }
}