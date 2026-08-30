import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/models/produto.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/produto_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    if (auth.empresaId == null) return;
    final service = context.read<ProdutoService>();
    await Future.wait([
      service.loadProdutos(auth.empresaId!),
      service.loadCategorias(auth.empresaId!),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ProdutoService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Produtos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProdutoDialog(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: service.loading
            ? const Center(child: CircularProgressIndicator())
            : service.produtos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2, size: 64, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        const Text('Nenhum produto cadastrado'),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showProdutoDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar Produto'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: service.produtos.length,
                    itemBuilder: (_, i) => _buildProdutoTile(service.produtos[i]),
                  ),
      ),
    );
  }

  Widget _buildProdutoTile(Produto produto) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: produto.imagemUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(produto.imagemUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2)),
                )
              : const Icon(Icons.inventory_2, color: AppTheme.primary),
        ),
        title: Text(produto.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (produto.categoriaNome != null)
              Text(produto.categoriaNome!, style: const TextStyle(fontSize: 12)),
            if (produto.codigoBarras != null)
              Text('Cód: ${produto.codigoBarras}', style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Text(produto.precoFormatado, style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.success,
        )),
        onTap: () => _showProdutoDialog(produto: produto),
      ),
    );
  }

  void _showProdutoDialog({Produto? produto}) {
    final nomeCtrl = TextEditingController(text: produto?.nome);
    final descCtrl = TextEditingController(text: produto?.descricao);
    final precoCtrl = TextEditingController(text: produto?.preco.toString());
    final codCtrl = TextEditingController(text: produto?.codigoBarras);
    final formKey = GlobalKey<FormState>();
    String? categoriaId = produto?.categoriaId;
    String? imagemUrl = produto?.imagemUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final categorias = context.read<ProdutoService>().categorias;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(produto == null ? 'Novo Produto' : 'Editar Produto',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nomeCtrl,
                    decoration: const InputDecoration(labelText: 'Nome do Produto'),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Descrição'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: precoCtrl,
                          decoration: const InputDecoration(labelText: 'Preço (R\$)'),
                          keyboardType: TextInputType.number,
                          validator: (v) => (v?.isEmpty ?? true) ? 'Obrigatório' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: codCtrl,
                          decoration: const InputDecoration(labelText: 'Cód. Barras'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categoriaId,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sem categoria')),
                      ...categorias.map((c) => DropdownMenuItem(
                        value: c.id, child: Text(c.nome),
                      )),
                    ],
                    onChanged: (v) => categoriaId = v,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage().then((url) {
                          if (url != null) imagemUrl = url;
                        }),
                        icon: const Icon(Icons.image),
                        label: const Text('Imagem'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(140, 40)),
                      ),
                      const SizedBox(width: 12),
                      if (imagemUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(imagemUrl!, width: 48, height: 48, fit: BoxFit.cover),
                        ),
                    ],
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

                        // Verificar limite do plano ao criar novo produto
                        if (produto == null) {
                          final limits = await context.read<SubscriptionService>().checkLimits(auth.empresaId!);
                          if (limits['produtosOk'] == false) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Limite de produtos atingido (${limits['limiteProdutos']}). Faça upgrade para Premium!'),
                                  backgroundColor: AppTheme.warning,
                                  action: SnackBarAction(
                                    label: 'Upgrade',
                                    textColor: AppTheme.primary,
                                    onPressed: () {},
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          await service.criarProduto(Produto(
                            id: '',
                            empresaId: auth.empresaId!,
                            categoriaId: categoriaId,
                            nome: nomeCtrl.text,
                            descricao: descCtrl.text,
                            preco: double.parse(precoCtrl.text),
                            codigoBarras: codCtrl.text,
                            imagemUrl: imagemUrl,
                          ));
                        } else {
                          await service.atualizarProduto(produto.id, {
                            'nome': nomeCtrl.text,
                            'descricao': descCtrl.text,
                            'preco': double.parse(precoCtrl.text),
                            'codigo_barras': codCtrl.text,
                            'categoria_id': categoriaId,
                            'imagem_url': imagemUrl,
                          });
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _load();
                      },
                      child: Text(produto == null ? 'Salvar' : 'Atualizar'),
                    ),
                  ),
                  if (produto != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await context.read<ProdutoService>().deletarProduto(produto.id);
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
        );
      },
    );
  }

  Future<String?> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return null;

    final auth = context.read<AuthService>();
    final supabase = SupabaseService();
    final bytes = await file.readAsBytes();

    final path = 'produtos/${auth.empresaId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storageFrom('produtos').uploadBinary(path, bytes);
    final url = supabase.storageFrom('produtos').getPublicUrl(path);
    return url;
  }
}
