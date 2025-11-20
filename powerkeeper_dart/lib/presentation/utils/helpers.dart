import 'dart:io';
import 'package:tabular/tabular.dart';

// Classe para entrada de dados do usuário
class InputHelper {
  static String prompt(String message) {
    stdout.write(message);
    return stdin.readLineSync()?.trim() ?? '';
  }

  static int promptInt(String message) {
    while (true) {
      try {
        final input = prompt(message);
        return int.parse(input);
      } catch (e) {
        print('❌ Entrada inválida. Digite um número inteiro.');
      }
    }
  }

  static double promptDouble(String message) {
    while (true) {
      try {
        final input = prompt(message);
        return double.parse(input);
      } catch (e) {
        print('❌ Entrada inválida. Digite um número decimal.');
      }
    }
  }

  static DateTime promptDateTime(String message) {
    while (true) {
      try {
        final input = prompt('$message (AAAA-MM-DD HH:MM:SS): ');
        return DateTime.parse(input);
      } catch (e) {
        print('❌ Formato inválido. Use AAAA-MM-DD HH:MM:SS');
      }
    }
  }

  static bool promptBoolean(String message) {
    final input = prompt('$message (s/N): ').toLowerCase();
    return input == 's' || input == 'sim' || input == 'y' || input == 'yes';
  }
}

// Classe para exibição de dados
class DisplayHelper {
  static void showTitle(String title) {
    print('\n' + '=' * 60);
    print('📊 $title');
    print('=' * 60);
  }

  static void showSection(String section) {
    print('\n🔹 $section');
    print('-' * 40);
  }

  static void showSuccess(String message) {
    print('✅ $message');
  }

  static void showError(String message) {
    print('❌ $message');
  }

  static void showWarning(String message) {
    print('⚠️ $message');
  }

  static void showInfo(String message) {
    print('ℹ️ $message');
  }

  static void showTable(List<Map<String, dynamic>> data, String title) {
    if (data.isEmpty) {
      showInfo('Nenhum registro encontrado.');
      return;
    }

    showTitle(title);

    final headers = data.first.keys.toList();
    final rows = data
        .map((e) => e.values.map((v) => v?.toString() ?? '').toList())
        .toList();

    final tabela = tabular([headers, ...rows]);
    print(tabela);
  }

  static void showEntityDetails<T>(T entity, String entityName) {
    showTitle('Detalhes do $entityName');
    print(entity.toString());
  }

  static void waitForUser() {
    print('\n⏎ Pressione Enter para continuar...');
    stdin.readLineSync();
  }

  static void clearScreen() {
    print('\x1B[2J\x1B[0;0H');
  }

  static void showProgress(String message) {
    stdout.write('🔄 $message...');
  }

  static void completeProgress() {
    print(' ✅');
  }
}

// Validações
class Validators {
  static bool isValidEmail(String email) {
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidCNPJ(String cnpj) {
    final cleaned = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length == 14;
  }

  static bool isValidName(String name) {
    return name.length >= 2 && name.length <= 100;
  }

  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName é obrigatório';
    }
    return null;
  }

  static String? validateEmail(String? email) {
    final requiredError = validateRequired(email, 'Email');
    if (requiredError != null) return requiredError;

    if (!isValidEmail(email!)) {
      return 'Email inválido';
    }
    return null;
  }

  static String? validateCNPJ(String? cnpj) {
    final requiredError = validateRequired(cnpj, 'CNPJ');
    if (requiredError != null) return requiredError;

    if (!isValidCNPJ(cnpj!)) {
      return 'CNPJ inválido';
    }
    return null;
  }
}

// Formatadores
class Formatters {
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2)}';
  }

  static String formatKWh(double kwh) {
    return '${kwh.toStringAsFixed(2)} kWh';
  }

  static String formatCNPJ(String cnpj) {
    final cleaned = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 14) return cnpj;

    return '${cleaned.substring(0, 2)}.${cleaned.substring(2, 5)}.${cleaned.substring(5, 8)}/${cleaned.substring(8, 12)}-${cleaned.substring(12)}';
  }
}
