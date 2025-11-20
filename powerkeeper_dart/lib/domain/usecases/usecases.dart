import '../entities/domain_entities.dart';
import '../repositories/abstract_repositories.dart';
import '../../data/datasources/remote_datasource.dart';

// Use Cases seguindo o princípio da responsabilidade única

abstract class UseCase<T, P> {
  Future<T> execute(P params);
}

abstract class StreamUseCase<T, P> {
  Stream<T> execute(P params);
}

class NoParams {
  const NoParams();
}

// Use Cases para Empresa
class CreateEmpresaUseCase implements UseCase<Empresa, CreateEmpresaParams> {
  final IEmpresaRepository repository;

  CreateEmpresaUseCase(this.repository);

  @override
  Future<Empresa> execute(CreateEmpresaParams params) async {
    return await repository.create(params.empresa);
  }
}

class CreateEmpresaParams {
  final Empresa empresa;

  CreateEmpresaParams(this.empresa);
}

class GetEmpresasUseCase implements UseCase<List<Empresa>, NoParams> {
  final IEmpresaRepository repository;

  GetEmpresasUseCase(this.repository);

  @override
  Future<List<Empresa>> execute(NoParams params) async {
    return await repository.findAll();
  }
}

class DeleteEmpresaUseCase implements UseCase<void, DeleteEmpresaParams> {
  final IEmpresaRepository repository;

  DeleteEmpresaUseCase(this.repository);

  @override
  Future<void> execute(DeleteEmpresaParams params) async {
    await repository.delete(params.id);
  }
}

class DeleteEmpresaParams {
  final int id;

  DeleteEmpresaParams(this.id);
}

// Use Cases para Funcionario
class CreateFuncionarioUseCase
    implements UseCase<Funcionario, CreateFuncionarioParams> {
  final IFuncionarioRepository repository;

  CreateFuncionarioUseCase(this.repository);

  @override
  Future<Funcionario> execute(CreateFuncionarioParams params) async {
    return await repository.create(params.funcionario);
  }
}

class CreateFuncionarioParams {
  final Funcionario funcionario;

  CreateFuncionarioParams(this.funcionario);
}

class GetFuncionariosUseCase implements UseCase<List<Funcionario>, NoParams> {
  final IFuncionarioRepository repository;

  GetFuncionariosUseCase(this.repository);

  @override
  Future<List<Funcionario>> execute(NoParams params) async {
    return await repository.findAll();
  }
}

class DeleteFuncionarioUseCase
    implements UseCase<void, DeleteFuncionarioParams> {
  final IFuncionarioRepository repository;

  DeleteFuncionarioUseCase(this.repository);

  @override
  Future<void> execute(DeleteFuncionarioParams params) async {
    await repository.delete(params.id);
  }
}

class DeleteFuncionarioParams {
  final int id;

  DeleteFuncionarioParams(this.id);
}

// Use Cases para Local
class CreateLocalUseCase implements UseCase<Local, CreateLocalParams> {
  final ILocalRepository repository;

  CreateLocalUseCase(this.repository);

  @override
  Future<Local> execute(CreateLocalParams params) async {
    return await repository.create(params.local);
  }
}

class CreateLocalParams {
  final Local local;

  CreateLocalParams(this.local);
}

class GetLocaisUseCase implements UseCase<List<Local>, NoParams> {
  final ILocalRepository repository;

  GetLocaisUseCase(this.repository);

  @override
  Future<List<Local>> execute(NoParams params) async {
    return await repository.findAll();
  }
}

class DeleteLocalUseCase implements UseCase<void, DeleteLocalParams> {
  final ILocalRepository repository;

  DeleteLocalUseCase(this.repository);

  @override
  Future<void> execute(DeleteLocalParams params) async {
    await repository.delete(params.id);
  }
}

class DeleteLocalParams {
  final int id;

  DeleteLocalParams(this.id);
}

// Use Cases para Dispositivo
class CreateDispositivoUseCase
    implements UseCase<Dispositivo, CreateDispositivoParams> {
  final IDispositivoRepository repository;

  CreateDispositivoUseCase(this.repository);

  @override
  Future<Dispositivo> execute(CreateDispositivoParams params) async {
    return await repository.create(params.dispositivo);
  }
}

class CreateDispositivoParams {
  final Dispositivo dispositivo;

  CreateDispositivoParams(this.dispositivo);
}

class GetDispositivosUseCase implements UseCase<List<Dispositivo>, NoParams> {
  final IDispositivoRepository repository;

  GetDispositivosUseCase(this.repository);

  @override
  Future<List<Dispositivo>> execute(NoParams params) async {
    return await repository.findAll();
  }
}

class DeleteDispositivoUseCase
    implements UseCase<void, DeleteDispositivoParams> {
  final IDispositivoRepository repository;

  DeleteDispositivoUseCase(this.repository);

  @override
  Future<void> execute(DeleteDispositivoParams params) async {
    await repository.delete(params.id);
  }
}

class DeleteDispositivoParams {
  final int id;

  DeleteDispositivoParams(this.id);
}

// Use Cases para Consumo Diário
class CreateConsumoDiarioUseCase
    implements UseCase<ConsumoDiario, CreateConsumoDiarioParams> {
  final IConsumoDiarioRepository repository;

  CreateConsumoDiarioUseCase(this.repository);

  @override
  Future<ConsumoDiario> execute(CreateConsumoDiarioParams params) async {
    return await repository.create(params.consumo);
  }
}

class CreateConsumoDiarioParams {
  final ConsumoDiario consumo;

  CreateConsumoDiarioParams(this.consumo);
}

class GetConsumosDiariosUseCase
    implements UseCase<List<ConsumoDiario>, NoParams> {
  final IConsumoDiarioRepository repository;

  GetConsumosDiariosUseCase(this.repository);

  @override
  Future<List<ConsumoDiario>> execute(NoParams params) async {
    return await repository.findAll();
  }
}

class DeleteConsumoDiarioUseCase
    implements UseCase<void, DeleteConsumoDiarioParams> {
  final IConsumoDiarioRepository repository;

  DeleteConsumoDiarioUseCase(this.repository);

  @override
  Future<void> execute(DeleteConsumoDiarioParams params) async {
    await repository.delete(params.id);
  }
}

class DeleteConsumoDiarioParams {
  final int id;

  DeleteConsumoDiarioParams(this.id);
}

// Use Case para Sincronização
class SyncConsumosDiariosUseCase implements UseCase<SyncResult, NoParams> {
  final IConsumoDiarioRepository localRepository;
  final IRemoteDataSource remoteDataSource;

  SyncConsumosDiariosUseCase({
    required this.localRepository,
    required this.remoteDataSource,
  });

  @override
  Future<SyncResult> execute(NoParams params) async {
    final consumosRemotos = await remoteDataSource.getConsumosDiarios();
    int sucessos = 0;
    int erros = 0;
    int duplicados = 0;

    for (final consumo in consumosRemotos) {
      try {
        // Verifica se já existe pelo firebaseKey
        final existente =
            await localRepository.findByFirebaseKey(consumo.firebaseKey);

        if (existente == null) {
          await localRepository.create(consumo);
          await remoteDataSource
              .marcarConsumoComoSincronizado(consumo.firebaseKey);
          sucessos++;
        } else {
          duplicados++;
        }
      } catch (e) {
        erros++;
        print('Erro ao sincronizar consumo ${consumo.firebaseKey}: $e');
      }
    }

    return SyncResult(
      sucessos: sucessos,
      erros: erros,
      duplicados: duplicados,
      total: consumosRemotos.length,
    );
  }
}

class SyncResult {
  final int sucessos;
  final int erros;
  final int duplicados;
  final int total;

  SyncResult({
    required this.sucessos,
    required this.erros,
    required this.duplicados,
    required this.total,
  });

  @override
  String toString() {
    return 'Sincronização: $sucessos/$total sucessos, $erros erros, $duplicados duplicados';
  }
}
