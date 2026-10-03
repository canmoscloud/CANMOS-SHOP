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

  String? _lastError;
  String? get lastError => _lastError;

  Future<void> loadProdutos(String empresaId) async {
    _loading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _supabase.client
          .from('produtos')
          .select('*, categorias(*)')
          .eq('empresa_id', empresaId)
          .eq('ativo', true)
          .order('nome');

      _produtos = (response as List).map((e) => Produto.fromJson(e)).toList();
    } catch (e) {
      // Sem o try/finally, uma falha de rede deixava _loading em true para
      // sempre e a tela ficava travada no spinner.
      _lastError = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategorias(String empresaId) async {
    try {
      final response = await _supabase.client
          .from('categorias')
          .select()
          .eq('empresa_id', empresaId)
          .order('ordem');

      _categorias = (response as List).map((e) => Categoria.fromJson(e)).toList();
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    }
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

  Future<String?> atualizarCategoria(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.client.from('categorias').update(data).eq('id', id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deletarCategoria(String id) async {
    try {
      await _supabase.client.from('categorias').delete().eq('id', id);
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
      // O valor precisa ir entre aspas: sem isso, uma vírgula no termo
      // ("Coca, lata") é lida como separador de condições e quebra a sintaxe
      // do filtro do PostgREST.
      final termo = query.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      request = request.or(
        'nome.ilike."%$termo%",codigo_barras.ilike."%$termo%"',
      );
    }

    final response = await request.order('nome');
    return (response as List).map((e) => Produto.fromJson(e)).toList();
  }
}
