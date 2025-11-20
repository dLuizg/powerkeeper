import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/exceptions/database_exceptions.dart';
import '../../domain/entities/domain_entities.dart';

abstract class IRemoteDataSource {
  Future<List<ConsumoDiario>> getConsumosDiarios();
  Future<void> marcarConsumoComoSincronizado(String firebaseKey);
  Future<void> close();
}

class FirebaseDataSource implements IRemoteDataSource {
  final http.Client _client;
  final String _databaseUrl;
  final String _accessToken;
  bool _isConnected = false;

  FirebaseDataSource({
    required String databaseUrl,
    required String accessToken,
    http.Client? client,
  })  : _databaseUrl = databaseUrl,
        _accessToken = accessToken,
        _client = client ?? http.Client();

  @override
  Future<List<ConsumoDiario>> getConsumosDiarios() async {
    final url =
        Uri.parse('$_databaseUrl/consumos_diarios.json?auth=$_accessToken');

    try {
      final response = await _client.get(url);

      if (response.statusCode != 200) {
        throw QueryException(
          'GET consumos_diarios',
          'HTTP ${response.statusCode}: ${response.body}',
          StackTrace.current,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final consumos = <ConsumoDiario>[];

      if (data != null) {
        for (final entry in data.entries) {
          if (entry.value is Map<String, dynamic>) {
            try {
              final consumo = _parseConsumoDiario(entry.value, entry.key);
              consumos.add(consumo);
            } catch (e) {
              print('Warning: Failed to parse consumo ${entry.key}: $e');
            }
          }
        }
      }

      return consumos;
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw QueryException(
        'GET consumos_diarios',
        'Failed to fetch consumos: $e',
        StackTrace.current,
      );
    }
  }

  ConsumoDiario _parseConsumoDiario(
      Map<String, dynamic> json, String firebaseKey) {
    final kwhValue = json['consumo_kWh'];
    final consumo = kwhValue is num
        ? kwhValue.toDouble()
        : kwhValue is String
            ? double.tryParse(kwhValue) ?? 0.0
            : 0.0;

    final dispositivoId = json['idDispositivo'] as int? ?? 0;

    DateTime timeStamp;
    final rawTimestamp = json['timestamp'];
    if (rawTimestamp is String) {
      timeStamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else {
      timeStamp = DateTime.now();
    }

    return ConsumoDiario(
      timeStamp: timeStamp,
      consumoKwh: consumo,
      dispositivoId: dispositivoId,
      firebaseKey: firebaseKey,
    );
  }

  @override
  Future<void> marcarConsumoComoSincronizado(String firebaseKey) async {
    final url = Uri.parse(
      '$_databaseUrl/consumos_diarios/$firebaseKey/sincronizado.json?auth=$_accessToken',
    );

    try {
      final response = await _client.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(true),
      );

      if (response.statusCode != 200) {
        throw QueryException(
          'PUT consumo_sincronizado',
          'HTTP ${response.statusCode}: ${response.body}',
          StackTrace.current,
        );
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw QueryException(
        'PUT consumo_sincronizado',
        'Failed to mark consumo as synchronized: $e',
        StackTrace.current,
      );
    }
  }

  @override
  Future<void> close() {
    _client.close();
    return Future.value();
  }
}
