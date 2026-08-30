import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: EnvConfig().supabaseUrl,
      publishableKey: EnvConfig().supabaseAnonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;

  GoTrueClient get auth => client.auth;

  StorageFileApi storageFrom(String bucket) => client.storage.from(bucket);

  Future<String> getAccessToken() async {
    final session = auth.currentSession;
    return session?.accessToken ?? '';
  }
}
