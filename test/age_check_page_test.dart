import 'package:app_idade18/features/age_check/application/age_check_controller.dart';
import 'package:app_idade18/features/age_check/data/verify_mock_server.dart';
import 'package:app_idade18/features/age_check/data/verify_service.dart';
import 'package:app_idade18/features/age_check/presentation/age_check_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke tests da AgeCheckPage. A matriz completa de renderizacao por estado
/// e o golden path de integracao ficam no M5.
Widget _host({required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: AgeCheckPage()),
  );
}

List<Override> _overrides(
  VerifyScenario scenario, {
  int activePolls = 1,
  bool walletOpens = true,
}) {
  final ({Dio dio, VerifyMockServer server}) mock = VerifyMockServer.createDio(
    scenario: scenario,
    activePolls: activePolls,
  );
  return <Override>[
    verifyServiceProvider.overrideWithValue(
      VerifyService(dio: mock.dio, uriLauncher: (_) async => walletOpens),
    ),
    ageCheckTimingProvider.overrideWithValue(
      const AgeCheckTiming(pollInterval: Duration.zero, maxPolls: 20),
    ),
  ];
}

void main() {
  testWidgets('estado idle mostra o botao "Verificar idade"', (
    WidgetTester tester,
  ) async {
    await tester
        .pumpWidget(_host(overrides: _overrides(VerifyScenario.over18)));
    await tester.pumpAndSettle();

    expect(find.text('Verificar idade'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('fluxo over18: idle -> success com "Concluir compra"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(overrides: _overrides(VerifyScenario.over18, activePolls: 1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verificar idade'));
    await tester.pumpAndSettle();

    expect(find.text('Idade confirmada'), findsOneWidget);
    expect(find.text('Concluir compra'), findsOneWidget);
  });

  testWidgets('fluxo underage: idle -> compra nao autorizada, sem retry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(overrides: _overrides(VerifyScenario.underage, activePolls: 1)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verificar idade'));
    await tester.pumpAndSettle();

    expect(find.text('Compra nao autorizada'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
  });

  testWidgets('carteira ausente: estado de erro com "Tentar de novo"', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        overrides: _overrides(VerifyScenario.over18, walletOpens: false),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verificar idade'));
    await tester.pumpAndSettle();

    expect(find.text('Nao foi possivel verificar'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  // Renderizacao explicita de CADA estado (criterio de aceite do M5), pumpando
  // o widget puramente visual com um AgeCheckState construido a mao.
  group('AgeCheckStatusView — um pump por estado', () {
    const AgeCheckSession session = AgeCheckSession(
      transactionId: 't-1',
      requestId: 'r-1',
    );

    Future<void> pumpState(WidgetTester tester, AgeCheckState state) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgeCheckStatusView(
              state: state,
              onVerify: () {},
              onRetry: () {},
              onDone: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('idle', (WidgetTester tester) async {
      await pumpState(tester, const AgeCheckState());
      expect(find.text('Verificacao de idade'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Verificar idade'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('abrindoWallet', (WidgetTester tester) async {
      await pumpState(
        tester,
        const AgeCheckState(phase: AgeCheckPhase.abrindoWallet),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Abrindo a carteira'), findsOneWidget);
    });

    testWidgets('aguardando mostra o contador de consultas', (
      WidgetTester tester,
    ) async {
      await pumpState(
        tester,
        const AgeCheckState(
          phase: AgeCheckPhase.aguardando,
          session: session,
          pollCount: 3,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Aguardando'), findsOneWidget);
      expect(find.textContaining('consulta 3'), findsOneWidget);
    });

    testWidgets('verificando', (WidgetTester tester) async {
      await pumpState(
        tester,
        const AgeCheckState(
          phase: AgeCheckPhase.verificando,
          session: session,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Confirmando'), findsOneWidget);
    });

    testWidgets('success', (WidgetTester tester) async {
      await pumpState(
        tester,
        const AgeCheckState(phase: AgeCheckPhase.success),
      );
      expect(find.text('Idade confirmada'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Concluir compra'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('underage nao oferece retry', (WidgetTester tester) async {
      await pumpState(
        tester,
        const AgeCheckState(phase: AgeCheckPhase.underage),
      );
      expect(find.text('Compra nao autorizada'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('expired oferece retry e voltar', (WidgetTester tester) async {
      await pumpState(
        tester,
        const AgeCheckState(
          phase: AgeCheckPhase.expired,
          message: 'A sessao expirou.',
        ),
      );
      expect(find.text('Sessao expirada'), findsOneWidget);
      expect(find.text('A sessao expirou.'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Tentar de novo'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Voltar a loja'), findsOneWidget);
    });

    testWidgets('error mostra a mensagem e retry', (WidgetTester tester) async {
      await pumpState(
        tester,
        const AgeCheckState(
          phase: AgeCheckPhase.error,
          message: 'Falha de rede.',
        ),
      );
      expect(find.text('Nao foi possivel verificar'), findsOneWidget);
      expect(find.text('Falha de rede.'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Tentar de novo'), findsOneWidget);
    });

    testWidgets('callbacks disparam', (WidgetTester tester) async {
      int verify = 0;
      int retry = 0;
      int done = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgeCheckStatusView(
              state:
                  const AgeCheckState(phase: AgeCheckPhase.error, message: 'x'),
              onVerify: () => verify++,
              onRetry: () => retry++,
              onDone: () => done++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tentar de novo'));
      await tester.tap(find.text('Voltar a loja'));
      expect(retry, 1);
      expect(done, 1);
      expect(verify, 0);
    });
  });
}
