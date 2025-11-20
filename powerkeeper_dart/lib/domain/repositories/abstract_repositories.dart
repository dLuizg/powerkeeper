import '../entities/domain_entities.dart';
import '../../core/interfaces/repository_interface.dart';

abstract class IEmpresaRepository extends ICrudRepository<Empresa> {
  Future<Empresa?> findByCnpj(String cnpj);
}

abstract class IFuncionarioRepository extends ICrudRepository<Funcionario> {
  Future<List<Funcionario>> findByEmpresaId(int empresaId);
  Future<Funcionario?> findByEmail(String email);
}

abstract class ILocalRepository extends ICrudRepository<Local> {
  Future<List<Local>> findByEmpresaId(int empresaId);
}

abstract class IDispositivoRepository extends ICrudRepository<Dispositivo> {
  Future<List<Dispositivo>> findByLocalId(int localId);
  Future<List<Dispositivo>> findByStatus(String status);
}

abstract class IConsumoDiarioRepository extends ICrudRepository<ConsumoDiario> {
  Future<List<ConsumoDiario>> findByDispositivoId(int dispositivoId);
  Future<List<ConsumoDiario>> findByPeriodo(DateTime inicio, DateTime fim);
  Future<ConsumoDiario?> findByFirebaseKey(String firebaseKey);
}

abstract class ILeituraRepository extends ICrudRepository<Leitura> {
  Future<List<Leitura>> findByDispositivoId(int dispositivoId);
  Future<List<Leitura>> findByPeriodo(DateTime inicio, DateTime fim);
}
