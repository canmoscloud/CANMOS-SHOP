import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Orquestra os pagamentos de uma venda.
///
/// Nenhum método aqui grava em `pagamentos` ou confirma a venda: a partir da
/// migration 006 o cliente só lê essas tabelas. Dinheiro vai por RPC
/// `SECURITY DEFINER`; cartão e PIX são registrados pelas Edge Functions como
/// `pendente` e promovidos a `aprovado` pelos webhooks dos provedores. Assim o
/// app não tem como declarar um pagamento aprovado sem que o dinheiro exista.
class PaymentService extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  bool _processing = false;
  String? _lastError;

  bool get processing => _processing;
  String? get lastError => _lastError;

  void _setProcessing(bool value) {
    _processing = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _lastError = error;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// As Edge Functions devolvem `{"error": "..."}` com mensagens já prontas
  /// para o operador ("Valor excede o restante da venda"). Sem desembrulhar,
  /// o usuário veria o dump da FunctionException.
  @visibleForTesting
  static String mensagemDeErro(Object e) {
    if (e is FunctionException) {
      final details = e.details;
      if (details is Map && details['error'] is String) {
        return details['error'] as String;
      }
      if (details is String && details.isNotEmpty) return details;
      return e.reasonPhrase ?? 'Falha ao chamar o servidor';
    }
    if (e is PostgrestException) return e.message;
    return e.toString();
  }

  Future<Map<String, dynamic>> _invoke(
    String funcao,
    Map<String, dynamic> body,
  ) async {
    final token = await _supabase.getAccessToken();
    final response = await _supabase.client.functions.invoke(
      funcao,
      body: body,
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = response.data;
    if (data == null) throw Exception('Resposta vazia do servidor');
    return Map<String, dynamic>.from(data as Map);
  }

  /// Cria a PaymentIntent no Stripe. A Edge Function valida que a venda é da
  /// empresa do usuário e que o valor não passa do que falta pagar, e grava o
  /// pagamento como `pendente`.
  Future<Map<String, dynamic>> processarCartao({
    required String vendaId,
    required double valor,
    required String metodo,
  }) async {
    _setProcessing(true);
    _setError(null);
    try {
      return await _invoke('stripe-payment', {
        'venda_id': vendaId,
        'valor': valor,
        'metodo': metodo,
      });
    } catch (e) {
      final msg = PaymentService.mensagemDeErro(e);
      _setError(msg);
      throw Exception(msg);
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> confirmarPagamentoCartao({required String clientSecret}) async {
    _setProcessing(true);
    _setError(null);
    try {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
      );
    } catch (e) {
      final msg = PaymentService.mensagemDeErro(e);
      _setError(msg);
      throw Exception(msg);
    } finally {
      _setProcessing(false);
    }
  }

  /// Cria a cobrança PIX. Devolve `cobrancaId`, `pagamentoId`, `qrCode` e
  /// `qrCodeText` — o pagamento fica `pendente` até o webhook da AbacatePay.
  Future<Map<String, dynamic>> gerarPix({
    required String vendaId,
    required double valor,
  }) async {
    _setProcessing(true);
    _setError(null);
    try {
      return await _invoke('abacatepay-pix', {
        'venda_id': vendaId,
        'valor': valor,
      });
    } catch (e) {
      final msg = PaymentService.mensagemDeErro(e);
      _setError(msg);
      throw Exception(msg);
    } finally {
      _setProcessing(false);
    }
  }

  /// Dinheiro é aprovado na hora — o operador recebeu a cédula. Mesmo assim
  /// passa por RPC, que valida empresa e valor e confirma a venda apenas
  /// quando a soma dos pagamentos cobre o total.
  Future<Map<String, dynamic>> registrarPagamentoDinheiro({
    required String vendaId,
    required double valor,
  }) async {
    _setProcessing(true);
    _setError(null);
    try {
      final result = await _supabase.client.rpc(
        'registrar_pagamento_dinheiro',
        params: {'p_venda_id': vendaId, 'p_valor': valor},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      final msg = PaymentService.mensagemDeErro(e);
      _setError(msg);
      throw Exception(msg);
    } finally {
      _setProcessing(false);
    }
  }

  /// Status atual de um pagamento, para acompanhar PIX e cartão enquanto o
  /// webhook do provedor não chega.
  Future<String?> consultarStatusPagamento(String pagamentoId) async {
    final response = await _supabase.client
        .from('pagamentos')
        .select('status')
        .eq('id', pagamentoId)
        .maybeSingle();
    return response?['status'] as String?;
  }

  /// Aguarda a confirmação do provedor por polling.
  ///
  /// Retorna o status final (`aprovado`, `recusado`, `cancelado`) ou
  /// `pendente` se estourar o tempo — nesse caso a venda continua pendente e
  /// o webhook ainda pode confirmá-la depois.
  Future<String> aguardarConfirmacao(
    String pagamentoId, {
    Duration intervalo = const Duration(seconds: 3),
    Duration limite = const Duration(minutes: 5),
  }) async {
    final fim = DateTime.now().add(limite);

    while (DateTime.now().isBefore(fim)) {
      await Future<void>.delayed(intervalo);
      final status = await consultarStatusPagamento(pagamentoId);
      if (status != null && status != 'pendente') return status;
    }

    return 'pendente';
  }
}
