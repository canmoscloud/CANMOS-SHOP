import 'package:flutter_test/flutter_test.dart';
import 'package:canmos_shop/core/models/produto.dart';
import 'package:canmos_shop/core/models/categoria.dart';
import 'package:canmos_shop/core/models/venda.dart';
import 'package:canmos_shop/core/models/caixa_model.dart';
import 'package:canmos_shop/core/constants/app_constants.dart';

void main() {
  group('Produto', () {
    test('fromJson deve criar instancia corretamente', () {
      final json = {
        'id': '123',
        'empresa_id': 'emp1',
        'categoria_id': 'cat1',
        'nome': 'Produto Teste',
        'descricao': 'Descricao',
        'preco': 29.90,
        'codigo_barras': '7891234567890',
        'imagem_url': 'https://example.com/img.jpg',
        'ativo': true,
      };
      final produto = Produto.fromJson(json);
      expect(produto.id, '123');
      expect(produto.nome, 'Produto Teste');
      expect(produto.preco, 29.90);
      expect(produto.codigoBarras, '7891234567890');
    });

    test('toJson deve retornar mapa correto', () {
      final produto = Produto(
        id: '123',
        empresaId: 'emp1',
        categoriaId: 'cat1',
        nome: 'Produto Teste',
        descricao: 'Descricao',
        preco: 29.90,
        codigoBarras: '7891234567890',
        imagemUrl: 'https://example.com/img.jpg',
      );
      final json = produto.toJson();
      expect(json['empresa_id'], 'emp1');
      expect(json['nome'], 'Produto Teste');
      expect(json['preco'], 29.90);
    });

    test('precoFormatado deve retornar formato correto', () {
      final produto = Produto(
        id: '1', empresaId: 'e1', nome: 'Teste', preco: 29.90,
      );
      expect(produto.precoFormatado, 'R\$ 29.90');
    });
  });

  group('Categoria', () {
    test('fromJson deve criar instancia corretamente', () {
      final json = {
        'id': 'cat1',
        'empresa_id': 'emp1',
        'nome': 'Bebidas',
        'cor': '#FF0000',
        'ordem': 1,
      };
      final categoria = Categoria.fromJson(json);
      expect(categoria.id, 'cat1');
      expect(categoria.nome, 'Bebidas');
      expect(categoria.cor, '#FF0000');
    });

    test('toJson deve retornar mapa correto', () {
      final categoria = Categoria(
        id: 'cat1', empresaId: 'emp1', nome: 'Bebidas', cor: '#FF0000', ordem: 1,
      );
      final json = categoria.toJson();
      expect(json['nome'], 'Bebidas');
      expect(json['ordem'], 1);
    });
  });

  group('Venda', () {
    test('fromJson deve criar instancia corretamente', () {
      final json = {
        'id': 'v1',
        'empresa_id': 'emp1',
        'usuario_id': 'u1',
        'valor_total': 100.0,
        'desconto': 10.0,
        'status': 'confirmada',
        'created_at': '2026-06-08T10:00:00',
        'itens_venda': [
          {
            'id': 'i1',
            'venda_id': 'v1',
            'produto_id': 'p1',
            'quantidade': 2,
            'preco_unitario': 50.0,
            'subtotal': 100.0,
            'produtos': {'nome': 'Produto 1'},
          },
        ],
        'pagamentos': [
          {
            'id': 'pg1',
            'venda_id': 'v1',
            'forma_pagamento': 'dinheiro',
            'valor': 100.0,
            'status': 'aprovado',
          },
        ],
        'usuarios': {'nome': 'João'},
      };
      final venda = Venda.fromJson(json);
      expect(venda.id, 'v1');
      expect(venda.valorTotal, 100.0);
      expect(venda.desconto, 10.0);
      expect(venda.status, 'confirmada');
      expect(venda.itens.length, 1);
      expect(venda.pagamentos.length, 1);
      expect(venda.operadorNome, 'João');
      expect(venda.valorLiquido, 90.0);
    });

    test('valorLiquido deve calcular corretamente', () {
      final venda = Venda(
        id: 'v1', empresaId: 'e1', usuarioId: 'u1',
        valorTotal: 100.0, desconto: 15.0,
      );
      expect(venda.valorLiquido, 85.0);
    });
  });

  group('ItemVenda', () {
    test('fromJson com join de produto', () {
      final json = {
        'id': 'i1',
        'venda_id': 'v1',
        'produto_id': 'p1',
        'quantidade': 3,
        'preco_unitario': 10.0,
        'subtotal': 30.0,
        'produtos': {'nome': 'Item Teste'},
      };
      final item = ItemVenda.fromJson(json);
      expect(item.produtoNome, 'Item Teste');
      expect(item.quantidade, 3);
      expect(item.subtotalFormatado, 'R\$ 30.00');
    });
  });

  group('Pagamento', () {
    test('formaPagamentoLabel deve retornar label correto', () {
      final p1 = Pagamento(
        id: '1', vendaId: 'v1', formaPagamento: 'cartao_credito', valor: 50.0,
      );
      final p2 = Pagamento(
        id: '2', vendaId: 'v1', formaPagamento: 'pix', valor: 50.0,
      );
      expect(p1.formaPagamentoLabel, 'Cartão de Crédito');
      expect(p2.formaPagamentoLabel, 'PIX');
    });
  });

  group('CaixaModel', () {
    test('fromJson deve criar instancia corretamente', () {
      final json = {
        'id': 'cx1',
        'empresa_id': 'emp1',
        'usuario_id': 'u1',
        'valor_abertura': 100.0,
        'status': 'aberto',
        'data_abertura': '2026-06-08T08:00:00',
      };
      final caixa = CaixaModel.fromJson(json);
      expect(caixa.id, 'cx1');
      expect(caixa.valorAbertura, 100.0);
      expect(caixa.status, 'aberto');
    });

    test('diferenca deve calcular corretamente', () {
      final caixa = CaixaModel(
        id: 'cx1', empresaId: 'e1', usuarioId: 'u1',
        valorAbertura: 100.0, saldoEsperado: 500.0, saldoReal: 480.0,
        status: 'fechado', dataAbertura: DateTime.now(),
      );
      expect(caixa.diferenca, -20.0);
    });
  });

  group('AppConstants', () {
    test('deve ter valores corretos para limites Free', () {
      expect(AppConstants.produtoLimitFree, 3);
      expect(AppConstants.vendaLimitFree, 5);
    });

    test('deve ter nome e versão do app', () {
      expect(AppConstants.appName, 'CANMOS-SHOP');
      expect(AppConstants.appVersion, '1.0.0');
    });

    test('deve ter email de suporte', () {
      expect(AppConstants.supportEmail, 'canmos.cloud@gmail.com');
    });
  });

  group('Categoria defaults', () {
    test('deve ter cor padrao quando nao fornecida', () {
      final json = {
        'id': 'cat1',
        'empresa_id': 'emp1',
        'nome': 'Teste',
      };
      final categoria = Categoria.fromJson(json);
      expect(categoria.cor, '#6B7280');
      expect(categoria.ordem, 0);
    });
  });

  group('Produto defaults', () {
    test('deve ter ativo=true por padrao', () {
      final produto = Produto(
        id: '1', empresaId: 'e1', nome: 'Teste', preco: 10.0,
      );
      expect(produto.ativo, true);
    });
  });
}
