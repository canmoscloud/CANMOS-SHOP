class Venda {
  final String id;
  final String empresaId;
  final String usuarioId;
  final String? caixaId;
  final double valorTotal;
  final double desconto;
  final String status;
  final String? observacao;
  final DateTime createdAt;
  final List<ItemVenda> itens;
  final List<Pagamento> pagamentos;
  final String? operadorNome;

  Venda({
    required this.id,
    required this.empresaId,
    required this.usuarioId,
    this.caixaId,
    required this.valorTotal,
    this.desconto = 0,
    this.status = 'pendente',
    this.observacao,
    DateTime? createdAt,
    this.itens = const [],
    this.pagamentos = const [],
    this.operadorNome,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Venda.fromJson(Map<String, dynamic> json) {
    return Venda(
      id: json['id'] as String,
      empresaId: json['empresa_id'] as String,
      usuarioId: json['usuario_id'] as String,
      caixaId: json['caixa_id'] as String?,
      valorTotal: (json['valor_total'] as num).toDouble(),
      desconto: (json['desconto'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'pendente',
      observacao: json['observacao'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      itens: (json['itens_venda'] as List?)?.map((e) => ItemVenda.fromJson(e)).toList() ?? [],
      pagamentos: (json['pagamentos'] as List?)?.map((e) => Pagamento.fromJson(e)).toList() ?? [],
      operadorNome: json['usuarios'] is Map ? json['usuarios']['nome'] as String? : null,
    );
  }

  String get valorTotalFormatado => 'R\$ ${valorTotal.toStringAsFixed(2)}';
  String get descontoFormatado => 'R\$ ${desconto.toStringAsFixed(2)}';
  double get valorLiquido => valorTotal - desconto;
  String get valorLiquidoFormatado => 'R\$ ${valorLiquido.toStringAsFixed(2)}';
}

class ItemVenda {
  final String id;
  final String vendaId;
  final String produtoId;
  final int quantidade;
  final double precoUnitario;
  final double subtotal;
  final String? produtoNome;

  ItemVenda({
    required this.id,
    required this.vendaId,
    required this.produtoId,
    required this.quantidade,
    required this.precoUnitario,
    required this.subtotal,
    this.produtoNome,
  });

  factory ItemVenda.fromJson(Map<String, dynamic> json) {
    return ItemVenda(
      id: json['id'] as String,
      vendaId: json['venda_id'] as String,
      produtoId: json['produto_id'] as String,
      quantidade: json['quantidade'] as int,
      precoUnitario: (json['preco_unitario'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      produtoNome: json['produtos'] is Map ? json['produtos']['nome'] as String? : null,
    );
  }

  String get precoFormatado => 'R\$ ${precoUnitario.toStringAsFixed(2)}';
  String get subtotalFormatado => 'R\$ ${subtotal.toStringAsFixed(2)}';
}

class Pagamento {
  final String id;
  final String vendaId;
  final String formaPagamento;
  final double valor;
  final String status;
  final String? stripePaymentIntentId;
  final String? abacatepayCobrancaId;
  final String? pixQrCode;
  final String? pixQrCodeTexto;
  final DateTime? processadoEm;

  Pagamento({
    required this.id,
    required this.vendaId,
    required this.formaPagamento,
    required this.valor,
    this.status = 'pendente',
    this.stripePaymentIntentId,
    this.abacatepayCobrancaId,
    this.pixQrCode,
    this.pixQrCodeTexto,
    this.processadoEm,
  });

  factory Pagamento.fromJson(Map<String, dynamic> json) {
    return Pagamento(
      id: json['id'] as String,
      vendaId: json['venda_id'] as String,
      formaPagamento: json['forma_pagamento'] as String,
      valor: (json['valor'] as num).toDouble(),
      status: json['status'] as String? ?? 'pendente',
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
      abacatepayCobrancaId: json['abacatepay_cobranca_id'] as String?,
      pixQrCode: json['pix_qr_code'] as String?,
      pixQrCodeTexto: json['pix_qr_code_texto'] as String?,
      processadoEm: DateTime.tryParse(json['processado_em'] as String? ?? ''),
    );
  }

  String get formaPagamentoLabel {
    switch (formaPagamento) {
      case 'cartao_credito': return 'Cartão de Crédito';
      case 'cartao_debito': return 'Cartão de Débito';
      case 'pix': return 'PIX';
      case 'dinheiro': return 'Dinheiro';
      default: return formaPagamento;
    }
  }

  String get valorFormatado => 'R\$ ${valor.toStringAsFixed(2)}';
}
