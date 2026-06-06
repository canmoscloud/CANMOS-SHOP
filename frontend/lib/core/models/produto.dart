class Produto {
  final String id;
  final String empresaId;
  final String? categoriaId;
  final String nome;
  final String? descricao;
  final double preco;
  final String? codigoBarras;
  final String? imagemUrl;
  final bool ativo;
  final String? categoriaNome;
  final String? categoriaCor;
  final DateTime createdAt;

  Produto({
    required this.id,
    required this.empresaId,
    this.categoriaId,
    required this.nome,
    this.descricao,
    required this.preco,
    this.codigoBarras,
    this.imagemUrl,
    this.ativo = true,
    this.categoriaNome,
    this.categoriaCor,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      id: json['id'] as String,
      empresaId: json['empresa_id'] as String,
      categoriaId: json['categoria_id'] as String?,
      nome: json['nome'] as String,
      descricao: json['descricao'] as String?,
      preco: (json['preco'] as num).toDouble(),
      codigoBarras: json['codigo_barras'] as String?,
      imagemUrl: json['imagem_url'] as String?,
      ativo: json['ativo'] as bool? ?? true,
      categoriaNome: json['categorias'] is Map ? json['categorias']['nome'] as String? : null,
      categoriaCor: json['categorias'] is Map ? json['categorias']['cor'] as String? : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'empresa_id': empresaId,
    'categoria_id': categoriaId,
    'nome': nome,
    'descricao': descricao,
    'preco': preco,
    'codigo_barras': codigoBarras,
    'imagem_url': imagemUrl,
    'ativo': ativo,
  };

  String get precoFormatado => 'R\$ ${preco.toStringAsFixed(2)}';
}
