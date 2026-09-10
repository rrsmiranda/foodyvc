import 'package:app_idade18/core/widgets/widgets.dart';
import 'package:app_idade18/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scaffold + wiring de rotas', () {
    testWidgets('app abre na loja com o catalogo e a barra de checkout',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: AppIdade18()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Loja'), findsOneWidget);
      expect(find.text('Cafe coado 300ml'), findsOneWidget);
      expect(find.text('Cerveja artesanal 473ml'), findsOneWidget);
      expect(find.text('Finalizar compra'), findsOneWidget);
    });

    testWidgets('pedido com item 18+ -> finalizar leva a AgeCheckPage real',
        (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: AppIdade18()));
      await tester.pumpAndSettle();

      // Adiciona a cerveja (item 18+).
      final Finder cervejaRow = find.ancestor(
        of: find.text('Cerveja artesanal 473ml'),
        matching: find.byType(ProductCard),
      );
      await tester.tap(
        find.descendant(of: cervejaRow, matching: find.byIcon(Icons.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finalizar compra'));
      await tester.pumpAndSettle();

      expect(
          find.widgetWithText(AppBar, 'Verificacao de idade'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Verificar idade'), findsOneWidget);
    });
  });
}
