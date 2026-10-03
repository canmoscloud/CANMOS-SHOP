import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/payment_service.dart';
import '../../core/theme/app_theme.dart';

/// De onde o QR exibido será desenhado.
enum PixQrFonte {
  /// Gerado localmente a partir do copia-e-cola (preferido).
  copiaECola,

  /// Imagem pronta devolvida pelo provedor, em base64.
  imagem,

  /// Provedor não devolveu nada utilizável.
  indisponivel,
}

/// Decide qual fonte usar para o QR.
///
/// O copia-e-cola tem precedência: é o dado canônico do PIX e desenhar a
/// partir dele independe do formato que o provedor escolheu para a imagem.
PixQrFonte escolherFonteQr({String? texto, String? imagem}) {
  if (texto != null && texto.isNotEmpty) return PixQrFonte.copiaECola;
  if (imagem != null && imagem.isNotEmpty) return PixQrFonte.imagem;
  return PixQrFonte.indisponivel;
}

/// Exibe o QR Code do PIX e acompanha a confirmação.
///
/// Fecha devolvendo o status final do pagamento: `aprovado`, `recusado`,
/// `cancelado`, ou `pendente` se o operador fechar antes da confirmação (a
/// venda segue pendente e o webhook ainda pode confirmá-la).
class PixQrDialog extends StatefulWidget {
  final String pagamentoId;
  final String? qrCodeText;
  final String? qrCodeImagem;
  final double valor;

  const PixQrDialog({
    super.key,
    required this.pagamentoId,
    required this.valor,
    this.qrCodeText,
    this.qrCodeImagem,
  });

  @override
  State<PixQrDialog> createState() => _PixQrDialogState();
}

class _PixQrDialogState extends State<PixQrDialog> {
  String _status = 'pendente';
  bool _copiado = false;

  @override
  void initState() {
    super.initState();
    _acompanhar();
  }

  Future<void> _acompanhar() async {
    final service = context.read<PaymentService>();
    final status = await service.aguardarConfirmacao(widget.pagamentoId);
    if (!mounted) return;
    setState(() => _status = status);

    // Dá um instante para o operador ver a confirmação antes de sair.
    if (status == 'aprovado') {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(status);
    }
  }

  Future<void> _copiar() async {
    final texto = widget.qrCodeText;
    if (texto == null || texto.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texto));
    if (!mounted) return;
    setState(() => _copiado = true);
  }

  static const double _lado = 220;

  /// O conteúdo vai sempre dentro de um SizedBox de lado fixo.
  ///
  /// Não é só estética: QrImageView usa LayoutBuilder internamente e o
  /// AlertDialog mede o conteúdo por dimensões intrínsecas, que LayoutBuilder
  /// não fornece — sem o SizedBox, o diálogo estoura asserção de layout.
  Widget _buildQr() {
    final fonte = escolherFonteQr(
      texto: widget.qrCodeText,
      imagem: widget.qrCodeImagem,
    );

    return SizedBox(
      width: _lado,
      height: _lado,
      child: _conteudoQr(fonte),
    );
  }

  Widget _conteudoQr(PixQrFonte fonte) {
    switch (fonte) {
      case PixQrFonte.copiaECola:
        return QrImageView(
          data: widget.qrCodeText!,
          version: QrVersions.auto,
          backgroundColor: Colors.white,
        );

      case PixQrFonte.imagem:
        final imagem = widget.qrCodeImagem!;
        try {
          final base64Puro =
              imagem.contains(',') ? imagem.split(',').last : imagem;
          return Image.memory(base64Decode(base64Puro), fit: BoxFit.contain);
        } catch (_) {
          return _qrIndisponivel();
        }

      case PixQrFonte.indisponivel:
        return _qrIndisponivel();
    }
  }

  Widget _qrIndisponivel() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'O provedor não retornou o código PIX. '
          'Cancele e tente novamente.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStatus() {
    switch (_status) {
      case 'aprovado':
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppTheme.success),
            SizedBox(width: 8),
            Text('Pagamento confirmado'),
          ],
        );
      case 'recusado':
      case 'cancelado':
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: AppTheme.error),
            const SizedBox(width: 8),
            Text('Pagamento $_status'),
          ],
        );
      default:
        return const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Aguardando pagamento...'),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final temTexto = widget.qrCodeText != null && widget.qrCodeText!.isNotEmpty;

    return AlertDialog(
      title: const Text('Pagamento via PIX'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'R\$ ${widget.valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildQr(),
            ),
            const SizedBox(height: 16),
            if (temTexto)
              OutlinedButton.icon(
                onPressed: _copiar,
                icon: Icon(_copiado ? Icons.check : Icons.copy, size: 18),
                label: Text(_copiado ? 'Código copiado' : 'Copiar código PIX'),
              ),
            const SizedBox(height: 16),
            _buildStatus(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_status),
          child: Text(_status == 'aprovado' ? 'Continuar' : 'Fechar'),
        ),
      ],
    );
  }
}
