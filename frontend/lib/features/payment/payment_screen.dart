import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/produto.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/venda_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/theme/app_theme.dart';
import '../receipt/receipt_screen.dart';

class MetodoPagamento {
  String tipo;
  double valor;

  MetodoPagamento({required this.tipo, required this.valor});

  String get label {
    switch (tipo) {
      case 'cartao_credito': return 'Cartão Crédito';
      case 'cartao_debito': return 'Cartão Débito';
      case 'pix': return 'PIX';
      case 'dinheiro': return 'Dinheiro';
      default: return tipo;
    }
  }

  IconData get icon {
    switch (tipo) {
      case 'cartao_credito': return Icons.credit_card;
      case 'cartao_debito': return Icons.credit_card;
      case 'pix': return Icons.pix;
      case 'dinheiro': return Icons.money;
      default: return Icons.payment;
    }
  }

  Color get color {
    switch (tipo) {
      case 'cartao_credito': return AppTheme.primary;
      case 'cartao_debito': return AppTheme.primaryDark;
      case 'pix': return AppTheme.pix;
      case 'dinheiro': return AppTheme.warning;
      default: return AppTheme.textSecondary;
    }
  }
}

class PaymentScreen extends StatefulWidget {
  final List<Map<String, dynamic>> itens;
  final double total;
  final double desconto;

  const PaymentScreen({
    super.key,
    required this.itens,
    required this.total,
    this.desconto = 0,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _processing = false;
  String? _vendaId;

  final _metodosSelecionados = <MetodoPagamento>[];
  final Map<String, TextEditingController> _valorControllers = {};

  double get _totalComDesconto => widget.total - widget.desconto;
  double get _totalRestante {
    final pago = _metodosSelecionados.fold(0.0, (s, m) => s + m.valor);
    return (_totalComDesconto - pago).clamp(0, _totalComDesconto);
  }

  @override
  void initState() {
    super.initState();
    for (final tipo in ['cartao_credito', 'cartao_debito', 'pix', 'dinheiro']) {
      _valorControllers[tipo] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final ctrl in _valorControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addMetodo(String tipo) {
    if (_totalRestante <= 0) return;
    final valorInput = double.tryParse(_valorControllers[tipo]?.text.replaceAll(',', '.') ?? '') ?? _totalRestante;
    final valorReal = double.parse(valorInput.clamp(0.0, _totalRestante).toStringAsFixed(2));

    if (valorReal <= 0) return;

    setState(() {
      _metodosSelecionados.add(MetodoPagamento(tipo: tipo, valor: valorReal));
      _valorControllers[tipo]?.clear();
    });
  }

  void _removerMetodo(int index) {
    setState(() => _metodosSelecionados.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar Venda')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('Valor Total', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text('R\$ ${_totalComDesconto.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.success)),
                    if (widget.desconto > 0)
                      Text('Desconto: R\$ ${widget.desconto.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    Text('${widget.itens.length} item(ns) no carrinho',
                        style: const TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
            if (_metodosSelecionados.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Formas de Pagamento', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._metodosSelecionados.asMap().entries.map((e) => ListTile(
                        dense: true,
                        leading: Icon(e.value.icon, color: e.value.color, size: 20),
                        title: Text(e.value.label, style: const TextStyle(fontSize: 13)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('R\$ ${e.value.valor.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _removerMetodo(e.key),
                              child: const Icon(Icons.close, size: 18, color: AppTheme.error),
                            ),
                          ],
                        ),
                      )),
                      if (_totalRestante > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text('Restante: ', style: TextStyle(color: AppTheme.textSecondary)),
                              Text('R\$ ${_totalRestante.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_totalRestante > 0) ...[
              const Text('Adicionar Forma de Pagamento',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: _buildMetodosGrid(),
              ),
            ],
            if (_totalRestante <= 0 && _metodosSelecionados.isNotEmpty) ...[
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _processarPagamentos,
                  icon: _processing
                      ? const SizedBox(height: 24, width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle),
                  label: const Text('Confirmar Pagamento'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetodosGrid() {
    final tiposDisponiveis = ['cartao_credito', 'cartao_debito', 'pix', 'dinheiro'];
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: tiposDisponiveis.map((tipo) {
        final nomes = {
          'cartao_credito': 'Cartão\nCrédito',
          'cartao_debito': 'Cartão\nDébito',
          'pix': 'PIX',
          'dinheiro': 'Dinheiro',
        };
        final icones = {
          'cartao_credito': Icons.credit_card,
          'cartao_debito': Icons.credit_card,
          'pix': Icons.pix,
          'dinheiro': Icons.money,
        };
        final cores = {
          'cartao_credito': AppTheme.primary,
          'cartao_debito': AppTheme.primaryDark,
          'pix': AppTheme.pix,
          'dinheiro': AppTheme.warning,
        };
        return Card(
          child: InkWell(
            onTap: _processing ? null : () => _addMetodo(tipo),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icones[tipo]!, size: 28, color: cores[tipo]),
                  const SizedBox(height: 4),
                  Text(nomes[tipo]!, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cores[tipo])),
                  SizedBox(
                    width: 80,
                    height: 28,
                    child: TextField(
                      controller: _valorControllers[tipo],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                      decoration: const InputDecoration(
                        hintText: 'R\$',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<String> _criarVenda() async {
    if (_vendaId != null) return _vendaId!;
    final vendaService = context.read<VendaService>();

    final itensJson = widget.itens.map((item) => {
      'produto_id': (item['produto'] as Produto).id,
      'quantidade': item['quantidade'],
    }).toList();

    final result = await vendaService.criarVenda(
      desconto: widget.desconto,
      itens: itensJson,
    );

    _vendaId = result['id'] as String;
    return _vendaId!;
  }

  Future<void> _processarPagamentos() async {
    setState(() => _processing = true);
    try {
      await _criarVenda();

      if (!mounted) return;
      final paymentService = context.read<PaymentService>();

      for (final metodo in _metodosSelecionados) {
        if (metodo.tipo == 'dinheiro') {
          await paymentService.registrarPagamentoDinheiro(
            vendaId: _vendaId!,
            valor: metodo.valor,
          );
        } else if (metodo.tipo == 'cartao_credito' || metodo.tipo == 'cartao_debito') {
          final result = await paymentService.processarCartao(
            vendaId: _vendaId!,
            valor: metodo.valor,
            metodo: metodo.tipo,
          );

          final clientSecret = result['client_secret'] as String?;
          final paymentIntentId = result['payment_intent_id'] as String?;

          if (clientSecret != null && clientSecret.isNotEmpty) {
            await paymentService.confirmarPagamentoCartao(
              clientSecret: clientSecret,
            );
          }

          await paymentService.registrarPagamentoCartao(
            vendaId: _vendaId!,
            valor: metodo.valor,
            metodo: metodo.tipo,
            stripePaymentIntentId: paymentIntentId ?? '',
          );
        } else if (metodo.tipo == 'pix') {
          final pixData = await paymentService.gerarPix(
            vendaId: _vendaId!,
            valor: metodo.valor,
          );

          await paymentService.registrarPagamentoPix(
            vendaId: _vendaId!,
            valor: metodo.valor,
            cobrancaId: pixData['cobrancaId'] as String? ?? '',
            qrCode: pixData['qrCode'] as String?,
            qrCodeTexto: pixData['qrCodeText'] as String?,
          );
        }
      }

      if (mounted) {
        _irParaRecibo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _irParaRecibo() async {
    try {
      final vendaService = context.read<VendaService>();
      final vendas = await vendaService.listarVendas(
        context.read<AuthService>().empresaId!,
      );
      final venda = vendas.firstWhere((v) => v.id == _vendaId);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReceiptScreen(venda: venda)),
        );
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }
}
