import 'package:app_idade18/core/theme/app_theme.dart';
import 'package:app_idade18/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('AppButton', () {
    testWidgets('dispara onPressed quando habilitado', (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Ok', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Ok'));
      expect(taps, 1);
    });

    testWidgets('onPressed null = desabilitado', (tester) async {
      await tester.pumpWidget(
        _host(const AppButton(label: 'Ok', onPressed: null)),
      );
      final FilledButton btn = tester.widget(find.byType(FilledButton));
      expect(btn.onPressed, isNull);
    });

    testWidgets('loading mostra spinner, esconde rotulo e fica inerte',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _host(
            AppButton(label: 'Enviar', loading: true, onPressed: () => taps++)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Enviar'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });

    testWidgets('secondary usa OutlinedButton', (tester) async {
      await tester.pumpWidget(
        _host(AppButton(
          label: 'Voltar',
          variant: AppButtonVariant.secondary,
          onPressed: () {},
        )),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });

  group('ProductCard', () {
    testWidgets('mostra nome, preco e o stepper', (tester) async {
      await tester.pumpWidget(_host(ProductCard(
        name: 'Cafe',
        priceLabel: r'R$ 6,50',
        quantity: 0,
        onAdd: () {},
        onRemove: () {},
      )));
      expect(find.text('Cafe'), findsOneWidget);
      expect(find.text(r'R$ 6,50'), findsOneWidget);
      expect(find.text('18+'), findsNothing);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('selo 18+ so quando is18Plus', (tester) async {
      await tester.pumpWidget(_host(ProductCard(
        name: 'Vinho',
        priceLabel: r'R$ 49,90',
        is18Plus: true,
        quantity: 2,
        onAdd: () {},
        onRemove: () {},
      )));
      expect(find.text('18+'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('callbacks de add/remove', (tester) async {
      int add = 0;
      int remove = 0;
      await tester.pumpWidget(_host(ProductCard(
        name: 'Cafe',
        priceLabel: r'R$ 6,50',
        quantity: 1,
        onAdd: () => add++,
        onRemove: () => remove++,
      )));
      await tester.tap(find.byIcon(Icons.add));
      await tester.tap(find.byIcon(Icons.remove));
      expect(add, 1);
      expect(remove, 1);
    });
  });

  group('StatusView', () {
    testWidgets('busy mostra spinner e nao exige icone', (tester) async {
      await tester.pumpWidget(
        _host(const StatusView(busy: true, title: 'Carregando')),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Carregando'), findsOneWidget);
    });

    testWidgets('renderiza icone, descricao e as duas acoes', (tester) async {
      int primary = 0;
      int secondary = 0;
      await tester.pumpWidget(_host(StatusView(
        icon: Icons.check_circle,
        tone: StatusTone.success,
        title: 'Pronto',
        description: 'Tudo certo.',
        primaryLabel: 'Continuar',
        onPrimary: () => primary++,
        secondaryLabel: 'Cancelar',
        onSecondary: () => secondary++,
      )));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Tudo certo.'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.tap(find.text('Cancelar'));
      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('child e footnote aparecem', (tester) async {
      await tester.pumpWidget(_host(const StatusView(
        icon: Icons.error_outline,
        tone: StatusTone.danger,
        title: 'Erro',
        footnote: 'codigo 42',
        child: AppBanner(kind: AppBannerKind.error, message: 'Falhou'),
      )));
      expect(find.text('Falhou'), findsOneWidget);
      expect(find.text('codigo 42'), findsOneWidget);
    });
  });

  group('AppBanner', () {
    testWidgets('cada kind mostra a mensagem e um icone', (tester) async {
      for (final AppBannerKind kind in AppBannerKind.values) {
        await tester.pumpWidget(
          _host(AppBanner(kind: kind, message: 'msg ${kind.name}')),
        );
        expect(find.text('msg ${kind.name}'), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
      }
    });

    testWidgets('renderiza no tema escuro sem erro', (tester) async {
      await tester.pumpWidget(_host(
        const AppBanner(kind: AppBannerKind.success, message: 'ok'),
        theme: AppTheme.dark,
      ));
      expect(find.text('ok'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
