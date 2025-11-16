// lib/models.dart

import 'package:intl/intl.dart';

class Leitura {
  final String? firebaseDocId; 
  final DateTime timeStamp; // <-- MUDADO: Não pode ser nulo (removed ?)
  final double corrente;
  final double tensao;
  final int? dispositivoId; // Continua opcional (pois o database_service usa '?? 1')

  Leitura({
    this.firebaseDocId,
    required this.timeStamp, // <-- MUDADO: Agora é 'required'
    required this.corrente,
    required this.tensao,
    this.dispositivoId,
  });

  factory Leitura.fromRtdb(Map<String, dynamic> data, String docId) {
    DateTime? parsedTimestamp; // Começa nulo
    int? parsedDispositivoId;

    // --- Processamento do Timestamp ---
    final tsData = data['timestamp'];
    if (tsData is int) {
      // Se for um número (Epoch)
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(tsData);
    } else if (tsData is String && tsData != ".sv") { 
      // Se for uma string (mas não ".sv")
      try { parsedTimestamp = DateTime.parse(tsData); } catch (e) { /* ignora */ }
    }
    
    // --- A "GAMBIARRA" ESTÁ AQUI ---
    // Se, depois de tudo, o timestamp ainda for nulo (porque era ".sv"),
    // nós forçamos o script a usar a data/hora de AGORA.
    parsedTimestamp ??= DateTime.now();
    // -------------------------------
    
    // --- Processamento do dispositivoId ---
    final rawDispositivoId = data['dispositivoId'];
    if (rawDispositivoId != null && rawDispositivoId is int) {
      parsedDispositivoId = rawDispositivoId;
    }

    // --- Puxa os 3 campos ---
    final corrente = (data['corrente'] as num).toDouble();
    final tensao = (data['tensao'] as num).toDouble();

    return Leitura(
      firebaseDocId: docId,
      timeStamp: parsedTimestamp, // Agora é garantido que NUNCA será nulo
      corrente: corrente,
      tensao: tensao,
      dispositivoId: parsedDispositivoId,
    );
  }
}