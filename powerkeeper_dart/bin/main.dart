// bin/main.dart

import 'dart:io';

// IMPORTAÇÃO CORRETA DO CLI_TABLE
import 'package:tabular/tabular.dart';

// IMPORTAÇÕES DO PROJETO
import 'package:firebase_listener/database_service.dart';
import 'package:firebase_listener/firebase_service.dart';
import 'package:firebase_listener/models.dart';

// Instâncias únicas dos nossos serviços
final db = DatabaseService();
final firebase = FirebaseService();

// ---------------------- INPUT AUXILIAR ----------------------

String prompt(String message) {
  stdout.write(message);
  return stdin.readLineSync() ?? '';
}

int promptInt(String message) {
  while (true) {
    try {
      final input = prompt(message);
      return int.parse(input);
    } catch (e) {
      print("Entrada inválida. Por favor, digite um número.");
    }
  }
}

// ---------------------- SINCRONIZAÇÃO ----------------------

Future<void> syncFirebase() async {
  print("\n🔄 Iniciando sincronização do Firebase para MySQL...");

  try {
    if (!firebase.conectado) {
      print("Conectando ao Firebase...");
      await firebase.connect();
    }

    print("Buscando leituras não sincronizadas no Firebase RTDB...");
    final List<Leitura> leituras = await firebase.getNaoSincronizadas();

    if (leituras.isEmpty) {
      print("✅ Nenhuma leitura nova para sincronizar.");
      return;
    }

    print("📊 Encontradas ${leituras.length} leitura(s) para sincronizar.");

    int sucesso = 0;
    int erros = 0;

    for (final leitura in leituras) {
      if (leitura.firebaseDocId == null) {
        print("⚠️  Leitura sem ID do Firebase, pulando...");
        erros++;
        continue;
      }

      final resultado = await db.insertLeitura(leitura);

      if (resultado.contains("sucesso")) {
        await firebase.marcarComoSincronizada(leitura.firebaseDocId!);
        sucesso++;
        print("✅ Leitura ${leitura.firebaseDocId} sincronizada: $resultado");
      } else if (resultado.contains("aviso: Leitura já existe")) {
        await firebase.marcarComoSincronizada(leitura.firebaseDocId!);
        print(
            "⚠️  Leitura ${leitura.firebaseDocId} já existia. Marcada como 'lida'.");
      } else {
        erros++;
        print(
            "❌ Erro ao sincronizar leitura ${leitura.firebaseDocId}: $resultado");
      }
    }

    print("\n📈 Resumo da sincronização:");
    print("   ✅ Sincronizadas com sucesso: $sucesso");
    print("   ❌ Erros: $erros");
    print("   📦 Total processado: ${leituras.length}");
  } catch (e) {
    print("❌ ERRO FATAL durante a sincronização: $e");
  }
}

// ---------------------- TABELAS (CLI TABLE) ----------------------

Future<void> listarTudoMySQL() async {
  print("\n--- 📋 Resumo Geral do Banco de Dados MySQL ---");

  void printTable(List<Map<String, dynamic>> data, String title) {
    print(title);

    if (data.isEmpty) {
      print("Nenhum dado cadastrado.");
      return;
    }

    final headers = data.first.keys.toList();
    final rows = data.map((map) => map.values.toList()).toList();

    // Adiciona os headers como primeira linha
    final tableData = [headers, ...rows];

    // Usando a API correta do pacote tabular
    final table = tabular(tableData);

    print(table);
  }

  printTable(await db.getEmpresasForTable(), "\n--- 🏢 Empresas ---");
  printTable(await db.getFuncionariosForTable(), "\n--- 👷 Funcionários ---");
  printTable(await db.getLocaisForTable(), "\n--- 📍 Locais ---");
  printTable(await db.getDispositivosForTable(), "\n--- 📱 Dispositivos ---");
  printTable(
      await db.getLeiturasForTable(10), "\n--- ⚡️ Últimas 10 Leituras ---");

  print("\n--- Fim do Resumo ---");
  print("Pressione Enter para continuar...");
  stdin.readLineSync();
}

Future<void> checkConexoes() async {
  print("\n🔍 Verificando conexões...");

  try {
    await db.getEmpresas();
    print("✅ MySQL: OK (Conexão estabelecida)");
  } catch (e) {
    print("❌ MySQL: ERRO - $e");
  }

  try {
    if (!firebase.conectado) {
      print("⚠️  Firebase: Não conectado. Conectando...");
      await firebase.connect();
    }
    print("✅ Firebase: OK (Conexão estabelecida)");
  } catch (e) {
    print("❌ Firebase: ERRO - $e");
  }

  print("Verificação de conexões concluída.");
}

// ---------------------- MENU PRINCIPAL ----------------------

Future<void> main() async {
  try {
    await db.connect();
  } catch (e) {
    print("ERRO FATAL: Não foi possível conectar ao banco de dados.");
    print(e);
    return;
  }

  bool running = true;
  while (running) {
    print("\n--- ⚡️ Sistema de Gestão PowerKeeper (MySQL) ---");
    print("1. Gerenciar Empresas");
    print("2. Gerenciar Funcionários");
    print("3. Gerenciar Locais");
    print("4. Gerenciar Dispositivos");
    print("5. Sincronizar / Listar");
    print("0. Sair");

    final choice = prompt("Escolha uma opção: ");

    switch (choice) {
      case '1':
        await menuEmpresas();
        break;
      case '2':
        await menuFuncionarios();
        break;
      case '3':
        await menuLocais();
        break;
      case '4':
        await menuDispositivos();
        break;
      case '5':
        await menuSincronizacao();
        break;
      case '0':
        running = false;
        break;
      default:
        print("Opção inválida!");
    }
  }

  await db.close();
  firebase.close();
  print("Saindo...");
}

// ---------------------- MENUS AUXILIARES ----------------------

Future<void> menuEmpresas() async {
  bool running = true;
  while (running) {
    print("\n--- 🏢 Gerenciar Empresas ---");
    print("1. Adicionar Empresa");
    print("2. Listar Empresas");
    print("3. Deletar Empresa");
    print("0. Voltar ao Menu Principal");

    final choice = prompt("Escolha uma opção: ");
    switch (choice) {
      case '1':
        final nome = prompt("Nome da empresa: ");
        final cnpj = prompt("CNPJ da empresa: ");
        await db.addEmpresa(nome, cnpj);
        print("Empresa '$nome' adicionada com sucesso!");
        break;
      case '2':
        print("\n--- Lista de Empresas ---");
        final empresas = await db.getEmpresas();
        empresas.isEmpty
            ? print("Nenhuma empresa cadastrada.")
            : empresas.forEach(print);
        break;
      case '3':
        final id = promptInt("ID da empresa a deletar: ");
        await db.deleteEmpresa(id);
        print("Empresa com ID $id (e dados relacionados) deletada.");
        break;
      case '0':
        running = false;
        break;
      default:
        print("Opção inválida!");
    }
  }
}

Future<void> menuFuncionarios() async {
  bool running = true;
  while (running) {
    print("\n--- 👷 Gerenciar Funcionários ---");
    print("1. Adicionar Funcionário");
    print("2. Listar Funcionários");
    print("3. Deletar Funcionário");
    print("0. Voltar ao Menu Principal");

    final choice = prompt("Escolha uma opção: ");
    switch (choice) {
      case '1':
        await _adicionarFuncionario();
        break;
      case '2':
        print("\n--- Lista de Funcionários ---");
        final funcionarios = await db.getFuncionarios();
        funcionarios.isEmpty
            ? print("Nenhum funcionário cadastrado.")
            : funcionarios.forEach(print);
        break;
      case '3':
        final id = promptInt("ID do funcionário a deletar: ");
        await db.deleteFuncionario(id);
        print("Funcionário com ID $id deletado.");
        break;
      case '0':
        running = false;
        break;
      default:
        print("Opção inválida!");
    }
  }
}

Future<void> _adicionarFuncionario() async {
  print("\n--- Empresas Disponíveis ---");
  final empresas = await db.getEmpresas();
  if (empresas.isEmpty) {
    print("Nenhuma empresa cadastrada. Adicione uma empresa primeiro.");
    return;
  }
  empresas.forEach(print);

  final nome = prompt("Nome do funcionário: ");
  final email = prompt("Email: ");
  final senha = prompt("Senha: ");
  final idEmpresa = promptInt("ID da Empresa do funcionário: ");

  final resultado = await db.addFuncionario(nome, email, senha, idEmpresa);
  print(resultado);
}

Future<void> menuLocais() async {
  bool running = true;
  while (running) {
    print("\n--- 📍 Gerenciar Locais ---");
    print("1. Adicionar Local");
    print("2. Listar Locais");
    print("3. Deletar Local");
    print("0. Voltar ao Menu Principal");

    final choice = prompt("Escolha uma opção: ");
    switch (choice) {
      case '1':
        await _adicionarLocal();
        break;
      case '2':
        final locais = await db.getLocais();
        locais.isEmpty
            ? print("Nenhum local cadastrado.")
            : locais.forEach(print);
        break;
      case '3':
        final id = promptInt("ID do local a deletar: ");
        await db.deleteLocal(id);
        print("Local (e dispositivos relacionados) com ID $id deletado.");
        break;
      case '0':
        running = false;
        break;
      default:
        print("Opção inválida!");
    }
  }
}

Future<void> _adicionarLocal() async {
  final empresas = await db.getEmpresas();
  if (empresas.isEmpty) {
    print("Nenhuma empresa cadastrada. Adicione uma empresa primeiro.");
    return;
  }
  empresas.forEach(print);

  final nome = prompt("Nome do local: ");
  final referencia = prompt("Referência: ");
  final idEmpresa = promptInt("ID da Empresa do local: ");

  final resultado = await db.addLocal(nome, referencia, idEmpresa);
  print(resultado);
}

Future<void> menuDispositivos() async {
  bool running = true;
  while (running) {
    print("\n--- 📱 Gerenciar Dispositivos ---");
    print("1. Adicionar Dispositivo");
    print("2. Listar Dispositivos");
    print("3. Deletar Dispositivo");
    print("0. Voltar ao Menu Principal");

    final choice = prompt("Escolha uma opção: ");
    switch (choice) {
      case '1':
        await _adicionarDispositivo();
        break;
      case '2':
        final dispositivos = await db.getDispositivos();
        dispositivos.isEmpty
            ? print("Nenhum dispositivo cadastrado.")
            : dispositivos.forEach(print);
        break;
      case '3':
        final id = promptInt("ID do dispositivo a deletar: ");
        await db.deleteDispositivo(id);
        print("Dispositivo com ID $id deletado.");
        break;
      case '0':
        running = false;
        break;
      default:
        print("Opção inválida!");
    }
  }
}

Future<void> _adicionarDispositivo() async {
  final locais = await db.getLocais();
  if (locais.isEmpty) {
    print("Nenhum local cadastrado. Adicione um local primeiro.");
    return;
  }
  locais.forEach(print);

  final modelo = prompt("Modelo do dispositivo: ");
  final status = prompt("Status inicial: ");
  final idLocal = promptInt("ID do Local do dispositivo: ");

  final resultado = await db.addDispositivo(modelo, status, idLocal);
  print(resultado);
}

// MENU DE SINCRONIZAÇÃO
Future<void> menuSincronizacao() async {
  bool running = true;
  while (running) {
    print("\n--- 🔄 Sincronizar / Listar ---");
    print("1. Sincronizar Firebase → MySQL");
    print("2. Listar Resumo do MySQL (Tabela)");
    print("3. Verificar Conexões");
    print("0. Voltar ao Menu Principal");

    final choice = prompt("Escolha uma opção: ");
    switch (choice) {
      case '1':
        await syncFirebase();
        break;
      case '2':
        await listarTudoMySQL();
        break;
      case '3':
        await checkConexoes();
        break;
      case '0':
        running = false;
        break;
      default:
        print("Opção inválida!");
    }
  }
}
