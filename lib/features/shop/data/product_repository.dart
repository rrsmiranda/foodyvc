import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/product.dart';

/// Fonte do catalogo. No MVP e um mock em memoria; trocar por HTTP depois nao
/// muda a `ShopPage` nem o `CartController`.
abstract interface class ProductRepository {
  List<Product> fetchAll();
}

class MockProductRepository implements ProductRepository {
  const MockProductRepository();

  static const List<Product> _catalog = <Product>[
    Product(id: 'cafe', nome: 'Cafe coado 300ml', preco: 6.50),
    Product(id: 'pao-de-queijo', nome: 'Pao de queijo (3 un)', preco: 9.90),
    Product(id: 'suco-laranja', nome: 'Suco de laranja 500ml', preco: 12.00),
    Product(
      id: 'cerveja',
      nome: 'Cerveja artesanal 473ml',
      preco: 18.90,
      is18Plus: true,
    ),
    Product(
      id: 'vinho',
      nome: 'Vinho tinto 750ml',
      preco: 49.90,
      is18Plus: true,
    ),
  ];

  @override
  List<Product> fetchAll() => _catalog;
}

final Provider<ProductRepository> productRepositoryProvider =
    Provider<ProductRepository>((Ref ref) => const MockProductRepository());

/// Catalogo pronto para a UI consumir.
final Provider<List<Product>> catalogProvider = Provider<List<Product>>(
  (Ref ref) => ref.watch(productRepositoryProvider).fetchAll(),
);
