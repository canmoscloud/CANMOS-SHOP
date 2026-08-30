import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/models/venda.dart';
import '../../core/theme/app_theme.dart';

class ReceiptScreen extends StatelessWidget {
  final Venda venda;
  const ReceiptScreen({super.key, required this.venda});

  Future<void> _imprimir(BuildContext context) async {
    try {
      final pdfBytes = await _gerarPdf(PdfPageFormat.a4);
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'CANMOS-SHOP - Comprovante',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao imprimir: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<Uint8List> _gerarPdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'CANMOS-SHOP',
                  style: const pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Sistema PDV Completo',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              ...venda.itens.map((item) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text('${item.quantidade}x ${item.produtoNome ?? 'Produto'}'),
                  ),
                  pw.Text(item.subtotalFormatado),
                ],
              )),
              pw.Divider(),
              if (venda.desconto > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Desconto:'),
                    pw.Text(venda.descontoFormatado),
                  ],
                ),
                pw.SizedBox(height: 5),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text(venda.valorTotalFormatado, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              ...venda.pagamentos.map((p) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(p.formaPagamentoLabel),
                  pw.Text(p.valorFormatado),
                ],
              )),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('Operador: ${venda.operadorNome ?? '-'}'),
              pw.Text('${venda.createdAt.day}/${venda.createdAt.month}/${venda.createdAt.year} '
                  '${venda.createdAt.hour.toString().padLeft(2, '0')}:${venda.createdAt.minute.toString().padLeft(2, '0')}'),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Obrigado pela preferencia!'),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprovante')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
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
                        if (venda.desconto > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Desconto:', style: TextStyle(color: AppTheme.warning)),
                              Text(venda.descontoFormatado, style: const TextStyle(color: AppTheme.warning)),
                            ],
                          ),
                          const Divider(),
                        ],
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
            ),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _imprimir(context),
                icon: const Icon(Icons.print),
                label: const Text('Imprimir Comprovante'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
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
