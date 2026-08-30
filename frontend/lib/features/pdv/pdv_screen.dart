import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/models/produto.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/caixa_service.dart';
import '../../core/services/produto_service.dart';
import '../../core/theme/app_theme.dart';
import '../payment/payment_screen.dart';

class PdvScreen extends StatefulWidget {
  const PdvScreen({super.key});

  @override
  State<PdvScreen> createState() => _PdvScreenState();
}

class _PdvScreenState extends State<PdvScreen> {
  final _searchCtrl = TextEditingController();
  final _carrinho = <Map<String, dynamic>>[];
  String? _categoriaFiltro;
  String _searchQuery = '';
  Timer? _debounce;
  double _desconto = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProdutos());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadProdutos() async {
    final auth = context.read<AuthService>();
    if (auth.empresaId == null) return;
    final produtoService = context.read<ProdutoService>();
    await produtoService.loadProdutos(auth.empresaId!);
  }

  void _adicionarAoCarrinho(Produto produto) {
    final idx = _carrinho.indexWhere((item) => item['produto'].id == produto.id);
    setState(() {
      if (idx >= 0) {
        _carrinho[idx]['quantidade']++;
        _carrinho[idx]['subtotal'] = _carrinho[idx]['quantidade'] * produto.preco;
      } else {
        _carrinho.add({
          'produto': produto,
          'quantidade': 1,
          'subtotal': produto.preco,
        });
      }
    });
  }

  void _removerDoCarrinho(int index) {
    setState(() => _carrinho.removeAt(index));
  }

  void _alterarQuantidade(int index, int delta) {
    setState(() {
      final novaQtd = (_carrinho[index]['quantidade'] as int) + delta;
      if (novaQtd <= 0) {
        _carrinho.removeAt(index);
        return;
      }
      _carrinho[index]['quantidade'] = novaQtd;
      _carrinho[index]['subtotal'] = novaQtd * (_carrinho[index]['produto'] as Produto).preco;
    });
  }

  double get _totalCarrinho =>
      _carrinho.fold(0.0, (sum, item) => sum + (item['subtotal'] as double));

  void _finalizarVenda() {
    if (_carrinho.isEmpty) return;

    // Verificar se há caixa aberto
    final caixaService = context.read<CaixaService>();
    if (caixaService.caixaAtual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abra o caixa antes de realizar vendas'),
          backgroundColor: AppTheme.warning,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          itens: List.from(_carrinho),
          total: _totalCarrinho,
          desconto: _desconto,
        ),
      ),
    );
  }

  void _abrirScanner() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 400,
          child: Column(
            children: [
              AppBar(
                title: const Text('Escaneie o Código de Barras'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcode = capture.barcodes.firstOrNull;
                    if (barcode?.rawValue != null) {
                      Navigator.pop(ctx);
                      _buscarPorCodigoBarras(barcode!.rawValue!);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _buscarPorCodigoBarras(String codigo) async {
    final auth = context.read<AuthService>();
    if (auth.empresaId == null) return;
    final produtoService = context.read<ProdutoService>();
    final produtos = await produtoService.buscarProdutos(
      auth.empresaId!,
      query: codigo,
    );

    if (produtos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produto não encontrado'), backgroundColor: AppTheme.warning),
        );
      }
      return;
    }

    _adicionarAoCarrinho(produtos.first);
  }

  void _mostrarDialogoDesconto() {
    final ctrl = TextEditingController(text: _desconto.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desconto'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Valor do Desconto (R\$)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _desconto = double.tryParse(ctrl.text)?.clamp(0, _totalCarrinho) ?? 0;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final produtoService = context.watch<ProdutoService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDV - Venda Rápida'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _abrirScanner,
            tooltip: 'Escaneie código de barras',
          ),
          if (_carrinho.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_carrinho.length} itens', style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar produto...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() => _searchQuery = v);
                });
              },
            ),
          ),

          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _catChip('Todos', null),
                ...produtoService.categorias.map((cat) => _catChip(cat.nome, cat.id)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: produtoService.loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildProdutosGrid(produtoService),
                ),

                Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  child: _buildCarrinho(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _catChip(String label, String? id) {
    final selected = _categoriaFiltro == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _categoriaFiltro = id),
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(color: selected ? Colors.white : null),
      ),
    );
  }

  Widget _buildProdutosGrid(ProdutoService service) {
    var produtos = service.produtos;

    if (_categoriaFiltro != null) {
      produtos = produtos.where((p) => p.categoriaId == _categoriaFiltro).toList();
    }
    if (_searchQuery.isNotEmpty) {
      produtos = produtos.where((p) =>
          p.nome.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.codigoBarras?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();
    }

    if (produtos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('Nenhum produto encontrado', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.85,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: produtos.length,
      itemBuilder: (_, i) => _buildProdutoCard(produtos[i]),
    );
  }

  Widget _buildProdutoCard(Produto produto) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _adicionarAoCarrinho(produto),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 60, width: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: produto.imagemUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(produto.imagemUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _defaultIcon()),
                      )
                    : _defaultIcon(),
              ),
              const SizedBox(height: 8),
              Text(produto.nome, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(produto.precoFormatado, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.success,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultIcon() => const Icon(Icons.inventory_2, size: 32, color: AppTheme.primary);

  Widget _buildCarrinho() {
    final totalComDesconto = _totalCarrinho - _desconto;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, size: 20),
              const SizedBox(width: 8),
              Text('Carrinho', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_carrinho.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _carrinho.clear();
                    _desconto = 0;
                  }),
                  child: const Text('Limpar', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                ),
            ],
          ),
        ),

        Expanded(
          child: _carrinho.isEmpty
              ? const Center(
                  child: Text('Carrinho vazio\nToque nos produtos para adicionar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              : ListView.builder(
                  itemCount: _carrinho.length,
                  itemBuilder: (_, i) {
                    final item = _carrinho[i];
                    final prod = item['produto'] as Produto;
                    return Dismissible(
                      key: Key(prod.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => _removerDoCarrinho(i),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        color: AppTheme.error,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        dense: true,
                        title: Text(prod.nome, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(prod.precoFormatado, style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              onPressed: () => _alterarQuantidade(i, -1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Text('${item['quantidade']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, size: 20),
                              onPressed: () => _alterarQuantidade(i, 1),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  Text('R\$ ${_totalCarrinho.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _mostrarDialogoDesconto,
                    child: const Row(
                      children: [
                        Text('Desconto:', style: TextStyle(fontSize: 13, color: AppTheme.warning)),
                        SizedBox(width: 4),
                        Icon(Icons.edit, size: 14, color: AppTheme.warning),
                      ],
                    ),
                  ),
                  Text('-R\$ ${_desconto.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.warning)),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 16)),
                  Text('R\$ ${totalComDesconto.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.success)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _carrinho.isEmpty ? null : _finalizarVenda,
                  icon: const Icon(Icons.payment),
                  label: const Text('Finalizar Venda'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
