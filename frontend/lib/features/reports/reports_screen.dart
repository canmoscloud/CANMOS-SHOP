import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/venda_service.dart';
import '../../core/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _vendaService = VendaService();
  DateTime _inicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fim = DateTime.now();
  Map<String, double> _resumo = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    if (auth.empresaId != null) {
      _resumo = await _vendaService.getResumoVendas(
        auth.empresaId!,
        inicio: _inicio,
        fim: _fim,
      );
    }
    setState(() => _loading = false);
  }

  Future<void> _selecionarPeriodo() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _inicio, end: _fim),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() { _inicio = picked.start; _fim = picked.end; });
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period selector
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.date_range),
                        title: Text('${_inicio.day}/${_inicio.month}/${_inicio.year} - ${_fim.day}/${_fim.month}/${_fim.year}'),
                        trailing: const Icon(Icons.edit),
                        onTap: _selecionarPeriodo,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Total card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Text('Total do Período', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                            const SizedBox(height: 8),
                            Text(
                              'R\$ ${(_resumo['total'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.success),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Chart
                    SizedBox(
                      height: 200,
                      child: _resumo.isEmpty
                          ? const Center(child: Text('Nenhuma venda no período'))
                          : PieChart(
                              PieChartData(
                                sections: _buildChartSections(),
                                centerSpaceRadius: 50,
                                sectionsSpace: 2,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Breakdown
                    _resumoCard('Cartão', _resumo['cartao'] ?? 0, AppTheme.primary),
                    _resumoCard('PIX', _resumo['pix'] ?? 0, AppTheme.pix),
                    _resumoCard('Dinheiro', _resumo['dinheiro'] ?? 0, AppTheme.warning),
                  ],
                ),
              ),
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections() {
    final data = {
      'Cartão': _resumo['cartao'] ?? 0,
      'PIX': _resumo['pix'] ?? 0,
      'Dinheiro': _resumo['dinheiro'] ?? 0,
    };
    final colors = [AppTheme.primary, AppTheme.pix, AppTheme.warning];
    int i = 0;

    return data.entries.map((e) {
      final section = PieChartSectionData(
        value: e.value,
        color: colors[i++],
        title: e.value > 0 ? 'R\$ ${e.value.toStringAsFixed(0)}' : '',
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
        radius: 60,
      );
      return section;
    }).toList();
  }

  Widget _resumoCard(String label, double valor, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: Text(label[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        title: Text(label),
        trailing: Text('R\$ ${valor.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
