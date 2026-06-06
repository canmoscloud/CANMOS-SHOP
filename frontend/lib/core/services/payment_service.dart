import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class PaymentService {
  final SupabaseService _supabase = SupabaseService();

  Future<Map<String, dynamic>> processarCartao({
    required String vendaId,
    required double valor,
    required String metodo,
  }) async {
    final token = await _supabase.auth.currentUser!.getIdToken();
    final response = await _supabase.client.functions.invoke(
      'stripe-payment',
      body: {
        'venda_id': vendaId,
        'valor': valor,
        'metodo': metodo,
      },
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.error != null) throw Exception(response.error!.message);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> gerarPix({
    required String vendaId,
    required double valor,
  }) async {
    final token = await _supabase.auth.currentUser!.getIdToken();
    final response = await _supabase.client.functions.invoke(
      'abacatepay-pix',
      body: {
        'venda_id': vendaId,
        'valor': valor,
      },
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.error != null) throw Exception(response.error!.message);
    return response.data as Map<String, dynamic>;
  }

  Future<void> registrarPagamentoDinheiro({
    required String vendaId,
    required double valor,
  }) async {
    await _supabase.client.from('pagamentos').insert({
      'venda_id': vendaId,
      'forma_pagamento': 'dinheiro',
      'valor': valor,
      'status': 'aprovado',
      'processado_em': DateTime.now().toIso8601String(),
    });

    await _supabase.client
        .from('vendas')
        .update({'status': 'confirmada'})
        .eq('id', vendaId);
  }
}
