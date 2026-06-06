import 'package:flutter/foundation.dart';
import '../models/caixa_model.dart';
import 'supabase_service.dart';

class CaixaService extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  CaixaModel? _caixaAtual;

  CaixaModel? get caixaAtual => _caixaAtual;

  Future<void> verificarCaixaAberto(String empresaId) async {
    final response = await _supabase.client
        .from('caixa')
        .select()
        .eq('empresa_id', empresaId)
        .eq('status', 'aberto')
        .order('data_abertura', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null) {
      _caixaAtual = CaixaModel.fromJson(response);
    } else {
      _caixaAtual = null;
    }
    notifyListeners();
  }

  Future<String?> abrirCaixa({
    required String empresaId,
    required String usuarioId,
    required double valorAbertura,
  }) async {
    try {
      final response = await _supabase.client.from('caixa').insert({
        'empresa_id': empresaId,
        'usuario_id': usuarioId,
        'valor_abertura': valorAbertura,
        'status': 'aberto',
      }).select().single();

      _caixaAtual = CaixaModel.fromJson(response);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> fecharCaixa({
    required String caixaId,
    required double saldoEsperado,
    required double saldoReal,
    String? observacao,
  }) async {
    try {
      final diferenca = saldoReal - saldoEsperado;
      await _supabase.client.from('caixa').update({
        'valor_fechamento': saldoReal,
        'saldo_esperado': saldoEsperado,
        'saldo_real': saldoReal,
        'diferenca': diferenca,
        'observacao': observacao,
        'status': 'fechado',
        'data_fechamento': DateTime.now().toIso8601String(),
      }).eq('id', caixaId);

      _caixaAtual = null;
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
