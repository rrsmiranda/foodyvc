import 'package:flutter/foundation.dart';

/// Item do catalogo da loja (casca de simulacao de compra).
///
/// `is18Plus` e a unica adicao "honesta" sobre um clone de vitrine: e a flag
/// que, no checkout, dispara o modulo de verificacao de idade.
@immutable
class Product {
  const Product({
    required this.id,
    required this.nome,
    required this.preco,
    this.is18Plus = false,
  });

  final String id;
  final String nome;

  /// Preco em reais.
  final double preco;

  /// Quando `true`, finalizar um pedido com este item exige verificacao 18+.
  final bool is18Plus;

  @override
  bool operator ==(Object other) =>
      other is Product &&
      other.id == id &&
      other.nome == nome &&
      other.preco == preco &&
      other.is18Plus == is18Plus;

  @override
  int get hashCode => Object.hash(id, nome, preco, is18Plus);

  @override
  String toString() => 'Product($id, $nome, R\$ $preco, is18Plus: $is18Plus)';
}
