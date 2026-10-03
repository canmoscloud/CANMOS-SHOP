import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:canmos_shop/core/services/payment_service.dart';
import 'package:canmos_shop/features/payment/pix_qr_dialog.dart';

/// Substitui o polling real: o diálogo só precisa saber qual status o
/// servidor devolveu.
class _FakePaymentService extends PaymentService {
  final String status;
  _FakePaymentService(this.status);

  @override
  Future<String> aguardarConfirmacao(
    String pagamentoId, {
    Duration intervalo = const Duration(seconds: 3),
    Duration limite = const Duration(minutes: 5),
  }) async =>
      status;
}

/// Abre o diálogo pelo caminho real (showDialog), e não dentro de um
/// Scaffold.body: AlertDialog não calcula dimensões intrínsecas fora de rota.
Future<String?> _abrir(
  WidgetTester tester,
  String status,
  PixQrDialog dialog,
) async {
  String? resultado;

  await tester.pumpWidget(
    ChangeNotifierProvider<PaymentService>.value(
      value: _FakePaymentService(status),
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                resultado = await showDialog<String>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => dialog,
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pump(); // abre a rota do diálogo
  await tester.pump(); // deixa o status assincrono chegar ao setState
  return resultado;
}

void main() {
  const copiaECola =
      '00020126580014br.gov.bcb.pix0136abc-123,com-virgula5204000053039865802BR';

  group('escolherFonteQr', () {
    test('copia-e-cola tem precedencia sobre a imagem do provedor', () {
      expect(
        escolherFonteQr(texto: copiaECola, imagem: 'AAAA'),
        PixQrFonte.copiaECola,
      );
    });

    test('usa a imagem quando nao vem o copia-e-cola', () {
      expect(escolherFonteQr(imagem: 'AAAA'), PixQrFonte.imagem);
      expect(escolherFonteQr(texto: '', imagem: 'AAAA'), PixQrFonte.imagem);
    });

    test('indisponivel quando nao vem nada utilizavel', () {
      expect(escolherFonteQr(), PixQrFonte.indisponivel);
      expect(escolherFonteQr(texto: '', imagem: ''), PixQrFonte.indisponivel);
    });
  });

  testWidgets('gera o QR a partir do copia-e-cola', (tester) async {
    await _abrir(
      tester,
      'pendente',
      const PixQrDialog(
        pagamentoId: 'pag-1',
        valor: 10.5,
        qrCodeText: copiaECola,
      ),
    );

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('R\$ 10,50'), findsOneWidget);
  });

  testWidgets('avisa quando o provedor nao devolve codigo', (tester) async {
    await _abrir(
      tester,
      'pendente',
      const PixQrDialog(pagamentoId: 'pag-2', valor: 5),
    );

    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('não retornou o código PIX'), findsOneWidget);
  });

  testWidgets('copia o codigo PIX para a area de transferencia',
      (tester) async {
    final chamadas = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        chamadas.add(call);
        return null;
      },
    );

    await _abrir(
      tester,
      'pendente',
      const PixQrDialog(
        pagamentoId: 'pag-3',
        valor: 1,
        qrCodeText: copiaECola,
      ),
    );

    await tester.tap(find.text('Copiar código PIX'));
    await tester.pump();

    final copia = chamadas.firstWhere((c) => c.method == 'Clipboard.setData');
    expect((copia.arguments as Map)['text'], copiaECola);
    expect(find.text('Código copiado'), findsOneWidget);
  });

  testWidgets('enquanto pendente, segue aguardando e nao fecha', (tester) async {
    await _abrir(
      tester,
      'pendente',
      const PixQrDialog(
        pagamentoId: 'pag-4',
        valor: 1,
        qrCodeText: copiaECola,
      ),
    );

    expect(find.text('Aguardando pagamento...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(PixQrDialog), findsOneWidget);
  });

  testWidgets('recusado aparece na tela e nao fecha sozinho', (tester) async {
    await _abrir(
      tester,
      'recusado',
      const PixQrDialog(
        pagamentoId: 'pag-5',
        valor: 1,
        qrCodeText: copiaECola,
      ),
    );

    expect(find.text('Pagamento recusado'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(PixQrDialog), findsOneWidget);
  });

  testWidgets('aprovado confirma e fecha devolvendo o status', (tester) async {
    await _abrir(
      tester,
      'aprovado',
      const PixQrDialog(
        pagamentoId: 'pag-6',
        valor: 1,
        qrCodeText: copiaECola,
      ),
    );

    expect(find.text('Pagamento confirmado'), findsOneWidget);

    // O diálogo se fecha sozinho após mostrar a confirmação. O timer de 900ms
    // não agenda frame, então pumpAndSettle sozinho não avançaria o relógio.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(PixQrDialog), findsNothing);
  });
}
