import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/produto.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/venda_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/theme/app_theme.dart';

class PaymentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> itens;
  final double total;
  const PaymentScreen({super.key, required this.itens, required this.total});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _vendaService = VendaService();
  final _paymentService = PaymentService();
  bool _processing = false;
  String? _vendaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar Venda')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Total
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('Valor Total', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text('R\$ ${widget.total.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.success)),
                    const SizedBox(height: 8),
                    Text('${widget.itens.length} item(ns) no carrinho', style: const TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text('Forma de Pagamento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Payment options
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _paymentButton('Cartão\nCrédito', Icons.credit_card, AppTheme.primary, () => _processarPagamento('cartao_credito')),
                  _paymentButton('Cartão\nDébito', Icons.credit_card, AppTheme.primaryDark, () => _processarPagamento('cartao_debito')),
                  _paymentButton('PIX', Icons.pix, AppTheme.pix, () => _processarPix()),
                  _paymentButton('Dinheiro', Icons.money, AppTheme.warning, () => _processarDinheiro()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: _processing ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: TextStyle(
                fontWeight: FontWeight.w600, color: color,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _criarVenda() async {
    if (_vendaId != null) return;
    final auth = context.read<AuthService>();

    final itensJson = widget.itens.map((item) => {
      'produto_id': (item['produto'] as Produto).id,
      'quantidade': item['quantidade'],
      'preco_unitario': (item['produto'] as Produto).preco,
      'subtotal': item['subtotal'],
    }).toList();

    final result = await _vendaService.criarVenda(
      empresaId: auth.empresaId!,
      usuarioId: auth.user!.id,
      valorTotal: widget.total,
      itens: itensJson,
    );

    _vendaId = result['id'] as String;
  }

  Future<void> _processarPagamento(String metodo) async {
    setState(() => _processing = true);
    try {
      await _criarVenda();
      final result = await _paymentService.processarCartao(
        vendaId: _vendaId!,
        valor: widget.total,
        metodo: metodo,
      );

      if (mounted) {
        _showSuccessDialog('Pagamento processado!', 'Pagamento via cartão iniciado.');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processarPix() async {
    setState(() => _processing = true);
    try {
      await _criarVenda();
      final result = await _paymentService.gerarPix(
        vendaId: _vendaId!,
        valor: widget.total,
      );

      if (mounted) {
        _showPixDialog(result);
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processarDinheiro() async {
    setState(() => _processing = true);
    try {
      await _criarVenda();
      await _paymentService.registrarPagamentoDinheiro(
        vendaId: _vendaId!,
        valor: widget.total,
      );

      if (mounted) {
        _showSuccessDialog('Venda concluída!', 'Pagamento em dinheiro registrado.');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppTheme.success, size: 48),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPixDialog(Map<String, dynamic> pixData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIX Gerado', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.pix.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.network(pixData['qrCode'] as String, width: 200, height: 200),
            ),
            const SizedBox(height: 16),
            const Text('Escaneie o QR Code com seu banco', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(pixData['qrCodeText'] as String? ?? '',
                  style: const TextStyle(fontSize: 11)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Concluído'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro: $message'), backgroundColor: AppTheme.error),
    );
  }
}
