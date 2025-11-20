abstract class Entity {
  dynamic get id;
}

class Empresa implements Entity {
  @override
  final int? id;
  final String nome;
  final String cnpj;
  final DateTime dataCriacao;

  Empresa({
    this.id,
    required this.nome,
    required this.cnpj,
    DateTime? dataCriacao,
  }) : dataCriacao = dataCriacao ?? DateTime.now();

  Empresa copyWith({
    int? id,
    String? nome,
    String? cnpj,
    DateTime? dataCriacao,
  }) {
    return Empresa(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      cnpj: cnpj ?? this.cnpj,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Empresa &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nome == other.nome &&
          cnpj == other.cnpj;

  @override
  int get hashCode => id.hashCode ^ nome.hashCode ^ cnpj.hashCode;

  @override
  String toString() => 'Empresa(id: $id, nome: $nome, cnpj: $cnpj)';
}

class Funcionario implements Entity {
  @override
  final int? id;
  final String nome;
  final String email;
  final String senhaLogin;
  final int empresaId;
  final DateTime dataCriacao;

  Funcionario({
    this.id,
    required this.nome,
    required this.email,
    required this.senhaLogin,
    required this.empresaId,
    DateTime? dataCriacao,
  }) : dataCriacao = dataCriacao ?? DateTime.now();

  Funcionario copyWith({
    int? id,
    String? nome,
    String? email,
    String? senhaLogin,
    int? empresaId,
    DateTime? dataCriacao,
  }) {
    return Funcionario(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      senhaLogin: senhaLogin ?? this.senhaLogin,
      empresaId: empresaId ?? this.empresaId,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Funcionario &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nome == other.nome &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ nome.hashCode ^ email.hashCode;

  @override
  String toString() => 'Funcionario(id: $id, nome: $nome, email: $email)';
}

class Local implements Entity {
  @override
  final int? id;
  final String nome;
  final String referencia;
  final int empresaId;
  final DateTime dataCriacao;

  Local({
    this.id,
    required this.nome,
    required this.referencia,
    required this.empresaId,
    DateTime? dataCriacao,
  }) : dataCriacao = dataCriacao ?? DateTime.now();

  Local copyWith({
    int? id,
    String? nome,
    String? referencia,
    int? empresaId,
    DateTime? dataCriacao,
  }) {
    return Local(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      referencia: referencia ?? this.referencia,
      empresaId: empresaId ?? this.empresaId,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Local &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          nome == other.nome &&
          referencia == other.referencia;

  @override
  int get hashCode => id.hashCode ^ nome.hashCode ^ referencia.hashCode;

  @override
  String toString() => 'Local(id: $id, nome: $nome, referencia: $referencia)';
}

class Dispositivo implements Entity {
  @override
  final int? id;
  final String modelo;
  final String status;
  final int localId;
  final DateTime dataCriacao;

  Dispositivo({
    this.id,
    required this.modelo,
    required this.status,
    required this.localId,
    DateTime? dataCriacao,
  }) : dataCriacao = dataCriacao ?? DateTime.now();

  Dispositivo copyWith({
    int? id,
    String? modelo,
    String? status,
    int? localId,
    DateTime? dataCriacao,
  }) {
    return Dispositivo(
      id: id ?? this.id,
      modelo: modelo ?? this.modelo,
      status: status ?? this.status,
      localId: localId ?? this.localId,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Dispositivo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          modelo == other.modelo;

  @override
  int get hashCode => id.hashCode ^ modelo.hashCode;

  @override
  String toString() => 'Dispositivo(id: $id, modelo: $modelo, status: $status)';
}

class ConsumoDiario implements Entity {
  @override
  final int? id;
  final DateTime timeStamp;
  final double consumoKwh;
  final int dispositivoId;
  final String firebaseKey;

  ConsumoDiario({
    this.id,
    required this.timeStamp,
    required this.consumoKwh,
    required this.dispositivoId,
    required this.firebaseKey,
  });

  ConsumoDiario copyWith({
    int? id,
    DateTime? timeStamp,
    double? consumoKwh,
    int? dispositivoId,
    String? firebaseKey,
  }) {
    return ConsumoDiario(
      id: id ?? this.id,
      timeStamp: timeStamp ?? this.timeStamp,
      consumoKwh: consumoKwh ?? this.consumoKwh,
      dispositivoId: dispositivoId ?? this.dispositivoId,
      firebaseKey: firebaseKey ?? this.firebaseKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsumoDiario &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          timeStamp == other.timeStamp &&
          dispositivoId == other.dispositivoId;

  @override
  int get hashCode => id.hashCode ^ timeStamp.hashCode ^ dispositivoId.hashCode;

  @override
  String toString() => 'ConsumoDiario(id: $id, dispositivoId: $dispositivoId, '
      'consumo: ${consumoKwh}kWh, data: $timeStamp)';
}

class Leitura implements Entity {
  @override
  final int? id;
  final DateTime timeStamp;
  final double corrente;
  final double tensao;
  final int dispositivoId;
  final String firebaseDocId;

  Leitura({
    this.id,
    required this.timeStamp,
    required this.corrente,
    required this.tensao,
    required this.dispositivoId,
    required this.firebaseDocId,
  });

  Leitura copyWith({
    int? id,
    DateTime? timeStamp,
    double? corrente,
    double? tensao,
    int? dispositivoId,
    String? firebaseDocId,
  }) {
    return Leitura(
      id: id ?? this.id,
      timeStamp: timeStamp ?? this.timeStamp,
      corrente: corrente ?? this.corrente,
      tensao: tensao ?? this.tensao,
      dispositivoId: dispositivoId ?? this.dispositivoId,
      firebaseDocId: firebaseDocId ?? this.firebaseDocId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Leitura &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          timeStamp == other.timeStamp &&
          dispositivoId == other.dispositivoId;

  @override
  int get hashCode => id.hashCode ^ timeStamp.hashCode ^ dispositivoId.hashCode;

  @override
  String toString() => 'Leitura(id: $id, dispositivoId: $dispositivoId, '
      'corrente: ${corrente}A, tensao: ${tensao}V)';
}
