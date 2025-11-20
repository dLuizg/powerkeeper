import 'dart:io';
import '../../domain/entities/domain_entities.dart';
import '../../domain/usecases/usecases.dart';
import '../utils/helpers.dart';

class MenuManager {
  final CreateEmpresaUseCase createEmpresa;
  final GetEmpresasUseCase getEmpresas;
  final DeleteEmpresaUseCase deleteEmpresa;
  final CreateFuncionarioUseCase createFuncionario;
  final GetFuncionariosUseCase getFuncionarios;
  final DeleteFuncionarioUseCase deleteFuncionario;
  final CreateLocalUseCase createLocal;
  final GetLocaisUseCase getLocais;
  final DeleteLocalUseCase deleteLocal;
  final CreateDispositivoUseCase createDispositivo;
  final GetDispositivosUseCase getDispositivos;
  final DeleteDispositivoUseCase deleteDispositivo;
  final GetConsumosDiariosUseCase getConsumosDiarios;
  final DeleteConsumoDiarioUseCase deleteConsumoDiario;
  final SyncConsumosDiariosUseCase syncConsumosDiarios;

  MenuManager({
    required this.createEmpresa,
    required this.getEmpresas,
    required this.deleteEmpresa,
    required this.createFuncionario,
    required this.getFuncionarios,
    required this.deleteFuncionario,
    required this.createLocal,
    required this.getLocais,
    required this.deleteLocal,
    required this.createDispositivo,
    required this.getDispositivos,
    required this.deleteDispositivo,
    required this.getConsumosDiarios,
    required this.deleteConsumoDiario,
    required this.syncConsumosDiarios,
  });

  void run() async {
    DisplayHelper.clearScreen();
    DisplayHelper.showTitle(
        '⚡ PowerKeeper CLI - Sistema de Monitoramento Energético');

    while (true) {
      _showMainMenu();
      final opcao = InputHelper.prompt('Escolha uma opção: ');

      switch (opcao) {
        case '1':
          await _menuEmpresas();
          break;
        case '2':
          await _menuFuncionarios();
          break;
        case '3':
          await _menuLocais();
          break;
        case '4':
          await _menuDispositivos();
          break;
        case '5':
          await _menuConsumoDiario();
          break;
        case '0':
          DisplayHelper.showSuccess('Saindo do sistema...');
          return;
        default:
          DisplayHelper.showError('Opção inválida!');
      }

      DisplayHelper.waitForUser();
      DisplayHelper.clearScreen();
    }
  }

  void _showMainMenu() {
    DisplayHelper.showTitle('Menu Principal');
    print('1. 🏢 Empresas');
    print('2. 👥 Funcionários');
    print('3. 📍 Locais');
    print('4. 📱 Dispositivos');
    print('5. ⚡ Consumo Diário');
    print('0. 🚪 Sair');
    print('');
  }

  Future<void> _menuEmpresas() async {
    while (true) {
      DisplayHelper.showTitle('Gestão de Empresas');
      print('1. ➕ Adicionar Empresa');
      print('2. 📋 Listar Empresas');
      print('3. 🗑️  Deletar Empresa');
      print('0. ↩️  Voltar');
      print('');

      final opcao = InputHelper.prompt('Escolha uma opção: ');

      switch (opcao) {
        case '1':
          await _adicionarEmpresa();
          break;
        case '2':
          await _listarEmpresas();
          break;
        case '3':
          await _deletarEmpresa();
          break;
        case '0':
          return;
        default:
          DisplayHelper.showError('Opção inválida!');
      }

      if (opcao != '0') {
        DisplayHelper.waitForUser();
        DisplayHelper.clearScreen();
      }
    }
  }

  Future<void> _adicionarEmpresa() async {
    DisplayHelper.showSection('Nova Empresa');

    final nome = InputHelper.prompt('Nome da empresa: ');
    final cnpj = InputHelper.prompt('CNPJ: ');

    final nomeError = Validators.validateRequired(nome, 'Nome');
    final cnpjError = Validators.validateCNPJ(cnpj);

    if (nomeError != null) {
      DisplayHelper.showError(nomeError);
      return;
    }

    if (cnpjError != null) {
      DisplayHelper.showError(cnpjError);
      return;
    }

    try {
      final empresa = Empresa(nome: nome, cnpj: cnpj);
      await createEmpresa.execute(CreateEmpresaParams(empresa));
      DisplayHelper.showSuccess('Empresa adicionada com sucesso!');
    } catch (e) {
      DisplayHelper.showError('Erro ao adicionar empresa: $e');
    }
  }

  Future<void> _listarEmpresas() async {
    try {
      final empresas = await getEmpresas.execute(const NoParams());

      final data = empresas.map((empresa) {
        return {
          'ID': empresa.id,
          'Nome': empresa.nome,
          'CNPJ': Formatters.formatCNPJ(empresa.cnpj),
          'Data Criação': Formatters.formatDateTime(empresa.dataCriacao),
        };
      }).toList();

      DisplayHelper.showTable(data, 'Empresas Cadastradas');
    } catch (e) {
      DisplayHelper.showError('Erro ao listar empresas: $e');
    }
  }

  Future<void> _deletarEmpresa() async {
    try {
      final empresas = await getEmpresas.execute(const NoParams());

      if (empresas.isEmpty) {
        DisplayHelper.showInfo('Nenhuma empresa cadastrada.');
        return;
      }

      final data = empresas.map((empresa) {
        return {
          'ID': empresa.id,
          'Nome': empresa.nome,
          'CNPJ': Formatters.formatCNPJ(empresa.cnpj),
        };
      }).toList();

      DisplayHelper.showTable(data, 'Empresas Disponíveis para Deleção');

      final id =
          InputHelper.promptInt('Digite o ID da empresa a ser deletada: ');

      if (!InputHelper.promptBoolean('Confirma a exclusão da empresa $id?')) {
        DisplayHelper.showInfo('Operação cancelada.');
        return;
      }

      await deleteEmpresa.execute(DeleteEmpresaParams(id));
      DisplayHelper.showSuccess('Empresa deletada com sucesso!');
    } catch (e) {
      DisplayHelper.showError('Erro ao deletar empresa: $e');
    }
  }

  Future<void> _menuFuncionarios() async {
    while (true) {
      DisplayHelper.showTitle('Gestão de Funcionários');
      print('1. ➕ Adicionar Funcionário');
      print('2. 📋 Listar Funcionários');
      print('3. 🗑️  Deletar Funcionário');
      print('0. ↩️  Voltar');
      print('');

      final opcao = InputHelper.prompt('Escolha uma opção: ');

      switch (opcao) {
        case '1':
          await _adicionarFuncionario();
          break;
        case '2':
          await _listarFuncionarios();
          break;
        case '3':
          await _deletarFuncionario();
          break;
        case '0':
          return;
        default:
          DisplayHelper.showError('Opção inválida!');
      }

      if (opcao != '0') {
        DisplayHelper.waitForUser();
        DisplayHelper.clearScreen();
      }
    }
  }

  Future<void> _adicionarFuncionario() async {
    DisplayHelper.showSection('Novo Funcionário');

    // Primeiro lista empresas para referência
    try {
      final empresas = await getEmpresas.execute(const NoParams());
      if (empresas.isEmpty) {
        DisplayHelper.showError(
            'Nenhuma empresa cadastrada. Cadastre uma empresa primeiro.');
        return;
      }

      final empresasData = empresas.map((empresa) {
        return {
          'ID': empresa.id,
          'Nome': empresa.nome,
        };
      }).toList();

      DisplayHelper.showTable(empresasData, 'Empresas Disponíveis');

      final nome = InputHelper.prompt('Nome do funcionário: ');
      final email = InputHelper.prompt('Email: ');
      final senha = InputHelper.prompt('Senha: ');
      final empresaId = InputHelper.promptInt('ID da Empresa: ');

      final nomeError = Validators.validateRequired(nome, 'Nome');
      final emailError = Validators.validateEmail(email);
      final senhaError = Validators.validateRequired(senha, 'Senha');

      if (nomeError != null) {
        DisplayHelper.showError(nomeError);
        return;
      }
      if (emailError != null) {
        DisplayHelper.showError(emailError);
        return;
      }
      if (senhaError != null) {
        DisplayHelper.showError(senhaError);
        return;
      }

      final funcionario = Funcionario(
        nome: nome,
        email: email,
        senhaLogin: senha,
        empresaId: empresaId,
      );

      await createFuncionario.execute(CreateFuncionarioParams(funcionario));
      DisplayHelper.showSuccess('Funcionário adicionado com sucesso!');
    } catch (e) {
      DisplayHelper.showError('Erro ao adicionar funcionário: $e');
    }
  }

  Future<void> _listarFuncionarios() async {
    try {
      final funcionarios = await getFuncionarios.execute(const NoParams());

      final data = funcionarios.map((funcionario) {
        return {
          'ID': funcionario.id,
          'Nome': funcionario.nome,
          'Email': funcionario.email,
          'Empresa ID': funcionario.empresaId,
          'Data Criação': Formatters.formatDateTime(funcionario.dataCriacao),
        };
      }).toList();

      DisplayHelper.showTable(data, 'Funcionários Cadastrados');
    } catch (e) {
      DisplayHelper.showError('Erro ao listar funcionários: $e');
    }
  }

  Future<void> _deletarFuncionario() async {
    try {
      final funcionarios = await getFuncionarios.execute(const NoParams());

      if (funcionarios.isEmpty) {
        DisplayHelper.showInfo('Nenhum funcionário cadastrado.');
        return;
      }

      final data = funcionarios.map((funcionario) {
        return {
          'ID': funcionario.id,
          'Nome': funcionario.nome,
          'Email': funcionario.email,
        };
      }).toList();

      DisplayHelper.showTable(data, 'Funcionários Disponíveis para Deleção');

      final id =
          InputHelper.promptInt('Digite o ID do funcionário a ser deletado: ');

      if (!InputHelper.promptBoolean(
          'Confirma a exclusão do funcionário $id?')) {
        DisplayHelper.showInfo('Operação cancelada.');
        return;
      }

      await deleteFuncionario.execute(DeleteFuncionarioParams(id));
      DisplayHelper.showSuccess('Funcionário deletado com sucesso!');
    } catch (e) {
      DisplayHelper.showError('Erro ao deletar funcionário: $e');
    }
  }

  Future<void> _menuLocais() async {
    while (true) {
      DisplayHelper.showTitle('Gestão de Locais');
      print('1. ➕ Adicionar Local');
      print('2. 📋 Listar Locais');
      print('3. 🗑️  Deletar Local');
      print('0. ↩️  Voltar');
      print('');

      final opcao = InputHelper.prompt('Escolha uma opção: ');

      switch (opcao) {
        case '1':
          await _adicionarLocal();
          break;
        case '2':
          await _listarLocais();
          break;
        case '3':
          await _deletarLocal();
          break;
        case '0':
          return;
        default:
          DisplayHelper.showError('Opção inválida!');
      }

      if (opcao != '0') {
        DisplayHelper.waitForUser();
        DisplayHelper.clearScreen();
      }
    }
  }

  Future<void> _adicionarLocal() async {
    DisplayHelper.showSection('Novo Local');

    try {
      final empresas = await getEmpresas.execute(const NoParams());
      if (empresas.isEmpty) {
        DisplayHelper.showError(
            'Nenhuma empresa cadastrada. Cadastre uma empresa primeiro.');
        return;
      }

      final empresasData = empresas.map((empresa) {
        return {
          'ID': empresa.id,
          'Nome': empresa.nome,
        };
      }).toList();

      DisplayHelper.showTable(empresasData, 'Empresas Disponíveis');

      final nome = InputHelper.prompt('Nome do local: ');
      final referencia = InputHelper.prompt('Referência: ');
      final empresaId = InputHelper.promptInt('ID da Empresa: ');

      final nomeError = Validators.validateRequired(nome, 'Nome');
      final referenciaError =
          Validators.validateRequired(referencia, 'Referência');

      if (nomeError != null) {
        DisplayHelper.showError(nomeError);
        return;
      }
      if (referenciaError != null) {
        DisplayHelper.showError(referenciaError);
        return;
      }

      final local = Local(
        nome: nome,
        referencia: referencia,
        empresaId: empresaId,
      );

      await createLocal.execute(CreateLocalParams(local));
      DisplayHelper.showSuccess('Local adicionado com sucesso!');
    } catch (e) {
      DisplayHelper.showError('Erro ao adicionar local: $e');
    }
  }

  Future<void> _listarLocais() async {
    try {
      final locais = await getLocais.execute(const NoParams());

      final data = locais.map((local) {
        return {
          'ID': local.id,
          'Nome': local.nome,
          'Referência': local.referencia,
          'Empresa ID': local.empresaId,
          'Data Criação': Formatters.formatDateTime(local.dataCriacao),
        };
      }).toList();

      DisplayHelper.showTable(data, 'Locais Cadastrados');
    } catch (e) {
      DisplayHelper.showError('Erro ao listar locais: $e');
    }
  }

  Future<void> _deletarLocal() async {
    try {
      final locais = await getLocais.execute(const NoParams());

      if (locais.isEmpty) {
        DisplayHelper.showInfo('Nenhum local cadastrado.');
        return;
      }

      final data = locais.map((local) {
        return {
          'ID': local.id,
          'Nome': local.nome,
          'Referência': local.referencia,
        };
      }).toList();

      DisplayHelper.showTable(data, 'Locais Disponíveis para Deleção');

      final id = InputHelper.promptInt('Digite o ID do local a ser deletado: ');

      if (!InputHelper.promptBoolean('Confirma a exclusão do local $id?')) {
        DisplayHelper.showInfo('Operação cancelada.');
        return;
      }

      await deleteLocal.execute(DeleteLocalParams(id));
      DisplayHelper.showSuccess('Local deletado com sucesso!');
    } catch (e) {
      DisplayHelper.showError('Erro ao deletar local: $e');
    }
  }

  Future<void> _menuDispositivos() async {
    while (true) {
      DisplayHelper.showTitle('Gestão de Dispositivos');
      print('1. ➕ Adicionar Dispositivo');
      print('2. 📋 Listar Dispositivos');
      print('3. 🗑️  Deletar Dispositivo');
      print('0. ↩️  Voltar');
      print('');

      final opcao = InputHelper.prompt('Escolha uma opção: ');

      switch (opcao) {
        case '1':
          await _adicionarDispositivo();
          break;
        case '2':
          await _listarDispositivos();
          break;
        case '3':
          await _deletarDispositivo();
          break;
        case '0':
          return;
        default:
          DisplayHelper.showError('Opção inválida!');
      }

      if (opcao != '0') {
        DisplayHelper.waitForUser();
        DisplayHelper.clearScreen();
      }
    }
  }

  Future<void> _adicionarDispositivo() async {
    DisplayHelper.showSection('Novo Dispositivo');

    try {
      final locais = await getLocais.execute(const NoParams());
      if (locais.isEmpty) {
        DisplayHelper.showError(
            'Nenhum local cadastrado. Cadastre um local primeiro.');
        return;
      }

      final locaisData = locais.map((local) {
        return {
          'ID': local.id,
          'Nome': local.nome,
          'Referência': local.referencia,
        };
      }).toList();

      DisplayHelper.showTable(locaisData, 'Locais Disponíveis');

      final modelo = InputHelper.prompt('Modelo do dispositivo: ');
      final status = InputHelper.prompt('Status: ');
      final localId = InputHelper.promptInt('ID do Local: ');

      final modeloError = Validators.validateRequired(modelo, 'Modelo');
      final statusError = Validators.validateRequired(status, 'Status');

      if (modeloError != null) {
        DisplayHelper.showError(modeloError);
        return;
      }
      if (statusError != null) {
        DisplayHelper.showError(statusError);
        return;
      }

      final dispositivo = Dispositivo(
        modelo: modelo,
        status: status,
        localId: localId,
      );

      await createDispositivo.execute(CreateDispositivoParams(dispositivo));
      DisplayHelper.showSuccess('Dispositivo adicionado com sucesso!');
    } catch (e) {
      DisplayHelper.showError('Erro ao adicionar dispositivo: $e');
    }
  }

  Future<void> _listarDispositivos() async {
    try {
      final dispositivos = await getDispositivos.execute(const NoParams());

      final data = dispositivos.map((dispositivo) {
        return {
          'ID': dispositivo.id,
          'Modelo': dispositivo.modelo,
          'Status': dispositivo.status,
          'Local ID': dispositivo.localId,
          'Data Criação': Formatters.formatDateTime(dispositivo.dataCriacao),
        };
      }).toList();

      DisplayHelper.showTable(data, 'Dispositivos Cadastrados');
    } catch (e) {
      DisplayHelper.showError('Erro ao listar dispositivos: $e');
    }
  }

  Future<void> _deletarDispositivo() async {
    try {
      final dispositivos = await getDispositivos.execute(const NoParams());

      if (dispositivos.isEmpty) {
        DisplayHelper.showInfo('Nenhum dispositivo cadastrado.');
        return;
      }

      final data = dispositivos.map((dispositivo) {
        return {
          'ID': dispositivo.id,
          'Modelo': dispositivo.modelo,
          'Status': dispositivo.status,
        };
      }).toList();

      DisplayHelper.showTable(data, 'Dispositivos Disponíveis para Deleção');

      final id =
          InputHelper.promptInt('Digite o ID do dispositivo a ser deletado: ');

      if (!InputHelper.promptBoolean(
          'Confirma a exclusão do dispositivo $id?')) {
        DisplayHelper.showInfo('Operação cancelada.');
        return;
      }

      await deleteDispositivo.execute(DeleteDispositivoParams(id));
      DisplayHelper.showSuccess('Dispositivo deletado com sucesso!');
    } catch (e) {
      DisplayHelper.showError('Erro ao deletar dispositivo: $e');
    }
  }

  Future<void> _menuConsumoDiario() async {
    while (true) {
      DisplayHelper.showTitle('Gestão de Consumo Diário');
      print('1. 🔄 Sincronizar com Firebase');
      print('2. 📋 Listar Consumos');
      print('3. 🗑️  Deletar Consumo');
      print('0. ↩️  Voltar');
      print('');

      final opcao = InputHelper.prompt('Escolha uma opção: ');

      switch (opcao) {
        case '1':
          await _sincronizarConsumos();
          break;
        case '2':
          await _listarConsumos();
          break;
        case '3':
          await _deletarConsumo();
          break;
        case '0':
          return;
        default:
          DisplayHelper.showError('Opção inválida!');
      }

      if (opcao != '0') {
        DisplayHelper.waitForUser();
        DisplayHelper.clearScreen();
      }
    }
  }

  Future<void> _sincronizarConsumos() async {
    DisplayHelper.showProgress('Sincronizando consumos diários');

    try {
      final resultado = await syncConsumosDiarios.execute(const NoParams());
      DisplayHelper.completeProgress();
      DisplayHelper.showSuccess(resultado.toString());
    } catch (e) {
      DisplayHelper.completeProgress();
      DisplayHelper.showError('Erro na sincronização: $e');
    }
  }

  Future<void> _listarConsumos() async {
    try {
      final consumos = await getConsumosDiarios.execute(const NoParams());

      final data = consumos.map((consumo) {
        return {
          'ID': consumo.id,
          'Dispositivo ID': consumo.dispositivoId,
          'Consumo': Formatters.formatKWh(consumo.consumoKwh),
          'Data/Hora': Formatters.formatDateTime(consumo.timeStamp),
          'Firebase Key': consumo.firebaseKey,
        };
      }).toList();

      DisplayHelper.showTable(data, 'Consumos Diários');
    } catch (e) {
      DisplayHelper.showError('Erro ao listar consumos: $e');
    }
  }

  Future<void> _deletarConsumo() async {
    try {
      final consumos = await getConsumosDiarios.execute(const NoParams());

      if (consumos.isEmpty) {
        DisplayHelper.showInfo('Nenhum consumo diário cadastrado.');
        return;
      }

      final data = consumos.map((consumo) {
        return {
          'ID': consumo.id,
          'Dispositivo ID': consumo.dispositivoId,
          'Consumo': Formatters.formatKWh(consumo.consumoKwh),
          'Data/Hora': Formatters.formatDateTime(consumo.timeStamp),
        };
      }).toList();

      DisplayHelper.showTable(data, 'Consumos Disponíveis para Deleção');

      final id =
          InputHelper.promptInt('Digite o ID do consumo a ser deletado: ');

      if (!InputHelper.promptBoolean('Confirma a exclusão do consumo $id?')) {
        DisplayHelper.showInfo('Operação cancelada.');
        return;
      }

      await deleteConsumoDiario.execute(DeleteConsumoDiarioParams(id));
      DisplayHelper.showSuccess('Consumo deletado com sucesso!');
    } catch (e) {
      DisplayHelper.showError('Erro ao deletar consumo: $e');
    }
  }
}
