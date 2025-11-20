import 'package:mysql1/mysql1.dart';
import '../../domain/entities/domain_entities.dart';

// Data Transfer Objects para mapeamento do banco de dados

class EmpresaDTO {
  final int? idEmpresa;
  final String nome;
  final String cnpj;
  final DateTime dataCriacao;

  EmpresaDTO({
    this.idEmpresa,
    required this.nome,
    required this.cnpj,
    required this.dataCriacao,
  });

  factory EmpresaDTO.fromRow(ResultRow row) {
    return EmpresaDTO(
      idEmpresa: row['idEmpresa'] as int?,
      nome: row['nome'] as String,
      cnpj: row['cnpj'] as String,
      dataCriacao: (row['dataCriacao'] as DateTime).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idEmpresa != null) 'idEmpresa': idEmpresa,
      'nome': nome,
      'cnpj': cnpj,
      'dataCriacao': dataCriacao.toUtc(),
    };
  }

  Empresa toEntity() {
    return Empresa(
      id: idEmpresa,
      nome: nome,
      cnpj: cnpj,
      dataCriacao: dataCriacao,
    );
  }

  static EmpresaDTO fromEntity(Empresa empresa) {
    return EmpresaDTO(
      idEmpresa: empresa.id,
      nome: empresa.nome,
      cnpj: empresa.cnpj,
      dataCriacao: empresa.dataCriacao,
    );
  }
}

class FuncionarioDTO {
  final int? idFuncionario;
  final String nome;
  final String email;
  final String senhaLogin;
  final int empresaIdEmpresa;
  final DateTime dataCriacao;

  FuncionarioDTO({
    this.idFuncionario,
    required this.nome,
    required this.email,
    required this.senhaLogin,
    required this.empresaIdEmpresa,
    required this.dataCriacao,
  });

  factory FuncionarioDTO.fromRow(ResultRow row) {
    return FuncionarioDTO(
      idFuncionario: row['idFuncionario'] as int?,
      nome: row['nome'] as String,
      email: row['email'] as String,
      senhaLogin: row['senhaLogin'] as String,
      empresaIdEmpresa: row['empresa_idEmpresa'] as int,
      dataCriacao: (row['dataCriacao'] as DateTime).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idFuncionario != null) 'idFuncionario': idFuncionario,
      'nome': nome,
      'email': email,
      'senhaLogin': senhaLogin,
      'empresa_idEmpresa': empresaIdEmpresa,
      'dataCriacao': dataCriacao.toUtc(),
    };
  }

  Funcionario toEntity() {
    return Funcionario(
      id: idFuncionario,
      nome: nome,
      email: email,
      senhaLogin: senhaLogin,
      empresaId: empresaIdEmpresa,
      dataCriacao: dataCriacao,
    );
  }

  static FuncionarioDTO fromEntity(Funcionario funcionario) {
    return FuncionarioDTO(
      idFuncionario: funcionario.id,
      nome: funcionario.nome,
      email: funcionario.email,
      senhaLogin: funcionario.senhaLogin,
      empresaIdEmpresa: funcionario.empresaId,
      dataCriacao: funcionario.dataCriacao,
    );
  }
}

class LocalDTO {
  final int? idLocal;
  final String nome;
  final String referencia;
  final int empresaIdEmpresa;
  final DateTime dataCriacao;

  LocalDTO({
    this.idLocal,
    required this.nome,
    required this.referencia,
    required this.empresaIdEmpresa,
    required this.dataCriacao,
  });

  factory LocalDTO.fromRow(ResultRow row) {
    return LocalDTO(
      idLocal: row['idLocal'] as int?,
      nome: row['nome'] as String,
      referencia: row['referencia'] as String,
      empresaIdEmpresa: row['empresa_idEmpresa'] as int,
      dataCriacao: (row['dataCriacao'] as DateTime).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idLocal != null) 'idLocal': idLocal,
      'nome': nome,
      'referencia': referencia,
      'empresa_idEmpresa': empresaIdEmpresa,
      'dataCriacao': dataCriacao.toUtc(),
    };
  }

  Local toEntity() {
    return Local(
      id: idLocal,
      nome: nome,
      referencia: referencia,
      empresaId: empresaIdEmpresa,
      dataCriacao: dataCriacao,
    );
  }

  static LocalDTO fromEntity(Local local) {
    return LocalDTO(
      idLocal: local.id,
      nome: local.nome,
      referencia: local.referencia,
      empresaIdEmpresa: local.empresaId,
      dataCriacao: local.dataCriacao,
    );
  }
}

class DispositivoDTO {
  final int? idDispositivo;
  final String modelo;
  final String status;
  final int localIdLocal;
  final DateTime dataCriacao;

  DispositivoDTO({
    this.idDispositivo,
    required this.modelo,
    required this.status,
    required this.localIdLocal,
    required this.dataCriacao,
  });

  factory DispositivoDTO.fromRow(ResultRow row) {
    return DispositivoDTO(
      idDispositivo: row['idDispositivo'] as int?,
      modelo: row['modelo'] as String,
      status: row['status'] as String,
      localIdLocal: row['local_idLocal'] as int,
      dataCriacao: (row['dataCriacao'] as DateTime).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idDispositivo != null) 'idDispositivo': idDispositivo,
      'modelo': modelo,
      'status': status,
      'local_idLocal': localIdLocal,
      'dataCriacao': dataCriacao.toUtc(),
    };
  }

  Dispositivo toEntity() {
    return Dispositivo(
      id: idDispositivo,
      modelo: modelo,
      status: status,
      localId: localIdLocal,
      dataCriacao: dataCriacao,
    );
  }

  static DispositivoDTO fromEntity(Dispositivo dispositivo) {
    return DispositivoDTO(
      idDispositivo: dispositivo.id,
      modelo: dispositivo.modelo,
      status: dispositivo.status,
      localIdLocal: dispositivo.localId,
      dataCriacao: dispositivo.dataCriacao,
    );
  }
}

class ConsumoDiarioDTO {
  final int? idLeitura;
  final DateTime timeStamp;
  final double consumoKwh;
  final int dispositivoIdDispositivo;
  final String? firebaseKey;

  ConsumoDiarioDTO({
    this.idLeitura,
    required this.timeStamp,
    required this.consumoKwh,
    required this.dispositivoIdDispositivo,
    this.firebaseKey,
  });

  factory ConsumoDiarioDTO.fromRow(ResultRow row) {
    return ConsumoDiarioDTO(
      idLeitura: row['idLeitura'] as int?,
      timeStamp: (row['timeStamp'] as DateTime).toLocal(),
      consumoKwh: (row['consumoKwh'] as num).toDouble(),
      dispositivoIdDispositivo: row['dispositivo_idDispositivo'] as int,
      firebaseKey: row['firebaseKey'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idLeitura != null) 'idLeitura': idLeitura,
      'timeStamp': timeStamp.toUtc(),
      'consumoKwh': consumoKwh,
      'dispositivo_idDispositivo': dispositivoIdDispositivo,
      if (firebaseKey != null) 'firebaseKey': firebaseKey,
    };
  }

  ConsumoDiario toEntity() {
    return ConsumoDiario(
      id: idLeitura,
      timeStamp: timeStamp,
      consumoKwh: consumoKwh,
      dispositivoId: dispositivoIdDispositivo,
      firebaseKey: firebaseKey ?? '',
    );
  }

  static ConsumoDiarioDTO fromEntity(ConsumoDiario consumo) {
    return ConsumoDiarioDTO(
      idLeitura: consumo.id,
      timeStamp: consumo.timeStamp,
      consumoKwh: consumo.consumoKwh,
      dispositivoIdDispositivo: consumo.dispositivoId,
      firebaseKey: consumo.firebaseKey.isNotEmpty ? consumo.firebaseKey : null,
    );
  }
}

class LeituraDTO {
  final int? idLeitura;
  final DateTime timeStamp;
  final double corrente;
  final double tensao;
  final int dispositivoIdDispositivo;
  final String? firebaseDocId;

  LeituraDTO({
    this.idLeitura,
    required this.timeStamp,
    required this.corrente,
    required this.tensao,
    required this.dispositivoIdDispositivo,
    this.firebaseDocId,
  });

  factory LeituraDTO.fromRow(ResultRow row) {
    return LeituraDTO(
      idLeitura: row['idLeitura'] as int?,
      timeStamp: (row['timeStamp'] as DateTime).toLocal(),
      corrente: (row['corrente'] as num).toDouble(),
      tensao: (row['tensao'] as num).toDouble(),
      dispositivoIdDispositivo: row['dispositivo_idDispositivo'] as int,
      firebaseDocId: row['firebaseDocId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (idLeitura != null) 'idLeitura': idLeitura,
      'timeStamp': timeStamp.toUtc(),
      'corrente': corrente,
      'tensao': tensao,
      'dispositivo_idDispositivo': dispositivoIdDispositivo,
      if (firebaseDocId != null) 'firebaseDocId': firebaseDocId,
    };
  }

  Leitura toEntity() {
    return Leitura(
      id: idLeitura,
      timeStamp: timeStamp,
      corrente: corrente,
      tensao: tensao,
      dispositivoId: dispositivoIdDispositivo,
      firebaseDocId: firebaseDocId ?? '',
    );
  }

  static LeituraDTO fromEntity(Leitura leitura) {
    return LeituraDTO(
      idLeitura: leitura.id,
      timeStamp: leitura.timeStamp,
      corrente: leitura.corrente,
      tensao: leitura.tensao,
      dispositivoIdDispositivo: leitura.dispositivoId,
      firebaseDocId:
          leitura.firebaseDocId.isNotEmpty ? leitura.firebaseDocId : null,
    );
  }
}
