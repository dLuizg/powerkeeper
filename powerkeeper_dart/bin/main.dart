// bin/main.dart
// (Seu antigo 'gestao.dart')

import 'dart:io';
// Ajuste 'powerkeeper_sync' para o nome do seu projeto no pubspec.yaml
import '../lib/database_service.dart';
import '../lib/firebase_service.dart';

// Instâncias únicas dos nossos serviços
final db = DatabaseService();
final firebase = FirebaseService();

// --- Funções Auxiliares de Input ---

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

// --- Funções de Sincronização ---

Future<void> syncFirebase() async {
  print("\n🔄 Iniciando sincronização do Firebase para MySQL...");
  
  try {
    // 1. Conectar ao Firebase se ainda não estiver conectado
    if (!firebase.conectado) {
      print("Conectando ao Firebase...");
      await firebase.connect();
    }

    // 2. Buscar leituras não sincronizadas
    print("Buscando leituras não sincronizadas no Firebase RTDB...");
    final leituras = await firebase.getNaoSincronizadas();
    
    if (leituras.isEmpty) {
      print("✅ Nenhuma leitura nova para sincronizar.");
      return;
    }

    print("📊 Encontradas ${leituras.length} leitura(s) para sincronizar.");

    // 3. Inserir cada leitura no MySQL
    int sucesso = 0;
    int erros = 0;

    for (final leitura in leituras) {
      if (leitura.firebaseDocId == null) {
        print("⚠️  Leitura sem ID do Firebase, pulando...");
        erros++;
        continue;
      }

      // Agora 'insertLeitura' usa os campos corretos do 'models.dart'
      final resultado = await db.insertLeitura(leitura);
      
      if (resultado.contains("sucesso")) {
        // 4. Marcar como sincronizada no Firestore
        await firebase.marcarComoSincronizada(leitura.firebaseDocId!);
        sucesso++;
        print("✅ Leitura ${leitura.firebaseDocId} sincronizada: $resultado");
      } else if (resultado.contains("aviso: Leitura já existe")) {
        // Se já existe no MySQL, marca como 'lida' no Firebase
        // para não buscá-la novamente.
        await firebase.marcarComoSincronizada(leitura.firebaseDocId!);
        print("⚠️  Leitura ${leitura.firebaseDocId} já existia. Marcada como 'lida'.");
      }
      else {
        erros++;
        print("❌ Erro ao sincronizar leitura ${leitura.firebaseDocId}: $resultado");
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

void syncMySQL() {
  print("\nIniciando sincronização com MySQL (Leituras)...");
  print("Buscando leituras do banco principal...");
  sleep(Duration(seconds: 1));
  print("... Sincronização de LEITURAS concluída.");
}

Future<void> checkConexoes() async {
  print("\n🔍 Verificando conexões...");
  
  // Verificar MySQL
  try {
    // Tenta reconectar se não estiver conectado
    if (!db.conectado) await db.connect();
    await db.getEmpresas(); // Teste simples
    print("✅ MySQL: OK (Conexão estabelecida)");
  } catch (e) {
    print("❌ MySQL: ERRO - $e");
  }

  // Verificar Firebase
  try {
    if (!firebase.conectado) {
      print("⚠️  Firebase: Não conectado. Conectando...");
      await firebase.connect();
    }
    print("✅ Firebase: OK (Conectado)");
  } catch (e) {
    print("❌ Firebase: ERRO - $e");
  }
  
  print("Verificação de conexões concluída.");
}

// --- Funções de Menu (Agora são 'async') ---

Future<void> main() async {
  try {
    // 1. Conectar ao banco ANTES de mostrar o menu
    await db.connect();
  } catch (e) {
    print("ERRO FATAL: Não foi possível conectar ao banco de dados.");
    print(e);
    return; // Encerra o app se não puder conectar
  }

  bool running = true;
  while (running) {
    print("\n--- ⚡️ Sistema de Gestão PowerKeeper (MySQL) ---");
    print("1. Gerenciar Empresas");
    print("2. Gerenciar Funcionários");
    print("3. Gerenciar Locais");
    print("4. Gerenciar Dispositivos");
    print("5. Sincronizar Leituras");
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
        await menuSincronizacao(); // Agora é async
        break;
      case '0':
        running = false;
        break;
      default:
        print("Opção inválida!");
    }
  }

  // 2. Fechar as conexões ao sair
  await db.close();
  firebase.close(); // Adicionado para fechar o cliente http
  print("Saindo...");
}

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
        if (empresas.isEmpty) {
          print("Nenhuma empresa cadastrada.");
        } else {
          empresas.forEach(print);
        }
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
        await _adicionarFuncionario(); // 'await' aqui
        break;
      case '2':
        print("\n--- Lista de Funcionários ---");
        final funcionarios = await db.getFuncionarios();
        if (funcionarios.isEmpty) {
          print("Nenhum funcionário cadastrado.");
        } else {
          funcionarios.forEach(print);
        }
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
  print("-----------------------------");

  final nome = prompt("Nome do funcionário: ");
  final email = prompt("Email: ");
  final senha = prompt("Senha: "); // A tabela pedia 'senhaLogin'
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
        await _adicionarLocal(); // 'await' aqui
        break;
      case '2':
        print("\n--- Lista de Locais ---");
        final locais = await db.getLocais();
        if (locais.isEmpty) {
          print("Nenhum local cadastrado.");
        } else {
          locais.forEach(print);
        }
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
  print("\n--- Empresas Disponíveis ---");
  final empresas = await db.getEmpresas();
  if (empresas.isEmpty) {
    print("Nenhuma empresa cadastrada. Adicione uma empresa primeiro.");
    return;
  }
  empresas.forEach(print);
  print("-----------------------------");

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
        await _adicionarDispositivo(); // 'await' aqui
        break;
      case '2':
        print("\n--- Lista de Dispositivos ---");
        final dispositivos = await db.getDispositivos();
        if (dispositivos.isEmpty) {
          print("Nenhum dispositivo cadastrado.");
        } else {
          dispositivos.forEach(print);
        }
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
  print("\n--- Locais Disponíveis ---");
  final locais = await db.getLocais();
  if (locais.isEmpty) {
    print("Nenhum local cadastrado. Adicione um local primeiro.");
    return;
  }
  locais.forEach(print);
  print("-----------------------------");

  final modelo = prompt("Modelo do dispositivo: ");
  final status = prompt("Status inicial: ");
  final idLocal = promptInt("ID do Local do dispositivo: ");

  final resultado = await db.addDispositivo(modelo, status, idLocal);
  print(resultado);
}

// Menu de Sincronização
Future<void> menuSincronizacao() async {
  bool running = true;
  while (running) {
    print("\n--- 🔄 Sincronizar Leituras ---");
    print("1. Sincronizar Firebase → MySQL");
    print("2. Sincronizar MySQL (Leituras)");
    print("3. Verificar Conexões");
    print("0. Voltar ao Menu Principal");

    final choice = prompt("Escolha uma opção: ");
    switch (choice) {
      case '1':
        await syncFirebase();
        break;
      case '2':
        syncMySQL();
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