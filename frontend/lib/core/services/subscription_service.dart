import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class SubscriptionService extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  Future<Map<String, dynamic>?> getPlanoAtual(String empresaId) async {
    try {
      final response = await _supabase.client
          .from('assinaturas')
          .select('*, planos(*)')
          .eq('empresa_id', empresaId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<int> getContagemProdutos(String empresaId) async {
    final response = await _supabase.client
        .from('produtos')
        .select('id')
        .eq('empresa_id', empresaId)
        .eq('ativo', true);
    return (response as List).length;
  }

  /// Conta vendas confirmadas do mês corrente (o limite do plano é mensal).
  Future<int> getContagemVendas(String empresaId) async {
    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month, 1);
    final response = await _supabase.client
        .from('vendas')
        .select('id')
        .eq('empresa_id', empresaId)
        .eq('status', 'confirmada')
        .gte('created_at', inicioMes.toIso8601String());
    return (response as List).length;
  }

  Future<Map<String, dynamic>> checkLimits(String empresaId) async {
    final plano = await getPlanoAtual(empresaId);
    final produtos = await getContagemProdutos(empresaId);
    final vendas = await getContagemVendas(empresaId);

    final planoData = plano?['planos'] as Map<String, dynamic>?;
    final limiteProdutos = planoData?['limite_produtos'] as int? ?? 3;
    final limiteVendas = planoData?['limite_vendas'] as int? ?? 5;
    final planoNome = planoData?['nome'] as String? ?? 'Free';

    return {
      'plano': planoNome,
      'produtos': produtos,
      'limiteProdutos': limiteProdutos,
      'vendas': vendas,
      'limiteVendas': limiteVendas,
      'produtosOk': limiteProdutos == -1 || produtos < limiteProdutos,
      'vendasOk': limiteVendas == -1 || vendas < limiteVendas,
    };
  }

  Future<String?> criarCheckoutSession({
    required String empresaId,
    required String priceId,
  }) async {
    try {
      final token = await _supabase.getAccessToken();
      final response = await _supabase.client.functions.invoke(
        'stripe-subscription',
        body: {
          'action': 'create_checkout',
          'empresa_id': empresaId,
          'price_id': priceId,
        },
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.data == null) throw Exception('Resposta vazia');
      final data = response.data as Map<String, dynamic>;
      return data['url'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<String?> abrirPortalAssinatura({required String empresaId}) async {
    try {
      final token = await _supabase.getAccessToken();
      final response = await _supabase.client.functions.invoke(
        'stripe-subscription',
        body: {
          'action': 'create_portal',
          'empresa_id': empresaId,
        },
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.data == null) throw Exception('Resposta vazia');
      final data = response.data as Map<String, dynamic>;
      return data['url'] as String?;
    } catch (e) {
      return null;
    }
  }
}
