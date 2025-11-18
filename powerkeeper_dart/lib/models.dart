// lib/models.dart

import 'package:intl/intl.dart';

class Leitura {
  final String? firebaseDocId;
  final DateTime timeStamp;
  final double corrente;
  final double tensao;
  final int dispositivoId;

  Leitura({
    this.firebaseDocId,
    required this.timeStamp,
    required this.corrente,
    required this.tensao,
    required this.dispositivoId,
  });

  factory Leitura.fromRtdb(Map<String, dynamic> data, String docId) {
    try {
      // Pega a string de data do Firebase
      final tsString = data['timestamp'] as String;

      // --- CORREÇÃO DO ERRO UTC ---
      // Adiciona um 'Z' no final para forçar o Dart a
      // tratar esta string como UTC.
      final tsStringUtc = tsString.endsWith('Z') ? tsString : "${tsString}Z";

      return Leitura(
        firebaseDocId: docId,
        // Faz o parse da string com o 'Z'
        timeStamp: DateTime.parse(tsStringUtc),

        corrente: (data['corrente'] as num).toDouble(),
        tensao: (data['tensao'] as num).toDouble(),

        // --- CORREÇÃO DO NOME DO CAMPO ---
        // Lê o campo 'dispositivo_idDispositivo' que o ESP32 envia
        dispositivoId: data['dispositivo_idDispositivo'] as int,
      );
    } catch (e) {
      print("Erro ao converter dados do Firebase: $e");
      print("Dados recebidos: $data");
      throw Exception('Formato de dados "Leitura" inválido: $e');
    }
  }
}
