import 'package:flutter/foundation.dart';
import '../models/caixa_model.dart';
import 'supabase_service.dart';

class CaixaService extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  CaixaModel? _caixaAtual;
  String? _lastError;

  CaixaModel? get caixaAtual => _caixaAtual;
  String? get lastError => _lastError;

  Future<void> verificarCaixaAberto(String empresaId) async {
    try {
      final response = await _supabase.client
          .from('caixa')
          .select()
          .eq('empresa_id', empresaId)
          .eq('status', 'aberto')
          .order('data_abertura', ascending: false)
          .limit(1)
          .maybeSingle();

      _caixaAtual = response != null ? CaixaModel.fromJson(response) : null;
      _lastError = null;
    } catch (e) {
      // Sem o catch a exceção subia para o widget e a tela ficava sem estado
      // definido, sem indicar o que falhou.
      _caixaAtual = null;
      _lastError = e.toString();
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

  /// Fecha o caixa via RPC.
  ///
  /// O operador informa apenas o que contou na gaveta. Antes, o cliente
  /// enviava também `saldo_esperado` e `diferenca` — ou seja, controlava os
  /// dois lados da conferência e podia encobrir quebra de caixa. Agora o
  /// esperado é somado no servidor a partir dos pagamentos em dinheiro
  /// aprovados das vendas do caixa.
  ///
  /// Devolve o resultado da conferência, ou lança em caso de erro.
  Future<Map<String, dynamic>> fecharCaixa({
    required String caixaId,
    required double saldoReal,
    String? observacao,
  }) async {
    final result = await _supabase.client.rpc('fechar_caixa', params: {
      'p_caixa_id': caixaId,
      'p_saldo_real': saldoReal,
      'p_observacao': observacao,
    });

    _caixaAtual = null;
    notifyListeners();

    return Map<String, dynamic>.from(result as Map);
  }
}
