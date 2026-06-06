import 'package:flutter/foundation.dart';
import '../models/produto.dart';
import '../models/categoria.dart';
import 'supabase_service.dart';

class ProdutoService extends ChangeNotifier {
  final SupabaseService _supabase = SupabaseService();
  List<Produto> _produtos = [];
  List<Categoria> _categorias = [];
  bool _loading = false;

  List<Produto> get produtos => _produtos;
  List<Categoria> get categorias => _categorias;
  bool get loading => _loading;

  Future<void> loadProdutos(String empresaId) async {
    _loading = true;
    notifyListeners();

    final response = await _supabase.client
        .from('produtos')
        .select('*, categorias(*)')
        .eq('empresa_id', empresaId)
        .eq('ativo', true)
        .order('nome');

    _produtos = (response as List).map((e) => Produto.fromJson(e)).toList();
    _loading = false;
    notifyListeners();
  }

  Future<void> loadCategorias(String empresaId) async {
    final response = await _supabase.client
        .from('categorias')
        .select()
        .eq('empresa_id', empresaId)
        .order('ordem');

    _categorias = (response as List).map((e) => Categoria.fromJson(e)).toList();
    notifyListeners();
  }

  Future<String?> criarProduto(Produto produto) async {
    try {
      await _supabase.client.from('produtos').insert(produto.toJson());
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> atualizarProduto(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.client.from('produtos').update(data).eq('id', id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deletarProduto(String id) async {
    try {
      await _supabase.client.from('produtos').update({'ativo': false}).eq('id', id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> criarCategoria(Categoria categoria) async {
    try {
      await _supabase.client.from('categorias').insert(categoria.toJson());
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<Produto>> buscarProdutos(String empresaId, {String? query}) async {
    var request = _supabase.client
        .from('produtos')
        .select('*, categorias(*)')
        .eq('empresa_id', empresaId)
        .eq('ativo', true);

    if (query != null && query.isNotEmpty) {
      request = request.ilike('nome', '%$query%');
    }

    final response = await request.order('nome');
    return (response as List).map((e) => Produto.fromJson(e)).toList();
  }
}
