import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  User? _user;
  Map<String, dynamic>? _userProfile;
  bool _loading = true;

  AuthService() {
    _initialize();
  }

  User? get user => _user;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;
  String? get empresaId => _userProfile?['empresa_id'] as String?;
  String? get userName => _userProfile?['nome'] as String?;
  String? get userRole => _userProfile?['role'] as String?;
  bool get isAdmin => userRole == 'admin';

  void _initialize() {
    _user = _supabase.auth.currentUser;
    _loading = false;
    if (_user != null) _loadProfile();
    notifyListeners();

    _supabase.auth.onAuthStateChange.listen((event) {
      _user = event.session?.user;
      if (_user != null) {
        _loadProfile();
      } else {
        _userProfile = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    final response = await _supabase.client
        .from('usuarios')
        .select()
        .eq('id', _user!.id)
        .single();
    _userProfile = response;
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String nome,
    required String empresaNome,
  }) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'nome': nome, 'empresa_nome': empresaNome},
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _user = null;
    _userProfile = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getActivePlan() async {
    if (empresaId == null) return null;
    final response = await _supabase.client
        .from('assinaturas')
        .select('*, planos(*)')
        .eq('empresa_id', empresaId!)
        .eq('status', 'active')
        .single();
    return response as Map<String, dynamic>;
  }
}
