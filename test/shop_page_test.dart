import 'package:app_idade18/core/widgets/widgets.dart';
import 'package:app_idade18/features/age_check/application/age_check_controller.dart';
import 'package:app_idade18/features/shop/application/cart_controller.dart';
import 'package:app_idade18/features/shop/presentation/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _app(ProviderContainer container) {
  final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, __) => const ShopPage()),
      GoRoute(
        path: '/verify',
        builder: (_, __) => const Scaffold(body: Text('VERIFY STUB')),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

ProviderContainer _container() {
  final ProviderContainer c = ProviderContainer();
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets(
      'lista o catalogo mock e comeca com "Finalizar compra" desabilitado',
      (WidgetTester tester) async {
    await tester.pumpWidget(_app(_container()));
    await tester.pumpAndSettle();

    expect(find.text('Cafe coado 300ml'), findsOneWidget);
    expect(find.text('Cerveja artesanal 473ml'), findsOneWidget);
    expect(find.text('18+'), findsNWidgets(2));

    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Finalizar compra'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('adicionar item atualiza o total e habilita o botao',
      (WidgetTester tester) async {
    final ProviderContainer c = _container();
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    await _addProduct(tester, 'Cafe coado 300ml');

    expect(c.read(cartControllerProvider).quantityOf('cafe'), 1);
    expect(find.text('R\$ 6,50'), findsWidgets);

    final FilledButton button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Finalizar compra'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
      'finalizar sem item 18+ -> dialogo "Compra concluida" e limpa o carrinho',
      (WidgetTester tester) async {
    final ProviderContainer c = _container();
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    await _addProduct(tester, 'Cafe coado 300ml');
    await tester.tap(find.text('Finalizar compra'));
    await tester.pumpAndSettle();

    expect(find.text('Compra concluida'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(c.read(cartControllerProvider).isEmpty, isTrue);
    expect(find.text('VERIFY STUB'), findsNothing);
  });

  testWidgets('finalizar com item 18+ -> navega para /verify',
      (WidgetTester tester) async {
    final ProviderContainer c = _container();
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    await _addProduct(tester, 'Cerveja artesanal 473ml');
    await tester.tap(find.text('Finalizar compra'));
    await tester.pumpAndSettle();

    expect(find.text('VERIFY STUB'), findsOneWidget);
  });

  testWidgets('volta de /verify com outcome=verified -> conclui e limpa',
      (WidgetTester tester) async {
    final ProviderContainer c = _container();
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    await _addProduct(tester, 'Cerveja artesanal 473ml');
    c.read(ageCheckOutcomeProvider.notifier).state = AgeCheckOutcome.verified;
    await tester.pumpAndSettle();

    expect(find.text('Compra concluida'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(c.read(cartControllerProvider).isEmpty, isTrue);
    expect(c.read(ageCheckOutcomeProvider), isNull);
  });

  testWidgets('volta de /verify com outcome=blocked -> remove itens 18+',
      (WidgetTester tester) async {
    final ProviderContainer c = _container();
    await tester.pumpWidget(_app(c));
    await tester.pumpAndSettle();

    await _addProduct(tester, 'Cafe coado 300ml');
    await _addProduct(tester, 'Cerveja artesanal 473ml');
    c.read(ageCheckOutcomeProvider.notifier).state = AgeCheckOutcome.blocked;
    await tester.pumpAndSettle();

    expect(find.text('Itens removidos'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final CartState cart = c.read(cartControllerProvider);
    expect(cart.hasAdultItem, isFalse);
    expect(cart.quantityOf('cafe'), 1);
    expect(c.read(ageCheckOutcomeProvider), isNull);
  });
}

Future<void> _addProduct(WidgetTester tester, String name) async {
  final Finder row = find.ancestor(
    of: find.text(name),
    matching: find.byType(ProductCard),
  );
  await tester.tap(
    find.descendant(of: row, matching: find.byIcon(Icons.add)),
  );
  await tester.pumpAndSettle();
}
