import 'dart:io';
import '../lib/data/datasources/local_datasource.dart';
import '../lib/data/datasources/remote_datasource.dart';
import '../lib/data/repositories/concrete_repositories.dart';
import '../lib/domain/usecases/usecases.dart';
import '../lib/presentation/cli/menus.dart';
import '../lib/presentation/utils/helpers.dart';

class DatabaseConfig {
  static const String host = 'localhost';
  static const int port = 3306;
  static const String user = 'root';
  static const String password = '296q';
  static const String database = 'powerkeeper';
}

void main() async {
  final accessToken = Platform.environment['FIREBASE_TOKEN'];
  if (accessToken == null) {
    print('❌ Variável de ambiente FIREBASE_TOKEN não encontrada');
    exit(1);
  }

  // Inicialização de dependências usando a classe de configuração
  final localDataSource = LocalDataSource(
    host: DatabaseConfig.host,
    port: DatabaseConfig.port,
    user: DatabaseConfig.user,
    password: DatabaseConfig.password,
    database: DatabaseConfig.database,
  );

  final remoteDataSource = FirebaseDataSource(
    databaseUrl: 'https://powerkeeper-synatec-default-rtdb.firebaseio.com',
    accessToken: accessToken,
  );

  // Repositórios
  final empresaRepository = EmpresaRepository(localDataSource);
  final funcionarioRepository = FuncionarioRepository(localDataSource);
  final localRepository = LocalRepository(localDataSource);
  final dispositivoRepository = DispositivoRepository(localDataSource);
  final consumoDiarioRepository = ConsumoDiarioRepository(localDataSource);

  // Use Cases
  final createEmpresaUseCase = CreateEmpresaUseCase(empresaRepository);
  final getEmpresasUseCase = GetEmpresasUseCase(empresaRepository);
  final deleteEmpresaUseCase = DeleteEmpresaUseCase(empresaRepository);

  final createFuncionarioUseCase =
      CreateFuncionarioUseCase(funcionarioRepository);
  final getFuncionariosUseCase = GetFuncionariosUseCase(funcionarioRepository);
  final deleteFuncionarioUseCase =
      DeleteFuncionarioUseCase(funcionarioRepository);

  final createLocalUseCase = CreateLocalUseCase(localRepository);
  final getLocaisUseCase = GetLocaisUseCase(localRepository);
  final deleteLocalUseCase = DeleteLocalUseCase(localRepository);

  final createDispositivoUseCase =
      CreateDispositivoUseCase(dispositivoRepository);
  final getDispositivosUseCase = GetDispositivosUseCase(dispositivoRepository);
  final deleteDispositivoUseCase =
      DeleteDispositivoUseCase(dispositivoRepository);

  final getConsumosDiariosUseCase =
      GetConsumosDiariosUseCase(consumoDiarioRepository);
  final deleteConsumoDiarioUseCase =
      DeleteConsumoDiarioUseCase(consumoDiarioRepository);

  final syncConsumosDiariosUseCase = SyncConsumosDiariosUseCase(
    localRepository: consumoDiarioRepository,
    remoteDataSource: remoteDataSource,
  );

  // Menu Manager
  final menuManager = MenuManager(
    createEmpresa: createEmpresaUseCase,
    getEmpresas: getEmpresasUseCase,
    deleteEmpresa: deleteEmpresaUseCase,
    createFuncionario: createFuncionarioUseCase,
    getFuncionarios: getFuncionariosUseCase,
    deleteFuncionario: deleteFuncionarioUseCase,
    createLocal: createLocalUseCase,
    getLocais: getLocaisUseCase,
    deleteLocal: deleteLocalUseCase,
    createDispositivo: createDispositivoUseCase,
    getDispositivos: getDispositivosUseCase,
    deleteDispositivo: deleteDispositivoUseCase,
    getConsumosDiarios: getConsumosDiariosUseCase,
    deleteConsumoDiario: deleteConsumoDiarioUseCase,
    syncConsumosDiarios: syncConsumosDiariosUseCase,
  );

  try {
    // Testar conexão com o banco
    DisplayHelper.showProgress('Conectando ao banco de dados');
    await localDataSource.connection;
    DisplayHelper.completeProgress();

    // Executar sistema
    menuManager.run();
  } catch (e) {
    DisplayHelper.showError('Erro fatal: $e');
    exit(1);
  } finally {
    // CORREÇÃO: Chamar close() sem await pois retornam void
    localDataSource.close();
    remoteDataSource.close();
  }
}
