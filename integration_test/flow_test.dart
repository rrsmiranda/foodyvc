import 'package:app_idade18/core/widgets/widgets.dart';
import 'package:app_idade18/features/age_check/application/age_check_controller.dart';
import 'package:app_idade18/features/age_check/data/verify_mock_server.dart';
import 'package:app_idade18/features/age_check/data/verify_service.dart';
import 'package:app_idade18/features/shop/application/cart_controller.dart';
import 'package:app_idade18/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Fluxo ponta a ponta contra o mock do M4 (plano, secao 5):
/// - caso 1 (over18): sucesso -> compra liberada;
/// - caso 2 (underage): bloqueio -> itens 18+ saem do pedido;
/// - caso 6 (timeout): status EXPIRED -> estado expired com retry.
///
/// Roda headless com `flutter test integration_test/flow_test.dart` ou em
/// device com `flutter test integration_test`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    required VerifyScenario scenario,
    int activePolls = 1,
    int maxPolls = 4,
  }) async {
    final ({Dio dio, VerifyMockServer server}) mock = VerifyMockServer.createDio(
      scenario: scenario,
      activePolls: activePolls,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          verifyServiceProvider.overrideWithValue(
            VerifyService(dio: mock.dio, uriLauncher: (_) async => true),
          ),
          ageCheckTimingProvider.overrideWithValue(
            AgeCheckTiming(
              pollInterval: const Duration(milliseconds: 1),
              maxPolls: maxPolls,
            ),
          ),
        ],
        child: const AppIdade18(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(AppIdade18)));
  }

  Future<void> addProduct(WidgetTester tester, String name) async {
    final Finder row = find.ancestor(
      of: find.text(name),
      matching: find.byType(ProductCard),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.add)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> checkout(WidgetTester tester) async {
    await tester.tap(find.text('Finalizar compra'));
    await tester.pumpAndSettle();
  }

  testWidgets('caso 1 — over18: verificacao aprova e a compra e concluida', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(
      tester,
      scenario: VerifyScenario.over18,
    );

    await addProduct(tester, 'Cerveja artesanal 473ml');
    await checkout(tester);

    expect(find.widgetWithText(AppBar, 'Verificacao de idade'), findsOneWidget);
    await tester.tap(find.text('Verificar idade'));
    await tester.pumpAndSettle();

    expect(find.text('Idade confirmada'), findsOneWidget);
    await tester.tap(find.text('Concluir compra'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Loja'), findsOneWidget);
    expect(find.text('Compra concluida'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(container.read(cartControllerProvider).isEmpty, isTrue);
    expect(container.read(ageCheckOutcomeProvider), isNull);
  });

  testWidgets('caso 2 — underage: verificacao nega e os itens 18+ saem', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(
      tester,
      scenario: VerifyScenario.underage,
    );

    await addProduct(tester, 'Cafe coado 300ml');
    await addProduct(tester, 'Cerveja artesanal 473ml');
    await checkout(tester);

    await tester.tap(find.text('Verificar idade'));
    await tester.pumpAndSettle();

    expect(find.text('Compra nao autorizada'), findsOneWidget);
    await tester.tap(find.text('Voltar a loja'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Loja'), findsOneWidget);
    expect(find.text('Itens removidos'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final CartState cart = container.read(cartControllerProvider);
    expect(cart.hasAdultItem, isFalse);
    expect(cart.quantityOf('cafe'), 1);
    expect(container.read(ageCheckOutcomeProvider), isNull);
  });

  testWidgets('caso 6 — timeout: status EXPIRED leva a "Sessao expirada"', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pumpApp(
      tester,
      scenario: VerifyScenario.timeout,
      maxPolls: 3,
    );

    await addProduct(tester, 'Cerveja artesanal 473ml');
    await checkout(tester);

    await tester.tap(find.text('Verificar idade'));
    await tester.pumpAndSettle();

    expect(find.text('Sessao expirada'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Tentar de novo'), findsOneWidget);

    // A compra nao foi concluida nem bloqueada: nenhum outcome registrado.
    expect(container.read(ageCheckOutcomeProvider), isNull);
    expect(container.read(cartControllerProvider).hasAdultItem, isTrue);
  });
}
