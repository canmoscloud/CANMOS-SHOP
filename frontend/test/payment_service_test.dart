import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:canmos_shop/core/services/payment_service.dart';

void main() {
  group('PaymentService.mensagemDeErro', () {
    test('extrai a mensagem do corpo {"error": ...} da Edge Function', () {
      const erro = FunctionException(
        status: 400,
        details: {'error': 'Valor 50.00 excede o restante da venda (30.00)'},
      );

      expect(
        PaymentService.mensagemDeErro(erro),
        'Valor 50.00 excede o restante da venda (30.00)',
      );
    });

    test('aceita details como string crua', () {
      const erro = FunctionException(status: 500, details: 'Boom');
      expect(PaymentService.mensagemDeErro(erro), 'Boom');
    });

    test('cai no reasonPhrase quando details nao tem mensagem util', () {
      const erro = FunctionException(
        status: 503,
        details: {'outra_chave': 1},
        reasonPhrase: 'Service Unavailable',
      );
      expect(PaymentService.mensagemDeErro(erro), 'Service Unavailable');
    });

    test('tem texto de fallback quando nao ha details nem reasonPhrase', () {
      const erro = FunctionException(status: 500);
      expect(PaymentService.mensagemDeErro(erro), 'Falha ao chamar o servidor');
    });

    test('propaga a mensagem de erro do Postgres (RAISE EXCEPTION da RPC)', () {
      const erro = PostgrestException(
        message: 'Venda possui 10.50 já aprovado em pagamentos. '
            'Estorne antes de cancelar.',
        code: 'P0001',
      );

      expect(
        PaymentService.mensagemDeErro(erro),
        contains('Estorne antes de cancelar'),
      );
    });

    test('nao quebra com excecao generica', () {
      expect(
        PaymentService.mensagemDeErro(Exception('qualquer coisa')),
        contains('qualquer coisa'),
      );
    });
  });
}
