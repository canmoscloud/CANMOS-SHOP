import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/categoria.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/produto_service.dart';
import '../../core/theme/app_theme.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    if (auth.empresaId == null) return;
    await context.read<ProdutoService>().loadCategorias(auth.empresaId!);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProdutoService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoriaDialog(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: service.categorias.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.category, size: 64, color: AppTheme.textSecondary),
                    const SizedBox(height: 16),
                    const Text('Nenhuma categoria cadastrada'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showCategoriaDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar Categoria'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                itemCount: service.categorias.length,
                itemBuilder: (_, i) => _buildCategoriaTile(service.categorias[i]),
              ),
      ),
    );
  }

  Widget _buildCategoriaTile(Categoria categoria) {
    final color = Color(int.parse('0xFF${categoria.cor.replaceAll('#', '')}'));
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(
            categoria.nome[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(categoria.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Ordem: ${categoria.ordem}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showCategoriaDialog(categoria: categoria),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: AppTheme.error),
              onPressed: () => _confirmarExclusao(categoria),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoriaDialog({Categoria? categoria}) {
    final nomeCtrl = TextEditingController(text: categoria?.nome);
    final formKey = GlobalKey<FormState>();
    String cor = categoria?.cor ?? '#6B7280';
    int ordem = categoria?.ordem ?? 0;

    final coresDisponiveis = [
      '#EF4444', '#F59E0B', '#10B981', '#3B82F6',
      '#8B5CF6', '#EC4899', '#6B7280', '#14B8A6',
      '#F97316', '#06B6D4', '#84CC16', '#E11D48',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(categoria == null ? 'Nova Categoria' : 'Editar Categoria',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome da Categoria'),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Cor', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: coresDisponiveis.map((c) {
                      final selected = cor == c;
                      return GestureDetector(
                        onTap: () => setSheetState(() => cor = c),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Color(int.parse('0xFF${c.replaceAll('#', '')}')),
                            shape: BoxShape.circle,
                            border: selected ? Border.all(color: Colors.white, width: 3) : null,
                            boxShadow: selected ? [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                            ] : null,
                          ),
                          child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: ordem.toString(),
                    decoration: const InputDecoration(labelText: 'Ordem'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => ordem = int.tryParse(v) ?? 0,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final auth = context.read<AuthService>();
                        final service = context.read<ProdutoService>();

                        if (categoria == null) {
                          await service.criarCategoria(Categoria(
                            id: '',
                            empresaId: auth.empresaId!,
                            nome: nomeCtrl.text,
                            cor: cor,
                            ordem: ordem,
                          ));
                        } else {
                          await service.atualizarCategoria(categoria.id, {
                            'nome': nomeCtrl.text,
                            'cor': cor,
                            'ordem': ordem,
                          });
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _load();
                      },
                      child: Text(categoria == null ? 'Salvar' : 'Atualizar'),
                    ),
                  ),
                  if (categoria != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await context.read<ProdutoService>().deletarCategoria(categoria.id);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          await _load();
                        },
                        icon: const Icon(Icons.delete, color: AppTheme.error),
                        label: const Text('Excluir', style: TextStyle(color: AppTheme.error)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmarExclusao(Categoria categoria) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Categoria'),
        content: Text('Deseja excluir "${categoria.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await context.read<ProdutoService>().deletarCategoria(categoria.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
