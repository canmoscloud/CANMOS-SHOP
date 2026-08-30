import 'package:flutter/foundation.dart';
import '../models/venda.dart';
import 'supabase_service.dart';

class VendaService extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();

  /// Cria a venda via RPC. O servidor deriva usuário/empresa da sessão,
  /// recalcula os preços a partir da tabela de produtos e vincula ao caixa
  /// aberto — itens carregam apenas produto_id e quantidade.
  Future<Map<String, dynamic>> criarVenda({
    double desconto = 0,
    required List<Map<String, dynamic>> itens,
  }) async {
    final response = await _supabase.client.rpc('criar_venda', params: {
      'p_itens': itens,
      'p_desconto': desconto,
    });
    if (response == null || response is! Map) {
      throw Exception('Erro ao criar venda: resposta inválida');
    }
    return Map<String, dynamic>.from(response);
  }

  Future<List<Venda>> listarVendas(String empresaId, {DateTime? inicio, DateTime? fim}) async {
    var query = _supabase.client
        .from('vendas')
        .select('*, itens_venda(*, produtos(*)), pagamentos(*), usuarios(nome)')
        .eq('empresa_id', empresaId);

    if (inicio != null) {
      query = query.gte('created_at', inicio.toIso8601String());
    }
    if (fim != null) {
      query = query.lte('created_at', fim.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((e) => Venda.fromJson(e)).toList();
  }

  Future<void> cancelarVenda(String vendaId) async {
    await _supabase.client
        .from('vendas')
        .update({'status': 'cancelada'})
        .eq('id', vendaId);
    notifyListeners();
  }

  Future<Map<String, double>> getResumoVendas(String empresaId, {required DateTime inicio, required DateTime fim}) async {
    final vendas = await listarVendas(empresaId, inicio: inicio, fim: fim);
    final confirmadas = vendas.where((v) => v.status == 'confirmada');

    double cartao = 0, pix = 0, dinheiro = 0, total = 0;

    for (var venda in confirmadas) {
      total += venda.valorLiquido;
      for (var pag in venda.pagamentos) {
        if (pag.status == 'aprovado') {
          switch (pag.formaPagamento) {
            case 'cartao_credito': cartao += pag.valor; break;
            case 'cartao_debito': cartao += pag.valor; break;
            case 'pix': pix += pag.valor; break;
            case 'dinheiro': dinheiro += pag.valor; break;
          }
        }
      }
    }

    return {'total': total, 'cartao': cartao, 'pix': pix, 'dinheiro': dinheiro};
  }
}
