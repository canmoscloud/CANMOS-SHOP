import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/caixa_service.dart';
import '../../core/theme/app_theme.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarCaixa());
  }

  Future<void> _verificarCaixa() async {
    final auth = context.read<AuthService>();
    if (auth.empresaId != null) {
      context.read<CaixaService>().verificarCaixaAberto(auth.empresaId!);
    }
  }

  void _abrirCaixa() {
    final valorCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abrir Caixa'),
        content: TextField(
          controller: valorCtrl,
          decoration: const InputDecoration(labelText: 'Valor de Abertura'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthService>();
              final error = await context.read<CaixaService>().abrirCaixa(
                empresaId: auth.empresaId!,
                usuarioId: auth.user!.id,
                valorAbertura: double.tryParse(valorCtrl.text) ?? 0,
              );
              if (!context.mounted) return;
              Navigator.pop(ctx);
              if (error != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: AppTheme.error),
                );
              }
            },
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
  }

  String _moeda(Object? valor) {
    final n = valor is num ? valor.toDouble() : double.tryParse('$valor') ?? 0;
    return 'R\$ ${n.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  /// O operador informa só o que contou na gaveta. O saldo esperado é somado
  /// no servidor a partir dos pagamentos em dinheiro — antes este diálogo
  /// pedia o esperado digitado, o que permitia encobrir quebra de caixa.
  void _fecharCaixa() {
    final saldoRealCtrl = TextEditingController();
    final caixaService = context.read<CaixaService>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fechar Caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Conte o dinheiro na gaveta e informe o total. '
              'O sistema calcula o esperado e aponta a diferença.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: saldoRealCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Valor contado na gaveta (R\$)',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final saldoReal = double.tryParse(
                saldoRealCtrl.text.replaceAll(',', '.'),
              );

              if (saldoReal == null || saldoReal < 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Informe um valor válido')),
                );
                return;
              }

              Navigator.pop(ctx);
              try {
                final resultado = await caixaService.fecharCaixa(
                  caixaId: caixaService.caixaAtual!.id,
                  saldoReal: saldoReal,
                );
                if (mounted) _mostrarConferencia(resultado);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _mostrarConferencia(Map<String, dynamic> r) {
    final diferenca = r['diferenca'] is num
        ? (r['diferenca'] as num).toDouble()
        : double.tryParse('${r['diferenca']}') ?? 0;

    final bate = diferenca.abs() < 0.01;
    final cor = bate
        ? AppTheme.success
        : (diferenca < 0 ? AppTheme.error : AppTheme.warning);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferência de Caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _linha('Abertura', _moeda(r['valor_abertura'])),
            _linha('Vendas em dinheiro', _moeda(r['total_dinheiro'])),
            const Divider(),
            _linha('Esperado', _moeda(r['saldo_esperado'])),
            _linha('Contado', _moeda(r['saldo_real'])),
            const Divider(),
            _linha(
              bate
                  ? 'Caixa confere'
                  : (diferenca < 0 ? 'Falta' : 'Sobra'),
              _moeda(diferenca.abs()),
              cor: cor,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _linha(String label, String valor, {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            valor,
            style: TextStyle(fontWeight: FontWeight.bold, color: cor),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caixa = context.watch<CaixaService>().caixaAtual;

    return Scaffold(
      appBar: AppBar(title: const Text('Controle de Caixa')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      caixa != null ? Icons.check_circle : Icons.cancel,
                      size: 64,
                      color: caixa != null ? AppTheme.success : AppTheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      caixa != null ? 'Caixa Aberto' : 'Caixa Fechado',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    if (caixa != null) ...[
                      const SizedBox(height: 8),
                      Text('Abertura: R\$ ${caixa.valorAbertura.toStringAsFixed(2)}'),
                      Text('Aberto em: ${caixa.dataAbertura.toString().substring(0, 16)}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: caixa == null ? _abrirCaixa : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Abrir Caixa'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: caixa != null ? _fecharCaixa : null,
                icon: const Icon(Icons.stop),
                label: const Text('Fechar Caixa'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
