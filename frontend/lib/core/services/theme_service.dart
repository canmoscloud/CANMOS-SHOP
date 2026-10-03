import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferência de tema do operador, persistida entre sessões.
///
/// Antes o valor vivia só em memória: reabrir o app voltava para o tema claro,
/// o que incomoda em balcão com pouca luz.
class ThemeService extends ChangeNotifier {
  static const _chave = 'tema_escuro';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  /// Lê a preferência salva. Chamada antes do `runApp` para não exibir um
  /// flash de tema claro antes de aplicar o escuro.
  Future<void> carregar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _aplicar(prefs.getBool(_chave) ?? false);
    } catch (_) {
      // Falha de armazenamento não deve impedir o app de abrir: segue no
      // tema claro.
      _aplicar(false);
    }
  }

  Future<void> toggle() => setDark(!isDark);

  Future<void> setDark(bool value) async {
    _aplicar(value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chave, value);
    } catch (_) {
      // O tema já trocou na tela; não conseguir persistir é degradação
      // aceitável e não vale desfazer a escolha do operador.
    }
  }

  void _aplicar(bool escuro) {
    _themeMode = escuro ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
