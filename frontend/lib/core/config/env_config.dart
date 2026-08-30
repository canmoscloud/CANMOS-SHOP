import 'package:flutter/foundation.dart';

class EnvConfig {
  static final EnvConfig _instance = EnvConfig._();
  factory EnvConfig() => _instance;
  EnvConfig._();

  static Future<void> load() async {
    assert(() {
      debugPrint('[EnvConfig] Carregando configurações...');
      debugPrint('[EnvConfig] Supabase URL: ${_instance.supabaseUrl}');
      debugPrint('[EnvConfig] Supabase Anon Key: ${_instance.supabaseAnonKey.isNotEmpty ? "Configurada" : "NÃO CONFIGURADA"}');
      debugPrint('[EnvConfig] Stripe Key: ${_instance.stripePublishableKey.isNotEmpty ? "Configurada" : "NÃO CONFIGURADA"}');
      return true;
    }());
  }

  String get supabaseUrl => const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  String get supabaseAnonKey => const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  String get stripePublishableKey => const String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get isStripeConfigured => stripePublishableKey.isNotEmpty;

  List<String> get missingConfigurations {
    final missing = <String>[];
    if (supabaseUrl.isEmpty) missing.add('SUPABASE_URL');
    if (supabaseAnonKey.isEmpty) missing.add('SUPABASE_ANON_KEY');
    if (stripePublishableKey.isEmpty) missing.add('STRIPE_PUBLISHABLE_KEY');
    return missing;
  }

  void validateOrFail() {
    final missing = missingConfigurations;
    if (missing.isNotEmpty) {
      throw Exception(
        'Configurações faltando: ${missing.join(", ")}. '
        'Configure via --dart-define ou arquivo .env',
      );
    }
  }
}
