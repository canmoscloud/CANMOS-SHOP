import 'package:flutter/material.dart';
import '../../core/models/venda.dart';
import '../../core/theme/app_theme.dart';

class ReceiptScreen extends StatelessWidget {
  final Venda venda;
  const ReceiptScreen({super.key, required this.venda});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprovante')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Receipt content
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long, size: 48, color: AppTheme.primary),
                      const SizedBox(height: 8),
                      const Text('CANMOS-SHOP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Divider(),
                      const SizedBox(height: 16),
                      ...venda.itens.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('${item.quantidade}x ${item.produtoNome ?? 'Produto'}',
                                  style: const TextStyle(fontSize: 14)),
                            ),
                            Text(item.subtotalFormatado, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(venda.valorTotalFormatado, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.success)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...venda.pagamentos.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(p.formaPagamentoLabel, style: const TextStyle(fontSize: 13)),
                            Text(p.valorFormatado, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text('Operador: ${venda.operadorNome ?? '-'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      Text('${venda.createdAt.day}/${venda.createdAt.month}/${venda.createdAt.year} ${venda.createdAt.hour.toString().padLeft(2, '0')}:${venda.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),

            // Print button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.print),
                label: const Text('Imprimir Comprovante'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check),
                label: const Text('Concluir'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
