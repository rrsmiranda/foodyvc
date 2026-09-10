import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/product.dart';

/// Uma linha do pedido: um produto e sua quantidade (>= 1).
@immutable
class CartLine {
  const CartLine({required this.product, required this.quantity})
      : assert(quantity >= 1);

  final Product product;
  final int quantity;

  double get subtotal => product.preco * quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);

  @override
  bool operator ==(Object other) =>
      other is CartLine &&
      other.product == product &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(product, quantity);
}

/// Estado do pedido em andamento.
@immutable
class CartState {
  const CartState({this.lines = const <CartLine>[]});

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  int get itemCount =>
      lines.fold<int>(0, (int sum, CartLine l) => sum + l.quantity);

  double get total =>
      lines.fold<double>(0, (double sum, CartLine l) => sum + l.subtotal);

  /// `true` se ha ao menos um item 18+ no pedido — e o que dispara a
  /// verificacao de idade ao finalizar.
  bool get hasAdultItem => lines.any((CartLine l) => l.product.is18Plus);

  int quantityOf(String productId) {
    for (final CartLine l in lines) {
      if (l.product.id == productId) return l.quantity;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is CartState && listEquals(other.lines, lines);

  @override
  int get hashCode => Object.hashAll(lines);
}

/// Carrinho do pedido.
///
/// **Nao** e `autoDispose`: o pedido precisa sobreviver a ida para `/verify` e
/// a volta.
final NotifierProvider<CartController, CartState> cartControllerProvider =
    NotifierProvider<CartController, CartState>(CartController.new);

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Getter pedido no spec do M1.
  bool get hasAdultItem => state.hasAdultItem;

  /// Adiciona uma unidade de [product] (cria a linha se necessario).
  void add(Product product) {
    final List<CartLine> lines = List<CartLine>.of(state.lines);
    final int i = lines.indexWhere((CartLine l) => l.product.id == product.id);
    if (i >= 0) {
      lines[i] = lines[i].copyWith(quantity: lines[i].quantity + 1);
    } else {
      lines.add(CartLine(product: product, quantity: 1));
    }
    state = CartState(lines: lines);
  }

  /// Remove uma unidade de [product]; some com a linha ao chegar a zero.
  void remove(Product product) {
    final List<CartLine> lines = <CartLine>[];
    for (final CartLine l in state.lines) {
      if (l.product.id != product.id) {
        lines.add(l);
      } else if (l.quantity > 1) {
        lines.add(l.copyWith(quantity: l.quantity - 1));
      }
    }
    state = CartState(lines: lines);
  }

  /// Tira do pedido todos os itens 18+ (usado quando a verificacao nao passa).
  void removeAdultItems() {
    state = CartState(
      lines: state.lines
          .where((CartLine l) => !l.product.is18Plus)
          .toList(growable: false),
    );
  }

  /// Esvazia o carrinho (compra concluida).
  void clear() => state = const CartState();
}
