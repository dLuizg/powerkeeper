// lib/firebase_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'models.dart';

class FirebaseService {
  http.Client? _client;
  String? _accessToken;

  final String _databaseUrl =
      'https://powerkeeper-synatec-default-rtdb.firebaseio.com';
  bool _conectado = false;

  bool get conectado => _conectado;

  /// Conecta ao Firebase usando o token de ambiente FIREBASE_TOKEN
  Future<void> connect() async {
    _accessToken = Platform.environment['FIREBASE_TOKEN'];

    if (_accessToken == null || _accessToken!.isEmpty) {
      print("❌ Token do Firebase não encontrado. Configure FIREBASE_TOKEN.");
      exit(1);
    }

    _client = http.Client();
    _conectado = true;
    print("Conectado ao Firebase Realtime Database com sucesso!");
  }

  // ------------------------- CONSUMOS DIÁRIOS -------------------------

  /// Busca consumos diários
  Future<List<ConsumoDiario>> getConsumosDiariosNaoSincronizados() async {
    if (!_conectado || _client == null || _accessToken == null) return [];

    final consumosList = <ConsumoDiario>[];
    final url =
        Uri.parse('$_databaseUrl/consumos_diarios.json?auth=$_accessToken');

    try {
      final response = await _client!.get(url);

      if (response.statusCode != 200) {
        print(
            "❌ Erro ao buscar consumos diários: Status ${response.statusCode}");
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>?;

      if (data != null) {
        data.forEach((dataKey, dataValue) {
          if (dataValue is Map<String, dynamic>) {
            try {
              consumosList.add(ConsumoDiario.fromJson(dataValue, dataKey));
            } catch (e) {
              print("❌ Erro ao converter Consumo Diário da data $dataKey: $e");
            }
          }
        });
      }
    } catch (e) {
      print("❌ Erro ao buscar consumos diários no Realtime Database: $e");
    }

    print('Total de Consumos Diários encontrados: ${consumosList.length}');
    return consumosList;
  }

  /// Marca um consumo diário como sincronizado
  Future<void> marcarConsumoComoSincronizado(String dataKey) async {
    if (!_conectado || _client == null || _accessToken == null) return;

    final url = Uri.parse(
        '$_databaseUrl/consumos_diarios/$dataKey/sincronizado.json?auth=$_accessToken');

    try {
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
  void close() {
    _client?.close();
    print("Conexão Firebase (HTTP Client) fechada.");
  }
}
