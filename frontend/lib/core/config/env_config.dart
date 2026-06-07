class EnvConfig {
  static final EnvConfig _instance = EnvConfig._();
  factory EnvConfig() => _instance;
  EnvConfig._();

  static Future<void> load() async {}

  String get supabaseUrl => const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pivfhfyqxciiucwahvvn.supabase.co',
  );

  String get supabaseAnonKey => const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpdmZoZnlxeGNpaXVjd2FodnZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4NTI0MzcsImV4cCI6MjA5NjQyODQzN30.VnwnkhJClRpjl-mNbCvwJeBLhwXedlIdi70fjOre8aA',
  );

  String get stripePublishableKey => const String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  bool get isConfigured =>
    supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
