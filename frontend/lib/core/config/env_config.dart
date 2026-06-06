class EnvConfig {
  static final EnvConfig _instance = EnvConfig._();
  factory EnvConfig() => _instance;
  EnvConfig._();

  static Future<void> load() async {}

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
}
