class CaixaModel {
  final String id;
  final String empresaId;
  final String usuarioId;
  final double valorAbertura;
  final double? valorFechamento;
  final double? saldoEsperado;
  final double? saldoReal;
  final double? diferenca;
  final String? observacao;
  final DateTime dataAbertura;
  final DateTime? dataFechamento;
  final String status;

  CaixaModel({
    required this.id,
    required this.empresaId,
    required this.usuarioId,
    this.valorAbertura = 0,
    this.valorFechamento,
    this.saldoEsperado,
    this.saldoReal,
    this.diferenca,
    this.observacao,
    DateTime? dataAbertura,
    this.dataFechamento,
    this.status = 'aberto',
  }) : dataAbertura = dataAbertura ?? DateTime.now();

  factory CaixaModel.fromJson(Map<String, dynamic> json) {
    return CaixaModel(
      id: json['id'] as String,
      empresaId: json['empresa_id'] as String,
      usuarioId: json['usuario_id'] as String,
      valorAbertura: (json['valor_abertura'] as num?)?.toDouble() ?? 0,
      valorFechamento: (json['valor_fechamento'] as num?)?.toDouble(),
      saldoEsperado: (json['saldo_esperado'] as num?)?.toDouble(),
      saldoReal: (json['saldo_real'] as num?)?.toDouble(),
      diferenca: (json['diferenca'] as num?)?.toDouble(),
      observacao: json['observacao'] as String?,
      dataAbertura: DateTime.tryParse(json['data_abertura'] as String? ?? '') ?? DateTime.now(),
      dataFechamento: DateTime.tryParse(json['data_fechamento'] as String? ?? ''),
      status: json['status'] as String? ?? 'aberto',
    );
  }
}
