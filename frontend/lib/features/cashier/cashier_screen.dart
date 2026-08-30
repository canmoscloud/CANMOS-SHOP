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

  void _fecharCaixa() {
    final saldoEsperadoCtrl = TextEditingController();
    final saldoRealCtrl = TextEditingController();
    final caixaService = context.read<CaixaService>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fechar Caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: saldoEsperadoCtrl,
              decoration: const InputDecoration(labelText: 'Saldo Esperado (R\$)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: saldoRealCtrl,
              decoration: const InputDecoration(labelText: 'Saldo Real (R\$)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final error = await caixaService.fecharCaixa(
                caixaId: caixaService.caixaAtual!.id,
                saldoEsperado: double.tryParse(saldoEsperadoCtrl.text) ?? 0,
                saldoReal: double.tryParse(saldoRealCtrl.text) ?? 0,
              );
              if (!context.mounted) return;
              Navigator.pop(ctx);
              if (error != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: AppTheme.error),
                );
              }
            },
            child: const Text('Fechar'),
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
