import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'supabase_service.dart';

class PaymentService extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  bool _processing = false;
  String? _lastError;
  String? _pixQrCode;
  String? _pixQrCodeText;

  bool get processing => _processing;
  String? get lastError => _lastError;
  String? get pixQrCode => _pixQrCode;
  String? get pixQrCodeText => _pixQrCodeText;

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

  Future<Map<String, dynamic>> processarCartao({
    required String vendaId,
    required double valor,
    required String metodo,
  }) async {
    _setProcessing(true);
    _setError(null);
    try {
      final token = await _supabase.getAccessToken();
      final response = await _supabase.client.functions.invoke(
        'stripe-payment',
        body: {
          'venda_id': vendaId,
          'valor': valor,
          'metodo': metodo,
        },
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.data == null) {
        throw Exception('Resposta vazia do servidor');
      }
      return response.data as Map<String, dynamic>;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> confirmarPagamentoCartao({
    required String clientSecret,
  }) async {
    _setProcessing(true);
    _setError(null);
    try {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
      );
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  Future<Map<String, dynamic>> gerarPix({
    required String vendaId,
    required double valor,
  }) async {
    _setProcessing(true);
    _setError(null);
    try {
      final token = await _supabase.getAccessToken();
      final response = await _supabase.client.functions.invoke(
        'abacatepay-pix',
        body: {
          'venda_id': vendaId,
          'valor': valor,
        },
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.data == null) {
        throw Exception('Resposta vazia do servidor');
      }
      final data = response.data as Map<String, dynamic>;
      _pixQrCode = data['qrCode'] as String?;
      _pixQrCodeText = data['qrCodeText'] as String?;
      notifyListeners();
      return data;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> registrarPagamentoDinheiro({
    required String vendaId,
    required double valor,
  }) async {
    _setError(null);
    try {
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
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> registrarPagamentoCartao({
    required String vendaId,
    required double valor,
    required String metodo,
    required String stripePaymentIntentId,
  }) async {
    _setError(null);
    try {
      await _supabase.client.from('pagamentos').insert({
        'venda_id': vendaId,
        'forma_pagamento': metodo,
        'valor': valor,
        'status': 'aprovado',
        'stripe_payment_intent_id': stripePaymentIntentId,
        'processado_em': DateTime.now().toIso8601String(),
      });

      await _supabase.client
          .from('vendas')
          .update({'status': 'confirmada'})
          .eq('id', vendaId);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> registrarPagamentoPix({
    required String vendaId,
    required double valor,
    required String cobrancaId,
    String? qrCode,
    String? qrCodeTexto,
  }) async {
    _setError(null);
    try {
      await _supabase.client.from('pagamentos').insert({
        'venda_id': vendaId,
        'forma_pagamento': 'pix',
        'valor': valor,
        'status': 'pendente',
        'abacatepay_cobranca_id': cobrancaId,
        'pix_qr_code': qrCode,
        'pix_qr_code_texto': qrCodeTexto,
        'processado_em': DateTime.now().toIso8601String(),
      });

      await _supabase.client
          .from('vendas')
          .update({'status': 'pendente'})
          .eq('id', vendaId);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }
}
