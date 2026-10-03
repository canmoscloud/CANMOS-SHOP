import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:canmos_shop/core/services/theme_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sem preferencia salva, comeca no tema claro', () async {
    final service = ThemeService();
    await service.carregar();

    expect(service.themeMode, ThemeMode.light);
    expect(service.isDark, isFalse);
  });

  test('carrega o tema escuro salvo em sessao anterior', () async {
    SharedPreferences.setMockInitialValues({'tema_escuro': true});

    final service = ThemeService();
    await service.carregar();

    expect(service.themeMode, ThemeMode.dark);
    expect(service.isDark, isTrue);
  });

  test('setDark persiste a escolha', () async {
    final service = ThemeService();
    await service.carregar();
    await service.setDark(true);

    // Uma instancia nova simula o app reaberto: antes o valor vivia so em
    // memoria e voltava para claro.
    final novaSessao = ThemeService();
    await novaSessao.carregar();

    expect(novaSessao.isDark, isTrue);
  });

  test('toggle alterna e persiste', () async {
    final service = ThemeService();
    await service.carregar();

    await service.toggle();
    expect(service.isDark, isTrue);

    await service.toggle();
    expect(service.isDark, isFalse);

    final novaSessao = ThemeService();
    await novaSessao.carregar();
    expect(novaSessao.isDark, isFalse);
  });

  test('notifica os listeners ao trocar de tema', () async {
    final service = ThemeService();
    await service.carregar();

    var avisos = 0;
    service.addListener(() => avisos++);

    await service.setDark(true);
    expect(avisos, 1);

    await service.setDark(false);
    expect(avisos, 2);
  });
}
