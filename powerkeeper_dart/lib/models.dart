// lib/models.dart

// A classe 'intl' não é estritamente necessária aqui, mas foi mantida por estar no original.
// import 'package:intl/intl.dart';

// ---------------------- CLASSE LEITURA (Revisada e Segura) ----------------------

class Leitura {
  final String firebaseDocId; // Chave do Firebase (ex: -OeRW...)
  final DateTime timeStamp;
  final double corrente;
  final double tensao;
  final int dispositivoId; // FK para MySQL

  Leitura({
    required this.firebaseDocId,
    required this.timeStamp,
    required this.corrente,
    required this.tensao,
    required this.dispositivoId,
  });

  // Construtor fromJson/fromRtdb seguro para lidar com nulos
  factory Leitura.fromRtdb(Map<String, dynamic> json, String docId) {
    final rawTimestamp = json['timestamp'];
    DateTime timeStamp;

    // Tratamento de timestamp (similar ao ConsumoDiario)
    if (rawTimestamp is String) {
      try {
        timeStamp = DateTime.parse(rawTimestamp);
      } catch (e) {
        timeStamp = DateTime.now();
      }
    } else {
      timeStamp = DateTime.now();
    }

    return Leitura(
      firebaseDocId: docId,
      timeStamp: timeStamp,
      // Usando operadores null-aware para segurança
      corrente: (json['corrente'] as num?)?.toDouble() ?? 0.0,
      tensao: (json['tensao'] as num?)?.toDouble() ?? 0.0,
      dispositivoId: json['idDispositivo'] as int? ?? 0,
    );
  }
}

// ---------------------- CLASSE CONSUMO DIÁRIO (CORRIGIDA) ----------------------

class ConsumoDiario {
  // NOVO CAMPO: Chave do Firebase (a data, ex: "2025-11-19") para marcar como sincronizado.
  final String firebaseKey;
  final double consumoKwh;
  final int dispositivoId; // Mapeia para dispositivo_idDispositivo
  final DateTime timeStamp;

  ConsumoDiario({
    required this.firebaseKey, // Adicionado ao construtor
    required this.consumoKwh,
    required this.dispositivoId,
    required this.timeStamp,
  });

  /**
   * Construtor de fábrica para criar ConsumoDiario a partir de um Map (JSON) 
   * vindo do Firebase.
   * * @param json O mapa de dados do consumo (contendo consumo_kWh, idDispositivo, timestamp).
   * @param key A chave do Firebase (o nó pai, que é a data, ex: "2025-11-19").
   */
  factory ConsumoDiario.fromJson(Map<String, dynamic> json, String key) {
    // 1. Tratamento seguro para 'consumo_kWh'
    final kwhValue = json['consumo_kWh'];
    double consumo = 0.0;
    if (kwhValue is num) {
      consumo = kwhValue.toDouble();
    } else if (kwhValue is String) {
      consumo = double.tryParse(kwhValue) ?? 0.0;
    }

    // 2. Tratamento seguro para 'idDispositivo'
    final dispositivoId = json['idDispositivo'] as int?;

    // 3. Tratamento para 'timestamp' (que é uma String formatada: "2025-11-20 00:55:48")
    DateTime timeStamp;
    final rawTimestamp = json['timestamp'];

    if (rawTimestamp is String) {
      // 🎯 Prioriza e usa tryParse para o formato de string ISO 8601 do Firebase
      timeStamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else if (rawTimestamp is int) {
      // Deixa a lógica de int como fallback, caso o formato mude no futuro.
      // Já que é um número baixo (ex: 6), pode ser um erro no dado.
      // MANTENDO A LÓGICA DE SEGUNDOS, POR SEGURANÇA, SE FOR UM ERRO DE FORMATO NO FIREBASE
      if (rawTimestamp.toString().length < 13) {
        timeStamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp * 1000);
      } else {
        timeStamp = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
      }
    } else {
      timeStamp = DateTime.now();
    }

    return ConsumoDiario(
      firebaseKey: key, // Chave do Firebase (a data)
      consumoKwh: consumo,
      dispositivoId: dispositivoId ?? 0,
      timeStamp: timeStamp,
    );
  }
}
