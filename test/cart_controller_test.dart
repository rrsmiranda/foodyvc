import 'package:app_idade18/features/shop/application/cart_controller.dart';
import 'package:app_idade18/features/shop/domain/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const Product _cafe = Product(id: 'cafe', nome: 'Cafe', preco: 6.5);
const Product _suco = Product(id: 'suco', nome: 'Suco', preco: 12);
const Product _cerveja = Product(
  id: 'cerveja',
  nome: 'Cerveja',
  preco: 18.9,
  is18Plus: true,
);

ProviderContainer _container() {
  final ProviderContainer c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('add / remove', () {
    test('add cria a linha com quantidade 1', () {
      final ProviderContainer c = _container();
      c.read(cartControllerProvider.notifier).add(_cafe);

      final CartState s = c.read(cartControllerProvider);
      expect(s.lines, hasLength(1));
      expect(s.quantityOf('cafe'), 1);
      expect(s.itemCount, 1);
      expect(s.total, 6.5);
    });

    test('add repetido incrementa a mesma linha', () {
      final ProviderContainer c = _container();
      final CartController ctrl = c.read(cartControllerProvider.notifier)
        ..add(_cafe)
        ..add(_cafe)
        ..add(_cafe);

      expect(c.read(cartControllerProvider).lines, hasLength(1));
      expect(c.read(cartControllerProvider).quantityOf('cafe'), 3);
      expect(ctrl.hasAdultItem, isFalse);
    });

    test('produtos diferentes viram linhas diferentes; total soma', () {
      final ProviderContainer c = _container();
      c.read(cartControllerProvider.notifier)
        ..add(_cafe)
        ..add(_suco)
        ..add(_suco);

      final CartState s = c.read(cartControllerProvider);
      expect(s.lines, hasLength(2));
      expect(s.itemCount, 3);
      expect(s.total, closeTo(6.5 + 12 + 12, 1e-9));
    });

    test('remove decrementa e remove a linha ao zerar', () {
      final ProviderContainer c = _container();
      final CartController ctrl = c.read(cartControllerProvider.notifier)
        ..add(_cafe)
        ..add(_cafe);

      ctrl.remove(_cafe);
      expect(c.read(cartControllerProvider).quantityOf('cafe'), 1);

      ctrl.remove(_cafe);
      expect(c.read(cartControllerProvider).quantityOf('cafe'), 0);
      expect(c.read(cartControllerProvider).isEmpty, isTrue);
    });

    test('remove de produto ausente e no-op', () {
      final ProviderContainer c = _container();
      c.read(cartControllerProvider.notifier)
        ..add(_cafe)
        ..remove(_suco);

      expect(c.read(cartControllerProvider).quantityOf('cafe'), 1);
    });
  });

  group('hasAdultItem', () {
    test('false sem itens 18+, true depois de adicionar um', () {
      final ProviderContainer c = _container();
      final CartController ctrl = c.read(cartControllerProvider.notifier);

      ctrl.add(_cafe);
      expect(c.read(cartControllerProvider).hasAdultItem, isFalse);
      expect(ctrl.hasAdultItem, isFalse);

      ctrl.add(_cerveja);
      expect(c.read(cartControllerProvider).hasAdultItem, isTrue);
      expect(ctrl.hasAdultItem, isTrue);
    });
  });

  group('removeAdultItems / clear', () {
    test('removeAdultItems mantem so os itens liberados', () {
      final ProviderContainer c = _container();
      c.read(cartControllerProvider.notifier)
        ..add(_cafe)
        ..add(_cerveja)
        ..add(_suco);

      c.read(cartControllerProvider.notifier).removeAdultItems();

      final CartState s = c.read(cartControllerProvider);
      expect(s.hasAdultItem, isFalse);
      expect(s.quantityOf('cafe'), 1);
      expect(s.quantityOf('suco'), 1);
      expect(s.quantityOf('cerveja'), 0);
    });

    test('clear esvazia', () {
      final ProviderContainer c = _container();
      c.read(cartControllerProvider.notifier)
        ..add(_cafe)
        ..add(_cerveja);

      c.read(cartControllerProvider.notifier).clear();
      expect(c.read(cartControllerProvider).isEmpty, isTrue);
    });
  });
}
