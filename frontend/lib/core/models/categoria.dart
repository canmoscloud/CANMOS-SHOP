class Categoria {
  final String id;
  final String empresaId;
  final String nome;
  final String cor;
  final int ordem;

  Categoria({
    required this.id,
    required this.empresaId,
    required this.nome,
    this.cor = '#6B7280',
    this.ordem = 0,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] as String,
      empresaId: json['empresa_id'] as String,
      nome: json['nome'] as String,
      cor: json['cor'] as String? ?? '#6B7280',
      ordem: json['ordem'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'empresa_id': empresaId,
    'nome': nome,
    'cor': cor,
    'ordem': ordem,
  };
}
