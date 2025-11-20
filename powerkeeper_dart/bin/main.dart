// main.dart
import 'dart:io';
import 'package:tabular/tabular.dart';
import 'package:firebase_listener/database_service.dart';
import 'package:firebase_listener/firebase_service.dart';
import 'package:firebase_listener/models.dart';

// Instâncias únicas dos serviços
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
      print("Entrada inválida. Digite um número.");
    }
  }
}

Future<void> sincronizarTudo() async {
  print("\n🔄 Sincronizando TUDO antes de abrir o menu...");

  // Consumos diários
  await syncConsumosDiariosOnly();

  // Aqui você pode adicionar outras sincronizações
  // await syncOutroTipoDeDados();

  print("✅ Sincronização completa!\n");
}

// ---------------------- SINCRONIZAÇÃO ----------------------
Future<void> menuSincronizacao() async {
  bool running = true;

  while (running) {
    print("\n--- 🔄 Menu de Sincronização ---");
    print("1. Sincronizar Consumos Diários");
    print("2. Sincronizar Tudo");
    print("0. Voltar");

    final op = prompt("Escolha: ");

    switch (op) {
      case '1':
        await syncConsumosDiariosOnly();
        break;
      case '2':
        print("🔧 Função 'sincronizar tudo' ainda não implementada.");
        break;
      case '0':
        running = false;
        break;
      default:
        print("Opção inválida.");
    }
  }
}

Future<void> syncConsumosDiariosOnly() async {
  print("\n🔄 Sincronizando APENAS Consumos Diários...");

  try {
    if (!firebase.conectado) {
      print("Conectando ao Firebase...");
      await firebase.connect();
    }
  } catch (e) {
    print("❌ Erro ao conectar ao Firebase.");
    return;
  }

  await _syncConsumosDiarios();
}

Future<void> _syncConsumosDiarios() async {
  // Mensagem inicial simples
  print("🔄 Sincronizando Consumos Diários...");

  final List<ConsumoDiario> consumos =
      await firebase.getConsumosDiariosNaoSincronizados();

  if (consumos.isEmpty) {
    print("Nenhum consumo novo encontrado.\n");
    return;
  }

  print("Total de registros a sincronizar: ${consumos.length}\n");

  int sucesso = 0;
  int erros = 0;
  int avisos = 0;

  for (final consumo in consumos) {
    if (consumo.firebaseKey.isEmpty) {
      // Aviso limpo
      print("⚠ Registro sem chave, ignorado.");
      erros++;
      continue;
    }

    final resultado = await db.insertConsumoDiario(consumo);

    if (resultado.contains("sucesso")) {
      await firebase.marcarConsumoComoSincronizado(consumo.firebaseKey);
      sucesso++;
    } else if (resultado.contains("Duplicate entry")) {
      // Mensagem amigável para duplicatas
      print("⚠ Registro já existe: Dispositivo ${consumo.dispositivoId} - ${consumo.timeStamp}");
      avisos++;
    } else if (resultado.startsWith("aviso:")) {
      print("⚠ Aviso: $resultado");
      avisos++;
    } else {
      erros++;
      print("❌ Falha ao inserir: Dispositivo ${consumo.dispositivoId} - ${consumo.timeStamp}");
    }
  }

  // Resumo final limpo
  print("\n📊 Resumo da sincronização:");
  print("✔ Inseridos com sucesso: $sucesso");
  print("⚠ Ignorados/avisos: $avisos");
  print("❌ Falhas: $erros\n");
}


// ---------------------- LISTAGEM (CLI TABLE) ----------------------
Future<void> listarTabelaCLI(
    List<Map<String, dynamic>> data, String titulo) async {
  print("\n$titulo");

  if (data.isEmpty) {
    print("Nenhum registro encontrado.");
    return;
  }

  final headers = data.first.keys.toList();
  // Tratamento de valores nulos
  final rows = data
      .map((e) => e.values.map((v) => v == null ? '' : v.toString()).toList())
      .toList();

  final tabela = tabular([headers, ...rows]);
  print(tabela);
}

// ---------------------- MENUS ----------------------
Future<void> menuEmpresas() async {
  bool running = true;

  while (running) {
    print("\n--- 🏢 Empresas ---");
    print("1. Adicionar");
    print("2. Listar");
    print("3. Deletar");
    print("0. Voltar");

    final op = prompt("Escolha: ");

    switch (op) {
      case '1':
        final nome = prompt("Nome: ");
        final cnpj = prompt("CNPJ: ");
        await db.addEmpresa(nome, cnpj);
        print("✅ Empresa adicionada.");
        // Só lista automaticamente após adicionar
        final empresasAtualizadas = await db.getEmpresas();
        if (empresasAtualizadas.isNotEmpty) {
          await listarTabelaCLI(empresasAtualizadas, "📋 Empresas");
        }
        break;

      case '2':
        // Chamada manual para listar
        final empresas = await db.getEmpresas();
        if (empresas.isEmpty) {
          print("Nenhuma empresa cadastrada.");
        } else {
          await listarTabelaCLI(empresas, "📋 Empresas");
        }
        break;

      case '3':
        final id = promptInt("ID: ");
        await db.deleteEmpresa(id);
        print("✅ Empresa deletada.");
        // Opcional: listar apenas se existir alguma
        final empresas = await db.getEmpresas();
        if (empresas.isNotEmpty) {
          await listarTabelaCLI(empresas, "📋 Empresas");
        }
        break;

      case '0':
        running = false;
        break;

      default:
        print("Opção inválida.");
    }
  }
}

Future<void> menuFuncionarios() async {
  bool running = true;

  while (running) {
    print("\n--- 👷 Funcionários ---");
    print("1. Adicionar");
    print("2. Listar");
    print("3. Deletar");
    print("0. Voltar");

    final op = prompt("Escolha: ");

    switch (op) {
      case '1':
        await adicionarFuncionario();
        break;

      case '2':
        await listarTabelaCLI(await db.getFuncionarios(), "📋 Funcionários");
        break;

      case '3':
        final id = promptInt("ID: ");
        await db.deleteFuncionario(id);
        print("Funcionário deletado.");
        await listarTabelaCLI(await db.getFuncionarios(), "📋 Funcionários");
        break;

      case '0':
        running = false;
        break;

      default:
        print("Opção inválida.");
    }
  }
}

Future<void> adicionarFuncionario() async {
  final empresas = await db.getEmpresas();

  if (empresas.isEmpty) {
    print("Nenhuma empresa encontrada.");
    return;
  }

  await listarTabelaCLI(empresas, "📋 Empresas disponíveis:");

  final nome = prompt("Nome: ");
  final email = prompt("Email: ");
  final senha = prompt("Senha: ");
  final idEmpresa = promptInt("ID Empresa: ");

  print(await db.addFuncionario(nome, email, senha, idEmpresa));
}

Future<void> menuLocais() async {
  bool running = true;

  while (running) {
    print("\n--- 📍 Locais ---");
    print("1. Adicionar");
    print("2. Listar");
    print("3. Deletar");
    print("0. Voltar");

    final op = prompt("Escolha: ");

    switch (op) {
      case '1':
        await adicionarLocal();
        break;

      case '2':
        await listarTabelaCLI(await db.getLocais(), "📋 Locais");
        break;

      case '3':
        final id = promptInt("ID: ");
        await db.deleteLocal(id);
        print("Local deletado.");
        await listarTabelaCLI(await db.getLocais(), "📋 Locais");
        break;

      case '0':
        running = false;
        break;

      default:
        print("Opção inválida.");
    }
  }
}

Future<void> adicionarLocal() async {
  final empresas = await db.getEmpresas();

  if (empresas.isEmpty) {
    print("Nenhuma empresa cadastrada.");
    return;
  }

  await listarTabelaCLI(empresas, "📋 Empresas disponíveis:");

  final nome = prompt("Nome do local: ");
  final ref = prompt("Referência: ");
  final idEmp = promptInt("ID Empresa: ");

  print(await db.addLocal(nome, ref, idEmp));
}

Future<void> menuDispositivos() async {
  bool running = true;

  while (running) {
    print("\n--- 📱 Dispositivos ---");
    print("1. Adicionar");
    print("2. Listar");
    print("3. Deletar");
    print("0. Voltar");

    final op = prompt("Escolha: ");

    switch (op) {
      case '1':
        await adicionarDispositivo();
        break;

      case '2':
        await listarTabelaCLI(await db.getDispositivos(), "📋 Dispositivos");
        break;

      case '3':
        final id = promptInt("ID: ");
        await db.deleteDispositivo(id);
        print("Dispositivo deletado.");
        await listarTabelaCLI(await db.getDispositivos(), "📋 Dispositivos");
        break;

      case '0':
        running = false;
        break;

      default:
        print("Opção inválida.");
    }
  }
}

Future<void> adicionarDispositivo() async {
  final locais = await db.getLocais();

  if (locais.isEmpty) {
    print("Nenhum local registrado.");
    return;
  }

  await listarTabelaCLI(locais, "📋 Locais disponíveis:");

  final modelo = prompt("Modelo: ");
  final status = prompt("Status: ");
  final idLocal = promptInt("ID Local: ");

  print(await db.addDispositivo(modelo, status, idLocal));
}

// ---------------------- MENU PRINCIPAL ----------------------
Future<void> main() async {
  try {
    await db.connect();
  } catch (e) {
    print("❌ ERRO ao conectar ao MySQL.");
    print(e);
    return;
  }

  // 🔄 Sincronização completa automática
  await sincronizarTudo();

  bool running = true;

  while (running) {
    print("\n--- ⚡ PowerKeeper CLI ---");
    print("1. Empresas");
    print("2. Funcionários");
    print("3. Locais");
    print("4. Dispositivos");
    print("5. Sincronização");
    print("0. Sair");

    final op = prompt("Escolha: ");

    switch (op) {
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
        print("Opção inválida.");
    }
  }

  await db.close();
  print("Encerrado.");
}
